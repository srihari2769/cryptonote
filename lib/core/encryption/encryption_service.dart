import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import '../app_config.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static EncryptionService get instance => _instance;

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _random = Random.secure();

  /// Encrypts a message using AES-256-GCM with PBKDF2 key derivation
  /// Returns: base64(salt + nonce + ciphertext)
  Future<String> encryptMessage(String message, String password) async {
    try {
      // Generate random salt
      final salt = _generateRandomBytes(AppConfig.saltLength);
      
      // Derive key using PBKDF2
      final secretKey = await _deriveKey(password, salt);
      
      // Generate random nonce
      final nonce = _generateRandomBytes(AppConfig.nonceLength);
      
      // Convert message to bytes
      final messageBytes = utf8.encode(message);
      
      // Encrypt the message
      final secretBox = await _aesGcm.encrypt(
        messageBytes,
        secretKey: secretKey,
        nonce: nonce,
      );
      
      // Combine salt + nonce + ciphertext
      final combined = Uint8List.fromList([
        ...salt,
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);
      
      // Return base64 encoded result
      return base64.encode(combined);
    } catch (e) {
      throw EncryptionException('Failed to encrypt message: $e');
    }
  }

  /// Decrypts a message using AES-256-GCM
  /// Input: base64(salt + nonce + ciphertext)
  Future<String> decryptMessage(String encryptedData, String password) async {
    try {
      // Decode from base64
      final combined = base64.decode(encryptedData);
      
      if (combined.length < AppConfig.saltLength + AppConfig.nonceLength + 16) {
        throw EncryptionException('Invalid encrypted data format');
      }
      
      // Extract components
      final salt = combined.sublist(0, AppConfig.saltLength);
      final nonce = combined.sublist(
        AppConfig.saltLength, 
        AppConfig.saltLength + AppConfig.nonceLength
      );
      final cipherTextWithMac = combined.sublist(AppConfig.saltLength + AppConfig.nonceLength);
      
      // Extract MAC (last 16 bytes)
      final mac = Mac(cipherTextWithMac.sublist(cipherTextWithMac.length - 16));
      final cipherText = cipherTextWithMac.sublist(0, cipherTextWithMac.length - 16);
      
      // Derive key using the same salt
      final secretKey = await _deriveKey(password, salt);
      
      // Create SecretBox for decryption
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      
      // Decrypt the message
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      
      // Convert back to string
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw EncryptionException('Failed to decrypt message: $e');
    }
  }

  /// Derives a key from password and salt using PBKDF2
  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: AppConfig.pbkdf2Iterations,
      bits: AppConfig.aesKeyLength * 8, // 256 bits
    );
    
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    
    return secretKey;
  }

  /// Generates cryptographically secure random bytes
  List<int> _generateRandomBytes(int length) {
    final bytes = List<int>.generate(length, (i) => _random.nextInt(256));
    return bytes;
  }

  /// Validates password strength
  bool isPasswordStrong(String password) {
    if (password.length < 8) return false;
    
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  /// Generates a secure random password
  String generateSecurePassword({int length = 16}) {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
    return List.generate(length, (index) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Hashes a password for storage (not for encryption)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}

