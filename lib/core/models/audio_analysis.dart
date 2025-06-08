class AudioAnalysis {
  final String filePath;
  final int duration; // in milliseconds
  final int sampleRate;
  final int channels;
  final int bitDepth;
  final int fileSize;
  final double averageAmplitude;
  final double maxAmplitude;
  final double minAmplitude;
  final List<double> waveformData;
  final AudioQuality quality;
  final bool hasHiddenMessage;
  final int? messageCapacity; // in bytes
  final Map<String, dynamic> metadata;

  AudioAnalysis({
    required this.filePath,
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
    required this.fileSize,
    required this.averageAmplitude,
    required this.maxAmplitude,
    required this.minAmplitude,
    required this.waveformData,
    required this.quality,
    required this.hasHiddenMessage,
    this.messageCapacity,
    this.metadata = const {},
  });

  String get formattedDuration {
    final seconds = duration ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedSampleRate {
    if (sampleRate >= 1000) {
      return '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
    } else {
      return '$sampleRate Hz';
    }
  }

  String get channelDescription {
    switch (channels) {
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      default:
        return '$channels channels';
    }
  }

  String get qualityDescription {
    switch (quality) {
      case AudioQuality.excellent:
        return 'Excellent';
      case AudioQuality.good:
        return 'Good';
      case AudioQuality.fair:
        return 'Fair';
      case AudioQuality.poor:
        return 'Poor';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'duration': duration,
      'sampleRate': sampleRate,
      'channels': channels,
      'bitDepth': bitDepth,
      'fileSize': fileSize,
      'averageAmplitude': averageAmplitude,
      'maxAmplitude': maxAmplitude,
      'minAmplitude': minAmplitude,
      'waveformData': waveformData,
      'quality': quality.name,
      'hasHiddenMessage': hasHiddenMessage,
      'messageCapacity': messageCapacity,
      'metadata': metadata,
    };
  }

  factory AudioAnalysis.fromJson(Map<String, dynamic> json) {
    return AudioAnalysis(
      filePath: json['filePath'],
      duration: json['duration'],
      sampleRate: json['sampleRate'],
      channels: json['channels'],
      bitDepth: json['bitDepth'],
      fileSize: json['fileSize'],
      averageAmplitude: json['averageAmplitude'],
      maxAmplitude: json['maxAmplitude'],
      minAmplitude: json['minAmplitude'],
      waveformData: List<double>.from(json['waveformData']),
      quality: AudioQuality.values.firstWhere(
        (e) => e.name == json['quality'],
        orElse: () => AudioQuality.fair,
      ),
      hasHiddenMessage: json['hasHiddenMessage'],
      messageCapacity: json['messageCapacity'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

enum AudioQuality {
  excellent, // High sample rate, good bit depth, low noise
  good,      // Standard quality, suitable for steganography
  fair,      // Acceptable quality, may have some limitations
  poor,      // Low quality, not recommended for steganography
}

class WaveformPoint {
  final double time; // in seconds
  final double amplitude; // normalized -1.0 to 1.0

  WaveformPoint({
    required this.time,
    required this.amplitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'amplitude': amplitude,
    };
  }

  factory WaveformPoint.fromJson(Map<String, dynamic> json) {
    return WaveformPoint(
      time: json['time'],
      amplitude: json['amplitude'],
    );
  }
}

class AudioSpectrum {
  final List<double> frequencies;
  final List<double> magnitudes;
  final double peakFrequency;
  final double dominantFrequency;

  AudioSpectrum({
    required this.frequencies,
    required this.magnitudes,
    required this.peakFrequency,
    required this.dominantFrequency,
  });

  Map<String, dynamic> toJson() {
    return {
      'frequencies': frequencies,
      'magnitudes': magnitudes,
      'peakFrequency': peakFrequency,
      'dominantFrequency': dominantFrequency,
    };
  }

  factory AudioSpectrum.fromJson(Map<String, dynamic> json) {
    return AudioSpectrum(
      frequencies: List<double>.from(json['frequencies']),
      magnitudes: List<double>.from(json['magnitudes']),
      peakFrequency: json['peakFrequency'],
      dominantFrequency: json['dominantFrequency'],
    );
  }
}

