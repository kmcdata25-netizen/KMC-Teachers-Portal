
/// Central Configuration for Kasarani Music Center Native Agora RTC Video/Audio Engine.
/// Powers the Native In-App "KMC Live Music Studio" for faculty masterclasses and student practice.
class AgoraConfig {
  AgoraConfig._();

  /// Default Agora App ID configured at build time or via environment variable.
  /// To pass during build: flutter build apk --dart-define=AGORA_APP_ID=your_app_id
  static const String _envAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: '');

  /// Runtime override if injected via Central Mind / Admin App
  static String? _runtimeAppId;

  /// Set the active App ID dynamically at runtime
  static void setAppId(String id) {
    _runtimeAppId = id.trim();
  }

  /// Active Agora App ID
  static String get appId {
    if (_runtimeAppId != null && _runtimeAppId!.isNotEmpty) {
      return _runtimeAppId!;
    }
    return _envAppId;
  }

  /// Whether an Agora App ID is provided and real-time cloud streaming is active
  static bool get isConfigured => appId.isNotEmpty;

  /// High-Fidelity Music Profile documentation:
  /// Kasarani Music Center uses 48kHz full-band stereo audio with AI noise suppression
  /// tuned specifically to preserve acoustic instrument resonance (pianos, violins, guitars, vocal timbre).
}
