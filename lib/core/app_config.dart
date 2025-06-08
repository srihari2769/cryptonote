class AppConfig {
  static const String appName = 'Covert Audio';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Secure message communication through audio steganography';
  
  // Encryption Configuration
  static const int aesKeyLength = 32; // 256 bits
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 16;
  static const int nonceLength = 12; // GCM nonce
  
  // Audio Configuration
  static const List<String> supportedAudioFormats = ['wav'];
  static const int sampleRate = 44100;
  static const int bitDepth = 16;
  
  // Steganography Configuration
  static const int lsbBitsPerSample = 1;
  static const int messageLengthHeaderBytes = 4;
  
  // Security Configuration
  static const int maxPasswordAttempts = 3;
  static const int sessionTimeoutMinutes = 15;
  
  // Storage Configuration
  static const String vaultDirectoryName = 'covert_audio_vault';
  static const String tempDirectoryName = 'temp';
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 2);
}

