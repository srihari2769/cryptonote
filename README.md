# Covert Audio - Secure Message Communication

A Flutter mobile application for covert message communication using audio steganography and AES-256-GCM encryption. This app allows users to securely hide encrypted messages inside audio files using advanced cryptographic techniques.

## 🔐 Features

### Core Security
- **AES-256-GCM Encryption** with integrity verification
- **PBKDF2 Key Derivation** (SHA-256, 100,000 iterations, 16-byte salt)
- **LSB Steganography** for WAV files with 4-byte message length headers
- **Biometric Authentication** (Fingerprint/Face ID) for vault access
- **Secure Storage** using flutter_secure_storage

### Audio Processing
- **WAV File Support** with comprehensive header parsing
- **Audio Recording** with high-quality settings (44.1kHz, 16-bit)
- **Playback Controls** with seek, pause, and progress tracking
- **Waveform Visualization** and analysis
- **Message Capacity Calculation** for optimal embedding

### User Experience
- **Material 3 Design** with comprehensive theming
- **Dark Mode Support** with automatic system detection
- **Intuitive Navigation** with bottom tab bar
- **Comprehensive Error Handling** with user-friendly messages
- **Progress Indicators** for long-running operations

### Vault System
- **Encrypted File Storage** with metadata tracking
- **Search and Sort** functionality
- **File Sharing** capabilities
- **Storage Usage** monitoring
- **Biometric Protection** for sensitive operations

## 📱 Screenshots

*Screenshots will be added after UI implementation*

## 🏗️ Architecture

### Core Modules

#### 1. Encryption Module (`lib/core/encryption/`)
- **Algorithm**: AES-256-GCM for confidentiality and integrity
- **Key Derivation**: PBKDF2 with SHA-256, 100,000 iterations
- **Output Format**: base64(salt + nonce + ciphertext + mac)

#### 2. Steganography Module (`lib/core/steganography/`)
- **Format**: WAV files (lossless audio)
- **Technique**: Least Significant Bit (LSB) embedding
- **Header**: 4-byte big-endian message length
- **Capacity**: Automatic calculation based on audio file size

#### 3. Audio Handling (`lib/core/services/audio_service.dart`)
- **Recording**: flutter_sound with configurable quality
- **Playback**: Multiple audio players for compatibility
- **Analysis**: Comprehensive audio file analysis
- **Formats**: WAV support with future extensibility

#### 4. Security Services
- **Biometric Service**: Local authentication with fallback
- **Secure Storage**: Encrypted local storage for vault items
- **Session Management**: Automatic timeout and re-authentication

### UI Architecture

#### Screens
1. **Splash Screen**: Animated loading with authentication check
2. **Authentication Screen**: Biometric and password authentication
3. **Home Screen**: Bottom navigation with four main tabs
4. **Embed Message Screen**: Complete message embedding workflow
5. **Extract Message Screen**: Message extraction with authentication
6. **Vault Screen**: Secure file management
7. **Settings Screen**: App configuration and security settings

#### Custom Widgets
- **SecureTextField**: Enhanced password input with strength indicator
- **AudioPlayerWidget**: Full-featured audio playback controls
- **WaveformWidget**: Audio visualization components
- **ProgressDialog**: Loading dialogs for operations
- **AnimatedLogo**: Animated branding elements

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode for platform-specific development
- Device with microphone for audio recording
- Device with biometric authentication (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/covert-audio.git
   cd covert-audio
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure platform permissions**
   
   **Android**: Permissions are already configured in `android/app/src/main/AndroidManifest.xml`
   
   **iOS**: Permissions are already configured in `ios/Runner/Info.plist`

4. **Run the application**
   ```bash
   flutter run
   ```

### Building for Release

#### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## 🔧 Configuration

### Audio Settings
- **Sample Rate**: 44.1 kHz (configurable in `app_config.dart`)
- **Bit Depth**: 16-bit
- **Channels**: Mono for recording, supports stereo playback
- **Format**: WAV (lossless)

### Security Settings
- **Encryption**: AES-256-GCM
- **Key Derivation**: PBKDF2 (100,000 iterations)
- **Salt Length**: 16 bytes
- **Nonce Length**: 12 bytes (GCM standard)

### Session Management
- **Timeout**: 15 minutes (configurable)
- **Max Password Attempts**: 3
- **Biometric Fallback**: Password authentication

## 📚 Usage

### Embedding a Message

1. **Select Audio**: Choose a WAV file or record new audio
2. **Enter Message**: Type your secret message
3. **Set Password**: Choose a strong encryption password
4. **Embed**: The app encrypts and hides the message in the audio
5. **Save to Vault**: Encrypted stego file is saved securely

### Extracting a Message

1. **Select Stego Audio**: Choose an audio file with hidden message
2. **Enter Password**: Provide the decryption password
3. **Authenticate**: Use biometric or password authentication
4. **Extract**: The app decrypts and reveals the hidden message

### Vault Management

- **View Files**: Browse all stored stego audio files
- **Search**: Find files by name or description
- **Sort**: Organize by date, size, or name
- **Share**: Export files securely
- **Delete**: Remove files permanently

## 🔒 Security Considerations

### Encryption
- Uses industry-standard AES-256-GCM encryption
- PBKDF2 key derivation with high iteration count
- Cryptographically secure random number generation
- Integrity verification with GCM authentication

### Steganography
- LSB technique minimizes audio quality impact
- Message length header prevents detection attempts
- Capacity calculation prevents overflow
- Support for error detection and correction

### Storage
- All sensitive data encrypted at rest
- Biometric authentication for vault access
- Secure key management
- Session timeout for security

### Privacy
- No network communication for core functionality
- Local processing of all sensitive data
- Optional cloud sync with zero-knowledge encryption
- No telemetry or analytics collection

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Security Testing
- Encryption/decryption validation
- Steganography capacity testing
- Authentication flow testing
- Storage security verification

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter/Dart style guidelines
- Add tests for new features
- Update documentation
- Ensure security best practices
- Test on both Android and iOS

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔮 Future Enhancements

### Planned Features
- **Multi-Layer Steganography**: Combine audio with image/video layers
- **Error Correction Codes**: Reed-Solomon or Hamming codes for reliability
- **MP3 Support**: Advanced LSB strategies for lossy formats
- **Steganalysis Shield**: Randomized bit-distribution for detection avoidance
- **Voice-to-Text Embedder**: Speech recognition for message input
- **Desktop Companion**: Cross-platform sync and management
- **Cloud Vault Sync**: Zero-knowledge encrypted backup
- **Waveform Editor**: Visual embedding location selection
- **Plugin Marketplace**: Additional steganography techniques
- **Audio Watermarking**: Copyright and origin signatures
- **Real-Time Stego**: Live audio stream embedding

### Technical Improvements
- **Performance Optimization**: Large file handling
- **Battery Optimization**: Background processing
- **Accessibility**: Screen reader support
- **Internationalization**: Multi-language support
- **Advanced Analytics**: Usage insights (privacy-preserving)

## 📞 Support

For support, questions, or feature requests:
- Create an issue on GitHub
- Contact: [your-email@example.com]
- Documentation: [Wiki/Docs link]

## 🙏 Acknowledgments

- Flutter team for the excellent framework
- Cryptography library maintainers
- Audio processing library contributors
- Security research community
- Open source community

---

**⚠️ Disclaimer**: This application is for educational and legitimate privacy purposes only. Users are responsible for complying with local laws and regulations regarding encryption and steganography.

