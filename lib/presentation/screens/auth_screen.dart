import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../widgets/secure_text_field.dart';
import 'home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _attemptBiometricAuth();
  }

  Future<void> _attemptBiometricAuth() async {
    final biometricService = BiometricService.instance;
    
    if (await biometricService.isBiometricEnabled()) {
      final result = await biometricService.authenticate(
        reason: 'Authenticate to access Covert Audio',
      );
      
      if (result == BiometricAuthResult.success) {
        await _navigateToHome();
      }
    }
  }

  Future<void> _authenticateWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, you would verify the password against a stored hash
      // For this demo, we'll use a simple check
      final storedPasswordHash = await SecureStorageService.instance
          .getSetting<String>('app_password_hash');
      
      if (storedPasswordHash == null) {
        // First time setup - set the password
        await _setNewPassword();
      } else {
        // Verify password
        final enteredPasswordHash = _hashPassword(_passwordController.text);
        if (enteredPasswordHash == storedPasswordHash) {
          await _navigateToHome();
        } else {
          _handleFailedAuth();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Authentication failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setNewPassword() async {
    final passwordHash = _hashPassword(_passwordController.text);
    await SecureStorageService.instance.setSetting('app_password_hash', passwordHash);
    await _navigateToHome();
  }

  String _hashPassword(String password) {
    // Simple hash for demo - in production use proper hashing
    return password.hashCode.toString();
  }

  void _handleFailedAuth() {
    setState(() {
      _failedAttempts++;
    });

    if (_failedAttempts >= 3) {
      _showErrorSnackBar('Too many failed attempts. Please try again later.');
      // In a real app, you might implement a lockout period
    } else {
      _showErrorSnackBar('Invalid password. ${3 - _failedAttempts} attempts remaining.');
    }
    
    _passwordController.clear();
  }

  Future<void> _navigateToHome() async {
    await SecureStorageService.instance.updateLastAccessTime();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Welcome Back',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Please authenticate to continue',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Authentication Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SecureTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                        onSubmitted: (_) => _authenticateWithPassword(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Authenticate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _authenticateWithPassword,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Authenticate',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Biometric Authentication Button
                FutureBuilder<bool>(
                  future: BiometricService.instance.isBiometricAvailable(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _attemptBiometricAuth,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Use Biometric Authentication'),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

