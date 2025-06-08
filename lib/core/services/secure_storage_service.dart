import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../app_config.dart';
import '../models/vault_item.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static SecureStorageService get instance => _instance;

  late FlutterSecureStorage _secureStorage;
  late Directory _vaultDirectory;
  late Directory _tempDirectory;

  // Storage Keys
  static const String _keyVaultItems = 'vault_items';
  static const String _keyAppSettings = 'app_settings';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastAccessTime = 'last_access_time';

  Future<void> init() async {
    // Initialize secure storage
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    const iosOptions = IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    );
    
    _secureStorage = const FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iosOptions,
    );

    // Initialize directories
    await _initDirectories();
  }

  Future<void> _initDirectories() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    
    _vaultDirectory = Directory('${appDocDir.path}/${AppConfig.vaultDirectoryName}');
    _tempDirectory = Directory('${appDocDir.path}/${AppConfig.tempDirectoryName}');
    
    if (!await _vaultDirectory.exists()) {
      await _vaultDirectory.create(recursive: true);
    }
    
    if (!await _tempDirectory.exists()) {
      await _tempDirectory.create(recursive: true);
    }
  }

  // Vault Items Management
  Future<List<VaultItem>> getVaultItems() async {
    try {
      final itemsJson = await _secureStorage.read(key: _keyVaultItems);
      if (itemsJson == null) return [];
      
      final itemsList = jsonDecode(itemsJson) as List;
      return itemsList.map((item) => VaultItem.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveVaultItems(List<VaultItem> items) async {
    try {
      final itemsJson = jsonEncode(items.map((item) => item.toJson()).toList());
      await _secureStorage.write(key: _keyVaultItems, value: itemsJson);
    } catch (e) {
      throw SecureStorageException('Failed to save vault items: $e');
    }
  }

  Future<void> addVaultItem(VaultItem item) async {
    final items = await getVaultItems();
    items.add(item);
    await saveVaultItems(items);
  }

  Future<void> removeVaultItem(String id) async {
    final items = await getVaultItems();
    items.removeWhere((item) => item.id == id);
    await saveVaultItems(items);
    
    // Also delete the physical file
    final file = File('${_vaultDirectory.path}/$id.wav');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> updateVaultItem(VaultItem updatedItem) async {
    final items = await getVaultItems();
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      await saveVaultItems(items);
    }
  }

  // File Management
  Future<File> saveToVault(File sourceFile, String fileName) async {
    final targetPath = '${_vaultDirectory.path}/$fileName';
    return await sourceFile.copy(targetPath);
  }

  Future<File> getVaultFile(String fileName) async {
    return File('${_vaultDirectory.path}/$fileName');
  }

  Future<File> createTempFile(String fileName) async {
    return File('${_tempDirectory.path}/$fileName');
  }

  Future<void> cleanTempFiles() async {
    if (await _tempDirectory.exists()) {
      await for (final entity in _tempDirectory.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  // Settings Management
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final settingsJson = await _secureStorage.read(key: _keyAppSettings);
      if (settingsJson == null) return {};
      return jsonDecode(settingsJson);
    } catch (e) {
      return {};
    }
  }

  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      final settingsJson = jsonEncode(settings);
      await _secureStorage.write(key: _keyAppSettings, value: settingsJson);
    } catch (e) {
      throw SecureStorageException('Failed to save app settings: $e');
    }
  }

  Future<T?> getSetting<T>(String key) async {
    final settings = await getAppSettings();
    return settings[key] as T?;
  }

  Future<void> setSetting<T>(String key, T value) async {
    final settings = await getAppSettings();
    settings[key] = value;
    await saveAppSettings(settings);
  }

  // Biometric Settings
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyBiometricEnabled, 
      value: enabled.toString()
    );
  }

  // Session Management
  Future<void> updateLastAccessTime() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: _keyLastAccessTime, value: now);
  }

  Future<DateTime?> getLastAccessTime() async {
    try {
      final timeStr = await _secureStorage.read(key: _keyLastAccessTime);
      if (timeStr == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(int.parse(timeStr));
    } catch (e) {
      return null;
    }
  }

  Future<bool> isSessionExpired() async {
    final lastAccess = await getLastAccessTime();
    if (lastAccess == null) return true;
    
    final now = DateTime.now();
    final difference = now.difference(lastAccess);
    return difference.inMinutes > AppConfig.sessionTimeoutMinutes;
  }

  // Utility Methods
  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    
    // Delete vault files
    if (await _vaultDirectory.exists()) {
      await _vaultDirectory.delete(recursive: true);
    }
    
    // Delete temp files
    if (await _tempDirectory.exists()) {
      await _tempDirectory.delete(recursive: true);
    }
    
    // Recreate directories
    await _initDirectories();
  }

  Future<int> getVaultSize() async {
    int totalSize = 0;
    if (await _vaultDirectory.exists()) {
      await for (final entity in _vaultDirectory.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    }
    return totalSize;
  }

  Directory get vaultDirectory => _vaultDirectory;
  Directory get tempDirectory => _tempDirectory;
}

class SecureStorageException implements Exception {
  final String message;
  SecureStorageException(this.message);
  
  @override
  String toString() => 'SecureStorageException: $message';
}

