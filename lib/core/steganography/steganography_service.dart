import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../app_config.dart';
import '../encryption/encryption_service.dart';

class SteganographyService {
  static final SteganographyService _instance = SteganographyService._internal();
  factory SteganographyService() => _instance;
  SteganographyService._internal();

  static SteganographyService get instance => _instance;

  final EncryptionService _encryptionService = EncryptionService.instance;

  /// Embeds an encrypted message into a WAV audio file using LSB steganography
  Future<File> embedMessage({
    required File audioFile,
    required String message,
    required String password,
    required String outputPath,
  }) async {
    try {
      // Validate input file
      if (!_isValidWavFile(audioFile)) {
        throw SteganographyException('Invalid WAV file format');
      }

      // Encrypt the message first
      final encryptedMessage = await _encryptionService.encryptMessage(message, password);
      
      // Read the WAV file
      final audioBytes = await audioFile.readAsBytes();
      final wavData = _parseWavFile(audioBytes);
      
      // Check if audio file has enough capacity
      final messageBytes = utf8.encode(encryptedMessage);
      final requiredCapacity = (AppConfig.messageLengthHeaderBytes + messageBytes.length) * 8;
      final availableCapacity = wavData.audioData.length;
      
      if (requiredCapacity > availableCapacity) {
        throw SteganographyException(
          'Audio file too small. Required: $requiredCapacity bits, Available: $availableCapacity bits'
        );
      }

      // Create a copy of the audio data
      final modifiedAudioData = Uint8List.fromList(wavData.audioData);
      
      // Embed message length header (4 bytes, big-endian)
      final messageLengthBytes = _intToBytes(messageBytes.length, 4);
      int bitIndex = 0;
      
      // Embed length header
      for (int i = 0; i < messageLengthBytes.length; i++) {
        for (int bit = 7; bit >= 0; bit--) {
          final messageBit = (messageLengthBytes[i] >> bit) & 1;
          modifiedAudioData[bitIndex] = (modifiedAudioData[bitIndex] & 0xFE) | messageBit;
          bitIndex++;
        }
      }
      
      // Embed the encrypted message
      for (int i = 0; i < messageBytes.length; i++) {
        for (int bit = 7; bit >= 0; bit--) {
          final messageBit = (messageBytes[i] >> bit) & 1;
          modifiedAudioData[bitIndex] = (modifiedAudioData[bitIndex] & 0xFE) | messageBit;
          bitIndex++;
        }
      }
      
      // Create the output file with modified audio data
      final outputBytes = _createWavFile(wavData.header, modifiedAudioData);
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);
      
      return outputFile;
    } catch (e) {
      throw SteganographyException('Failed to embed message: $e');
    }
  }

  /// Extracts and decrypts a message from a WAV audio file
  Future<String> extractMessage({
    required File audioFile,
    required String password,
  }) async {
    try {
      // Validate input file
      if (!_isValidWavFile(audioFile)) {
        throw SteganographyException('Invalid WAV file format');
      }

      // Read the WAV file
      final audioBytes = await audioFile.readAsBytes();
      final wavData = _parseWavFile(audioBytes);
      
      // Extract message length from header (first 4 bytes)
      int bitIndex = 0;
      final lengthBytes = List<int>.filled(4, 0);
      
      for (int i = 0; i < 4; i++) {
        for (int bit = 7; bit >= 0; bit--) {
          final lsb = wavData.audioData[bitIndex] & 1;
          lengthBytes[i] = (lengthBytes[i] << 1) | lsb;
          bitIndex++;
        }
      }
      
      final messageLength = _bytesToInt(lengthBytes);
      
      if (messageLength <= 0 || messageLength > wavData.audioData.length) {
        throw SteganographyException('Invalid message length or no hidden message found');
      }
      
      // Extract the encrypted message
      final messageBytes = List<int>.filled(messageLength, 0);
      
      for (int i = 0; i < messageLength; i++) {
        for (int bit = 7; bit >= 0; bit--) {
          final lsb = wavData.audioData[bitIndex] & 1;
          messageBytes[i] = (messageBytes[i] << 1) | lsb;
          bitIndex++;
        }
      }
      
      // Convert to string and decrypt
      final encryptedMessage = utf8.decode(messageBytes);
      final decryptedMessage = await _encryptionService.decryptMessage(encryptedMessage, password);
      
      return decryptedMessage;
    } catch (e) {
      throw SteganographyException('Failed to extract message: $e');
    }
  }

  /// Checks if an audio file potentially contains a hidden message
  Future<bool> hasHiddenMessage(File audioFile) async {
    try {
      if (!_isValidWavFile(audioFile)) {
        return false;
      }

      final audioBytes = await audioFile.readAsBytes();
      final wavData = _parseWavFile(audioBytes);
      
      // Extract potential message length
      int bitIndex = 0;
      final lengthBytes = List<int>.filled(4, 0);
      
      for (int i = 0; i < 4; i++) {
        for (int bit = 7; bit >= 0; bit--) {
          final lsb = wavData.audioData[bitIndex] & 1;
          lengthBytes[i] = (lengthBytes[i] << 1) | lsb;
          bitIndex++;
        }
      }
      
      final messageLength = _bytesToInt(lengthBytes);
      
      // Check if the length is reasonable
      return messageLength > 0 && 
             messageLength < wavData.audioData.length && 
             messageLength < 1000000; // Max 1MB message
    } catch (e) {
      return false;
    }
  }

  /// Calculates the maximum message capacity for an audio file
  Future<int> getMessageCapacity(File audioFile) async {
    try {
      if (!_isValidWavFile(audioFile)) {
        return 0;
      }

      final audioBytes = await audioFile.readAsBytes();
      final wavData = _parseWavFile(audioBytes);
      
      // Available bits minus header
      final availableBits = wavData.audioData.length - (AppConfig.messageLengthHeaderBytes * 8);
      return availableBits ~/ 8; // Convert to bytes
    } catch (e) {
      return 0;
    }
  }

  /// Validates if a file is a proper WAV file
  bool _isValidWavFile(File file) {
    final extension = path.extension(file.path).toLowerCase();
    return extension == '.wav';
  }

  /// Parses a WAV file and extracts header and audio data
  WavData _parseWavFile(Uint8List bytes) {
    if (bytes.length < 44) {
      throw SteganographyException('Invalid WAV file: too small');
    }

    // Check RIFF header
    final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffHeader != 'RIFF') {
      throw SteganographyException('Invalid WAV file: missing RIFF header');
    }

    // Check WAVE format
    final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveFormat != 'WAVE') {
      throw SteganographyException('Invalid WAV file: not WAVE format');
    }

    // Find data chunk
    int dataOffset = 12;
    while (dataOffset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
      final chunkSize = _bytesToInt(bytes.sublist(dataOffset + 4, dataOffset + 8));
      
      if (chunkId == 'data') {
        final header = bytes.sublist(0, dataOffset + 8);
        final audioData = bytes.sublist(dataOffset + 8, dataOffset + 8 + chunkSize);
        return WavData(header: header, audioData: audioData);
      }
      
      dataOffset += 8 + chunkSize;
      if (chunkSize % 2 == 1) dataOffset++; // Padding for odd-sized chunks
    }

    throw SteganographyException('Invalid WAV file: no data chunk found');
  }

  /// Creates a WAV file from header and audio data
  Uint8List _createWavFile(Uint8List header, Uint8List audioData) {
    final result = Uint8List(header.length + audioData.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, audioData);
    return result;
  }

  /// Converts an integer to bytes (big-endian)
  List<int> _intToBytes(int value, int byteCount) {
    final bytes = List<int>.filled(byteCount, 0);
    for (int i = byteCount - 1; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  /// Converts bytes to integer (big-endian)
  int _bytesToInt(List<int> bytes) {
    int result = 0;
    for (int byte in bytes) {
      result = (result << 8) | byte;
    }
    return result;
  }
}

class WavData {
  final Uint8List header;
  final Uint8List audioData;

  WavData({required this.header, required this.audioData});
}

class SteganographyException implements Exception {
  final String message;
  SteganographyException(this.message);
  
  @override
  String toString() => 'SteganographyException: $message';
}

