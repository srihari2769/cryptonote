import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_analysis.dart';
import 'secure_storage_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static AudioService get instance => _instance;

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  AudioPlayer? _audioPlayer;
  final SecureStorageService _storageService = SecureStorageService.instance;

  bool get isRecording => _recorder?.isRecording ?? false;
  bool get isPlaying => _player?.isPlaying ?? false;

  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _audioPlayer = AudioPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  Future<void> dispose() async {
    await _recorder?.closeRecorder();
    await _player?.closePlayer();
    await _audioPlayer?.dispose();
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  /// Start recording audio
  Future<void> startRecording({
    String? fileName,
    Function(RecordingDisposition)? onProgress,
  }) async {
    if (!await hasMicrophonePermission()) {
      throw AudioException('Microphone permission not granted');
    }

    if (isRecording) {
      throw AudioException('Already recording');
    }

    final tempDir = _storageService.tempDirectory;
    final recordingPath = '${tempDir.path}/${fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.wav'}';

    await _recorder!.startRecorder(
      toFile: recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 44100,
      numChannels: 1,
    );

    if (onProgress != null) {
      _recorder!.onProgress!.listen(onProgress);
    }
  }

  /// Stop recording and return the recorded file
  Future<File?> stopRecording() async {
    if (!isRecording) {
      return null;
    }

    final path = await _recorder!.stopRecorder();
    if (path != null) {
      return File(path);
    }
    return null;
  }

  /// Play an audio file
  Future<void> playAudio(File audioFile, {Function(PlaybackDisposition)? onProgress}) async {
    if (isPlaying) {
      await stopPlayback();
    }

    await _player!.startPlayer(
      fromURI: audioFile.path,
      codec: Codec.pcm16WAV,
    );

    if (onProgress != null) {
      _player!.onProgress!.listen(onProgress);
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    if (isPlaying) {
      await _player!.stopPlayer();
    }
  }

  /// Pause audio playback
  Future<void> pausePlayback() async {
    if (isPlaying) {
      await _player!.pausePlayer();
    }
  }

  /// Resume audio playback
  Future<void> resumePlayback() async {
    await _player!.resumePlayer();
  }

  /// Seek to a specific position in the audio
  Future<void> seekTo(Duration position) async {
    await _player!.seekToPlayer(position);
  }

  /// Get the current playback position
  Duration? get currentPosition => _player?.playerState.position;

  /// Get the total duration of the currently loaded audio
  Duration? get duration => _player?.playerState.duration;

  /// Play audio using AudioPlayer (alternative player)
  Future<void> playAudioWithPlayer(File audioFile) async {
    await _audioPlayer!.play(DeviceFileSource(audioFile.path));
  }

  /// Stop audio using AudioPlayer
  Future<void> stopAudioPlayer() async {
    await _audioPlayer!.stop();
  }

  /// Analyze an audio file and return detailed information
  Future<AudioAnalysis> analyzeAudio(File audioFile) async {
    try {
      final fileStats = await audioFile.stat();
      final audioBytes = await audioFile.readAsBytes();
      
      // Parse WAV file header to get audio properties
      final audioProperties = _parseWavHeader(audioBytes);
      
      // Generate waveform data (simplified)
      final waveformData = _generateWaveformData(audioBytes, audioProperties);
      
      // Calculate audio quality
      final quality = _calculateAudioQuality(audioProperties);
      
      // Check for hidden messages
      final hasHiddenMessage = await _checkForHiddenMessage(audioFile);
      
      // Calculate message capacity
      final messageCapacity = _calculateMessageCapacity(audioProperties);

      return AudioAnalysis(
        filePath: audioFile.path,
        duration: audioProperties['duration'] ?? 0,
        sampleRate: audioProperties['sampleRate'] ?? 0,
        channels: audioProperties['channels'] ?? 0,
        bitDepth: audioProperties['bitDepth'] ?? 0,
        fileSize: fileStats.size,
        averageAmplitude: waveformData.isNotEmpty 
            ? waveformData.reduce((a, b) => a + b) / waveformData.length 
            : 0.0,
        maxAmplitude: waveformData.isNotEmpty 
            ? waveformData.reduce((a, b) => a > b ? a : b) 
            : 0.0,
        minAmplitude: waveformData.isNotEmpty 
            ? waveformData.reduce((a, b) => a < b ? a : b) 
            : 0.0,
        waveformData: waveformData,
        quality: quality,
        hasHiddenMessage: hasHiddenMessage,
        messageCapacity: messageCapacity,
      );
    } catch (e) {
      throw AudioException('Failed to analyze audio: $e');
    }
  }

  /// Parse WAV file header to extract audio properties
  Map<String, dynamic> _parseWavHeader(Uint8List bytes) {
    if (bytes.length < 44) {
      throw AudioException('Invalid WAV file: too small');
    }

    // Check RIFF header
    final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffHeader != 'RIFF') {
      throw AudioException('Invalid WAV file: missing RIFF header');
    }

    // Check WAVE format
    final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveFormat != 'WAVE') {
      throw AudioException('Invalid WAV file: not WAVE format');
    }

    // Extract audio properties
    final channels = _bytesToInt16(bytes.sublist(22, 24));
    final sampleRate = _bytesToInt32(bytes.sublist(24, 28));
    final bitDepth = _bytesToInt16(bytes.sublist(34, 36));
    final dataSize = _bytesToInt32(bytes.sublist(40, 44));
    
    final duration = (dataSize / (sampleRate * channels * (bitDepth / 8)) * 1000).round();

    return {
      'channels': channels,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'dataSize': dataSize,
      'duration': duration,
    };
  }

  /// Generate simplified waveform data for visualization
  List<double> _generateWaveformData(Uint8List bytes, Map<String, dynamic> properties) {
    final dataOffset = 44; // Standard WAV header size
    final dataSize = properties['dataSize'] as int;
    final bitDepth = properties['bitDepth'] as int;
    final channels = properties['channels'] as int;
    
    if (bytes.length < dataOffset + dataSize) {
      return [];
    }

    final audioData = bytes.sublist(dataOffset, dataOffset + dataSize);
    final waveform = <double>[];
    
    // Sample every 1000th point for visualization
    final sampleStep = (audioData.length / (bitDepth ~/ 8) / channels / 1000).round();
    if (sampleStep <= 0) return [];
    
    for (int i = 0; i < audioData.length - (bitDepth ~/ 8); i += sampleStep * (bitDepth ~/ 8) * channels) {
      double sample = 0.0;
      
      if (bitDepth == 16) {
        final value = _bytesToInt16(audioData.sublist(i, i + 2));
        sample = value / 32768.0; // Normalize to -1.0 to 1.0
      } else if (bitDepth == 8) {
        final value = audioData[i];
        sample = (value - 128) / 128.0; // Normalize to -1.0 to 1.0
      }
      
      waveform.add(sample.abs()); // Use absolute value for visualization
    }
    
    return waveform;
  }

  /// Calculate audio quality based on properties
  AudioQuality _calculateAudioQuality(Map<String, dynamic> properties) {
    final sampleRate = properties['sampleRate'] as int;
    final bitDepth = properties['bitDepth'] as int;
    final channels = properties['channels'] as int;
    
    int score = 0;
    
    // Sample rate scoring
    if (sampleRate >= 44100) score += 3;
    else if (sampleRate >= 22050) score += 2;
    else if (sampleRate >= 11025) score += 1;
    
    // Bit depth scoring
    if (bitDepth >= 16) score += 2;
    else if (bitDepth >= 8) score += 1;
    
    // Channel scoring
    if (channels >= 1) score += 1;
    
    if (score >= 5) return AudioQuality.excellent;
    if (score >= 4) return AudioQuality.good;
    if (score >= 2) return AudioQuality.fair;
    return AudioQuality.poor;
  }

  /// Check if audio file potentially contains hidden messages
  Future<bool> _checkForHiddenMessage(File audioFile) async {
    try {
      // This is a simplified check - in a real implementation,
      // you might use more sophisticated steganalysis techniques
      final bytes = await audioFile.readAsBytes();
      if (bytes.length < 48) return false;
      
      // Extract potential message length from LSBs
      int messageLength = 0;
      for (int i = 44; i < 48 && i < bytes.length; i++) {
        messageLength = (messageLength << 8) | (bytes[i] & 1);
      }
      
      return messageLength > 0 && messageLength < bytes.length;
    } catch (e) {
      return false;
    }
  }

  /// Calculate maximum message capacity for steganography
  int _calculateMessageCapacity(Map<String, dynamic> properties) {
    final dataSize = properties['dataSize'] as int;
    // Each byte can hide 1 bit, minus 4 bytes for length header
    return (dataSize - 32) ~/ 8; // Convert bits to bytes
  }

  /// Convert bytes to 16-bit integer (little-endian)
  int _bytesToInt16(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8);
  }

  /// Convert bytes to 32-bit integer (little-endian)
  int _bytesToInt32(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  /// Convert audio file to different format (if needed)
  Future<File> convertToWav(File inputFile) async {
    // For now, assume input is already WAV
    // In a full implementation, you might use FFmpeg or similar
    return inputFile;
  }

  /// Get supported audio formats
  List<String> get supportedFormats => ['wav'];

  /// Validate if file is a supported audio format
  bool isValidAudioFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return supportedFormats.contains(extension);
  }
}

class AudioException implements Exception {
  final String message;
  AudioException(this.message);
  
  @override
  String toString() => 'AudioException: $message';
}

