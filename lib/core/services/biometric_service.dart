import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'secure_storage_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  static BiometricService get instance => _instance;

  late LocalAuthentication _localAuth;
  final SecureStorageService _storageService = SecureStorageService.instance;

  Future<void> init() async {
    _localAuth = LocalAuthentication();
  }

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if biometric authentication is enabled in app settings
  Future<bool> isBiometricEnabled() async {
    return await _storageService.isBiometricEnabled();
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storageService.setBiometricEnabled(enabled);
  }

  /// Authenticate using biometrics
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to access your secure vault',
    bool biometricOnly = false,
  }) async {
    try {
      // Check if biometrics are available
      if (!await isBiometricAvailable()) {
        return BiometricAuthResult.unavailable;
      }

      // Check if biometric is enabled in app
      if (!await isBiometricEnabled()) {
        return BiometricAuthResult.disabled;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedFallbackTitle: 'Use PIN',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Touch sensor',
            biometricNotRecognized: 'Biometric not recognized, try again',
            biometricRequiredTitle: 'Biometric required',
            biometricSuccess: 'Biometric authentication successful',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription: 'Device credentials required',
            goToSettingsButton: 'Go to settings',
            goToSettingsDescription: 'Biometric authentication is not set up on your device',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Biometric authentication is not set up on your device',
            lockOut: 'Biometric authentication is disabled. Please lock and unlock your screen to enable it.',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
        ),
      );

      return didAuthenticate 
          ? BiometricAuthResult.success 
          : BiometricAuthResult.failed;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
          return BiometricAuthResult.unavailable;
        case 'NotEnrolled':
          return BiometricAuthResult.notEnrolled;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.lockedOut;
        case 'UserCancel':
          return BiometricAuthResult.cancelled;
        default:
          return BiometricAuthResult.error;
      }
    } catch (e) {
      return BiometricAuthResult.error;
    }
  }

  /// Get a user-friendly description of available biometric types
  Future<String> getBiometricTypeDescription() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.isEmpty) {
      return 'No biometric authentication available';
    }
    
    final types = <String>[];
    
    if (biometrics.contains(BiometricType.fingerprint)) {
      types.add('Fingerprint');
    }
    if (biometrics.contains(BiometricType.face)) {
      types.add('Face ID');
    }
    if (biometrics.contains(BiometricType.iris)) {
      types.add('Iris');
    }
    if (biometrics.contains(BiometricType.strong)) {
      types.add('Strong Biometric');
    }
    if (biometrics.contains(BiometricType.weak)) {
      types.add('Weak Biometric');
    }
    
    if (types.length == 1) {
      return types.first;
    } else if (types.length == 2) {
      return '${types[0]} and ${types[1]}';
    } else {
      return '${types.sublist(0, types.length - 1).join(', ')}, and ${types.last}';
    }
  }

  /// Check if the user should be prompted to enable biometrics
  Future<bool> shouldPromptForBiometricSetup() async {
    final isAvailable = await isBiometricAvailable();
    final isEnabled = await isBiometricEnabled();
    final hasPrompted = await _storageService.getSetting<bool>('biometric_setup_prompted') ?? false;
    
    return isAvailable && !isEnabled && !hasPrompted;
  }

  /// Mark that the user has been prompted for biometric setup
  Future<void> markBiometricSetupPrompted() async {
    await _storageService.setSetting('biometric_setup_prompted', true);
  }

  /// Authenticate for vault access specifically
  Future<bool> authenticateForVault() async {
    final result = await authenticate(
      reason: 'Authenticate to access your secure audio vault',
    );
    
    return result == BiometricAuthResult.success;
  }

  /// Authenticate for message extraction specifically
  Future<bool> authenticateForExtraction() async {
    final result = await authenticate(
      reason: 'Authenticate to extract hidden message',
    );
    
    return result == BiometricAuthResult.success;
  }
}

enum BiometricAuthResult {
  success,
  failed,
  cancelled,
  unavailable,
  disabled,
  notEnrolled,
  lockedOut,
  error,
}

