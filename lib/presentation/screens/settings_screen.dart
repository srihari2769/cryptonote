import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/app_config.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/biometric_service.dart';
import '../widgets/secure_text_field.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SecureStorageService _storageService = SecureStorageService.instance;
  final BiometricService _biometricService = BiometricService.instance;
  
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = '';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final biometricEnabled = await _biometricService.isBiometricEnabled();
      final biometricAvailable = await _biometricService.isBiometricAvailable();
      final biometricType = await _biometricService.getBiometricTypeDescription();
      
      setState(() {
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
        _biometricType = biometricType;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled && _biometricAvailable) {
      // Test biometric authentication before enabling
      final authResult = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric security',
      );
      
      if (authResult == BiometricAuthResult.success) {
        await _biometricService.setBiometricEnabled(true);
        setState(() {
          _biometricEnabled = true;
        });
        _showSuccessSnackBar('Biometric authentication enabled');
      } else {
        _showErrorSnackBar('Biometric authentication failed');
      }
    } else {
      await _biometricService.setBiometricEnabled(false);
      setState(() {
        _biometricEnabled = false;
      });
      _showSuccessSnackBar('Biometric authentication disabled');
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showClearDataConfirmation();
    if (!confirmed) return;

    try {
      await _storageService.clearAllData();
      _showSuccessSnackBar('All data cleared successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to clear data: $e');
    }
  }

  Future<bool> _showClearDataConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all vault items, settings, and cached data. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _changePassword() async {
    final newPassword = await _showPasswordChangeDialog();
    if (newPassword != null) {
      try {
        final passwordHash = newPassword.hashCode.toString();
        await _storageService.setSetting('app_password_hash', passwordHash);
        _showSuccessSnackBar('Password changed successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to change password: $e');
      }
    }
  }

  Future<String?> _showPasswordChangeDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SecureTextField(
                controller: currentPasswordController,
                labelText: 'Current Password',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SecureTextField(
                controller: newPasswordController,
                labelText: 'New Password',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SecureTextField(
                controller: confirmPasswordController,
                labelText: 'Confirm New Password',
                obscureText: true,
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(newPasswordController.text);
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion: AppConfig.appVersion,
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.security,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        Text(AppConfig.appDescription),
        const SizedBox(height: 16),
        const Text(
          'This application uses AES-256-GCM encryption and LSB steganography '
          'to securely hide messages in audio files.',
        ),
      ],
    );
  }

  void _showSecurityInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Encryption:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• AES-256-GCM for message encryption'),
              Text('• PBKDF2 key derivation (100,000 iterations)'),
              Text('• SHA-256 hashing'),
              SizedBox(height: 16),
              Text(
                'Steganography:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• LSB (Least Significant Bit) technique'),
              Text('• WAV file format support'),
              Text('• 4-byte message length headers'),
              SizedBox(height: 16),
              Text(
                'Storage:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Encrypted local storage'),
              Text('• Biometric authentication'),
              Text('• Secure key management'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Security Section
                _buildSectionHeader('Security', theme),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Biometric Authentication'),
                        subtitle: Text(
                          _biometricAvailable
                              ? 'Secure vault access with $_biometricType'
                              : 'Not available on this device',
                        ),
                        value: _biometricEnabled,
                        onChanged: _biometricAvailable ? _toggleBiometric : null,
                        secondary: const Icon(Icons.fingerprint),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your app password'),
                        leading: const Icon(Icons.lock_reset),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePassword,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Security Information'),
                        subtitle: const Text('View encryption details'),
                        leading: const Icon(Icons.info_outline),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showSecurityInfo,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Storage Section
                _buildSectionHeader('Storage', theme),
                Card(
                  child: Column(
                    children: [
                      FutureBuilder<int>(
                        future: _storageService.getVaultSize(),
                        builder: (context, snapshot) {
                          final sizeInMB = snapshot.hasData 
                              ? (snapshot.data! / (1024 * 1024)).toStringAsFixed(1)
                              : '0.0';
                          return ListTile(
                            title: const Text('Vault Storage'),
                            subtitle: Text('$sizeInMB MB used'),
                            leading: const Icon(Icons.storage),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      FutureBuilder<List>(
                        future: _storageService.getVaultItems(),
                        builder: (context, snapshot) {
                          final itemCount = snapshot.hasData ? snapshot.data!.length : 0;
                          return ListTile(
                            title: const Text('Vault Items'),
                            subtitle: Text('$itemCount item${itemCount == 1 ? '' : 's'}'),
                            leading: const Icon(Icons.folder),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Clear All Data'),
                        subtitle: const Text('Delete all vault items and settings'),
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _clearAllData,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Audio Section
                _buildSectionHeader('Audio', theme),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Supported Formats'),
                        subtitle: Text(AppConfig.supportedAudioFormats.join(', ').toUpperCase()),
                        leading: const Icon(Icons.audio_file),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Sample Rate'),
                        subtitle: Text('${AppConfig.sampleRate} Hz'),
                        leading: const Icon(Icons.graphic_eq),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Bit Depth'),
                        subtitle: Text('${AppConfig.bitDepth} bit'),
                        leading: const Icon(Icons.settings_input_component),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader('About', theme),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(AppConfig.appName),
                        subtitle: Text('Version ${AppConfig.appVersion}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAboutDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('View our privacy policy'),
                        leading: const Icon(Icons.privacy_tip),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Implement privacy policy view
                          _showErrorSnackBar('Privacy policy not implemented yet');
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Terms of Service'),
                        subtitle: const Text('View terms of service'),
                        leading: const Icon(Icons.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Implement terms of service view
                          _showErrorSnackBar('Terms of service not implemented yet');
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Footer
                Center(
                  child: Text(
                    'Covert Audio - Secure Message Communication',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

