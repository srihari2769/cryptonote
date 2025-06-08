import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/steganography/steganography_service.dart';
import '../../core/models/vault_item.dart';
import '../widgets/secure_text_field.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/progress_dialog.dart';

class EmbedMessageScreen extends ConsumerStatefulWidget {
  const EmbedMessageScreen({super.key});

  @override
  ConsumerState<EmbedMessageScreen> createState() => _EmbedMessageScreenState();
}

class _EmbedMessageScreenState extends ConsumerState<EmbedMessageScreen> {
  final _messageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  File? _selectedAudioFile;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _obscurePassword = true;
  int _messageCapacity = 0;

  final AudioService _audioService = AudioService.instance;
  final SteganographyService _steganographyService = SteganographyService.instance;
  final SecureStorageService _storageService = SecureStorageService.instance;

  @override
  void initState() {
    super.initState();
    _audioService.init();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
          });
          
          // Calculate message capacity
          final capacity = await _steganographyService.getMessageCapacity(file);
          setState(() {
            _messageCapacity = capacity;
          });
          
          _showSuccessSnackBar('Audio file selected successfully');
        } else {
          _showErrorSnackBar('Please select a valid WAV audio file');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick audio file: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioService.hasMicrophonePermission()) {
        final granted = await _audioService.requestMicrophonePermission();
        if (!granted) {
          _showErrorSnackBar('Microphone permission is required to record audio');
          return;
        }
      }

      setState(() {
        _isRecording = true;
      });

      await _audioService.startRecording(
        fileName: 'recording_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      _showSuccessSnackBar('Recording started');
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final recordedFile = await _audioService.stopRecording();
      
      setState(() {
        _isRecording = false;
      });

      if (recordedFile != null) {
        setState(() {
          _selectedAudioFile = recordedFile;
        });
        
        // Calculate message capacity
        final capacity = await _steganographyService.getMessageCapacity(recordedFile);
        setState(() {
          _messageCapacity = capacity;
        });
        
        _showSuccessSnackBar('Recording completed');
      } else {
        _showErrorSnackBar('Failed to save recording');
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showErrorSnackBar('Failed to stop recording: $e');
    }
  }

  Future<void> _embedMessage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudioFile == null) {
      _showErrorSnackBar('Please select or record an audio file');
      return;
    }

    // Check message size
    final messageBytes = _messageController.text.length;
    if (messageBytes > _messageCapacity) {
      _showErrorSnackBar(
        'Message too long. Maximum: $_messageCapacity characters, Current: $messageBytes'
      );
      return;
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
            title: 'Embedding Message',
            message: 'Encrypting and embedding your message...',
          ),
        );
      }

      // Generate output file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName = 'stego_$timestamp.wav';
      final outputPath = '${_storageService.tempDirectory.path}/$outputFileName';

      // Embed the message
      final stegoFile = await _steganographyService.embedMessage(
        audioFile: _selectedAudioFile!,
        message: _messageController.text,
        password: _passwordController.text,
        outputPath: outputPath,
      );

      // Save to vault
      final vaultFileName = '${DateTime.now().millisecondsSinceEpoch}.wav';
      final vaultFile = await _storageService.saveToVault(stegoFile, vaultFileName);

      // Create vault item
      final vaultItem = VaultItem(
        name: _nameController.text.isNotEmpty 
            ? _nameController.text 
            : 'Stego Audio ${DateTime.now().day}/${DateTime.now().month}',
        fileName: vaultFileName,
        originalFileName: _selectedAudioFile!.path.split('/').last,
        fileSize: await vaultFile.length(),
        description: 'Hidden message embedded',
        type: VaultItemType.stegoAudio,
        metadata: {
          'messageLength': _messageController.text.length,
          'originalFileSize': await _selectedAudioFile!.length(),
        },
      );

      await _storageService.addVaultItem(vaultItem);

      // Clean up temp file
      if (await stegoFile.exists()) {
        await stegoFile.delete();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showSuccessSnackBar('Message embedded and saved to vault successfully');
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
      }
      _showErrorSnackBar('Failed to embed message: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearForm() {
    _messageController.clear();
    _passwordController.clear();
    _nameController.clear();
    setState(() {
      _selectedAudioFile = null;
      _messageCapacity = 0;
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
        title: const Text('Embed Message'),
        centerTitle: true,
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
                        'Select Audio File',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      if (_selectedAudioFile == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickAudioFile,
                                icon: const Icon(Icons.file_upload),
                                label: const Text('Pick WAV File'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isRecording ? _stopRecording : _startRecording,
                                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                label: Text(_isRecording ? 'Stop Recording' : 'Record Audio'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRecording ? Colors.red : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Audio File Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.audio_file),
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
                                        _messageCapacity = 0;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              if (_messageCapacity > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Message capacity: $_messageCapacity characters',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Audio Player
                        if (_selectedAudioFile != null)
                          AudioPlayerWidget(audioFile: _selectedAudioFile!),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Message Input Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message to Hide',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Secret Message',
                          hintText: 'Enter your secret message here...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a message to hide';
                          }
                          if (_messageCapacity > 0 && value.length > _messageCapacity) {
                            return 'Message too long (max: $_messageCapacity characters)';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {}); // Update character count
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Characters: ${_messageController.text.length}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (_messageCapacity > 0)
                            Text(
                              'Remaining: ${_messageCapacity - _messageController.text.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _messageController.text.length > _messageCapacity
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Security Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Settings',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      SecureTextField(
                        controller: _passwordController,
                        labelText: 'Encryption Password',
                        hintText: 'Enter a strong password',
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
                            return 'Please enter an encryption password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'File Name (Optional)',
                          hintText: 'Enter a name for this stego file',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Embed Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _embedMessage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock),
                  label: Text(_isProcessing ? 'Embedding...' : 'Embed Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

