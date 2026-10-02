import 'package:shared_preferences/shared_preferences.dart';

/// Central Configuration for Kasarani Music Center Native Agora RTC Video/Audio Engine.
/// Powers the Native In-App "KMC Live Music Studio" for faculty masterclasses and student practice.
class AgoraConfig {
  AgoraConfig._();

  static const String _envAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  static const String _prefKey = 'kmc_agora_app_id';
  static String? _runtimeAppId;

  /// Load persisted App ID from local device storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        _runtimeAppId = saved.trim();
      }
    } catch (_) {}
  }

  /// Persist new Agora App ID dynamically at runtime
  static Future<void> saveAppId(String id) async {
    _runtimeAppId = id.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _runtimeAppId!);
    } catch (_) {}
  }

  /// Alias for saveAppId
  static Future<void> setDynamicAppId(String id) => saveAppId(id);

  /// Active Agora App ID
  static String get appId {
    if (_runtimeAppId != null && _runtimeAppId!.isNotEmpty) {
      return _runtimeAppId!;
    }
    return _envAppId;
  }

  /// Whether an Agora App ID is provided and real-time cloud streaming is active
  static bool get isConfigured => appId.isNotEmpty;
}
