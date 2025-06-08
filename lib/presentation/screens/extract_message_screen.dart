import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/steganography/steganography_service.dart';
import '../widgets/secure_text_field.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/progress_dialog.dart';

class ExtractMessageScreen extends ConsumerStatefulWidget {
  const ExtractMessageScreen({super.key});

  @override
  ConsumerState<ExtractMessageScreen> createState() => _ExtractMessageScreenState();
}

class _ExtractMessageScreenState extends ConsumerState<ExtractMessageScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  File? _selectedAudioFile;
  String? _extractedMessage;
  bool _isProcessing = false;
  bool _obscurePassword = true;
  bool _hasHiddenMessage = false;

  final AudioService _audioService = AudioService.instance;
  final SteganographyService _steganographyService = SteganographyService.instance;
  final BiometricService _biometricService = BiometricService.instance;

  @override
  void initState() {
    super.initState();
    _audioService.init();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        if (_audioService.isValidAudioFile(file)) {
          setState(() {
            _selectedAudioFile = file;
            _extractedMessage = null; // Clear previous message
          });
          
          // Check if file potentially contains a hidden message
          final hasMessage = await _steganographyService.hasHiddenMessage(file);
          setState(() {
            _hasHiddenMessage = hasMessage;
          });
          
          if (hasMessage) {
            _showSuccessSnackBar('Audio file selected - hidden message detected!');
          } else {
            _showWarningSnackBar('Audio file selected - no hidden message detected');
          }
        } else {
          _showErrorSnackBar('Please select a valid WAV audio file');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick audio file: $e');
    }
  }

  Future<void> _extractMessage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudioFile == null) {
      _showErrorSnackBar('Please select an audio file');
      return;
    }

    // Request biometric authentication for extraction
    if (await _biometricService.isBiometricEnabled()) {
      final authResult = await _biometricService.authenticateForExtraction();
      if (!authResult) {
        _showErrorSnackBar('Authentication required to extract message');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const ProgressDialog(
            title: 'Extracting Message',
            message: 'Decrypting and extracting hidden message...',
          ),
        );
      }

      // Extract the message
      final message = await _steganographyService.extractMessage(
        audioFile: _selectedAudioFile!,
        password: _passwordController.text,
      );

      setState(() {
        _extractedMessage = message;
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showSuccessSnackBar('Message extracted successfully!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
      }
      
      String errorMessage = 'Failed to extract message';
      if (e.toString().contains('decrypt')) {
        errorMessage = 'Incorrect password or corrupted data';
      } else if (e.toString().contains('Invalid message length')) {
        errorMessage = 'No hidden message found in this audio file';
      }
      
      _showErrorSnackBar('$errorMessage: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _copyMessageToClipboard() async {
    if (_extractedMessage != null) {
      await Clipboard.setData(ClipboardData(text: _extractedMessage!));
      _showSuccessSnackBar('Message copied to clipboard');
    }
  }

  void _clearForm() {
    _passwordController.clear();
    setState(() {
      _selectedAudioFile = null;
      _extractedMessage = null;
      _hasHiddenMessage = false;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Message'),
        centerTitle: true,
        actions: [
          if (_selectedAudioFile != null || _extractedMessage != null)
            IconButton(
              onPressed: _clearForm,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Audio Selection Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Stego Audio File',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      if (_selectedAudioFile == null) ...[
                        ElevatedButton.icon(
                          onPressed: _pickAudioFile,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Pick WAV File'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ] else ...[
                        // Audio File Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasHiddenMessage 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasHiddenMessage 
                                  ? Colors.green
                                  : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _hasHiddenMessage 
                                        ? Icons.lock 
                                        : Icons.warning,
                                    color: _hasHiddenMessage 
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedAudioFile!.path.split('/').last,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAudioFile = null;
                                        _hasHiddenMessage = false;
                                        _extractedMessage = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _hasHiddenMessage
                                    ? 'Hidden message detected in this file'
                                    : 'No hidden message detected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _hasHiddenMessage 
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Audio Player
                        AudioPlayerWidget(audioFile: _selectedAudioFile!),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Password Input Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decryption Password',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      SecureTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: 'Enter the password used for encryption',
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
                            return 'Please enter the decryption password';
                          }
                          return null;
                        },
                        onSubmitted: (_) => _extractMessage(),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Extract Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _extractMessage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: Text(_isProcessing ? 'Extracting...' : 'Extract Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              // Extracted Message Section
              if (_extractedMessage != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.message,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Extracted Message',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _copyMessageToClipboard,
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy to clipboard',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: SelectableText(
                            _extractedMessage!,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Message length: ${_extractedMessage!.length} characters',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

