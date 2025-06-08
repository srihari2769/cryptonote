import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../core/services/audio_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final File audioFile;
  final bool showWaveform;
  final bool autoPlay;
  final VoidCallback? onPlaybackComplete;

  const AudioPlayerWidget({
    super.key,
    required this.audioFile,
    this.showWaveform = false,
    this.autoPlay = false,
    this.onPlaybackComplete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioService _audioService = AudioService.instance;
  
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get audio file duration (simplified approach)
      final analysis = await _audioService.analyzeAudio(widget.audioFile);
      setState(() {
        _totalDuration = Duration(milliseconds: analysis.duration);
      });

      if (widget.autoPlay) {
        await _playAudio();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize audio player: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _audioService.playAudio(
        widget.audioFile,
        onProgress: (disposition) {
          if (mounted) {
            setState(() {
              _currentPosition = disposition.position;
              _totalDuration = disposition.duration;
            });
          }
        },
      );

      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });

      // Listen for playback completion
      _listenForCompletion();
    } catch (e) {
      _showErrorSnackBar('Failed to play audio: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenForCompletion() {
    // Simple completion detection based on position
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isPlaying) {
        if (_currentPosition >= _totalDuration && _totalDuration > Duration.zero) {
          _onPlaybackComplete();
        } else {
          _listenForCompletion();
        }
      }
    });
  }

  void _onPlaybackComplete() {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = Duration.zero;
    });
    
    widget.onPlaybackComplete?.call();
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioService.pausePlayback();
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to pause audio: $e');
    }
  }

  Future<void> _resumeAudio() async {
    try {
      await _audioService.resumePlayback();
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to resume audio: $e');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioService.stopPlayback();
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = Duration.zero;
      });
    } catch (e) {
      // Ignore errors during disposal
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioService.seekTo(position);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to seek: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // File Info
          Row(
            children: [
              Icon(
                Icons.audio_file,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.audioFile.path.split('/').last,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Duration: ${_formatDuration(_totalDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress Bar
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _totalDuration.inMilliseconds > 0
                      ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                      : 0.0,
                  onChanged: (value) {
                    final position = Duration(
                      milliseconds: (value * _totalDuration.inMilliseconds).round(),
                    );
                    _seekTo(position);
                  },
                  activeColor: theme.colorScheme.primary,
                  inactiveColor: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              
              // Time Labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop Button
              IconButton(
                onPressed: _isPlaying || _isPaused ? _stopPlayback : null,
                icon: const Icon(Icons.stop),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Play/Pause Button
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isLoading
                      ? null
                      : _isPlaying
                          ? _pauseAudio
                          : _isPaused
                              ? _resumeAudio
                              : _playAudio,
                  icon: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Volume Button (placeholder)
              IconButton(
                onPressed: () {
                  // TODO: Implement volume control
                },
                icon: const Icon(Icons.volume_up),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          // Waveform (if enabled)
          if (widget.showWaveform) ...[
            const SizedBox(height: 16),
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Center(
                child: Text(
                  'Waveform visualization\n(Coming soon)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

