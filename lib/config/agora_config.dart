import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agora_token_generator/agora_token_generator.dart';

/// Central Configuration for Kasarani Music Center Native Agora RTC Video/Audio Engine.
/// Powers the Native In-App "KMC Live Music Studio" for faculty masterclasses and student practice.
class AgoraConfig {
  AgoraConfig._();

  static const String _defaultKmcAppId = 'cdc6011254554a2bb8c2febe29b85af2';
  static const String _defaultKmcCertificate = '36b4693ce2794fde994c111454d795bc';

  static const String _envAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: _defaultKmcAppId);
  static const String _envCertificate = String.fromEnvironment('AGORA_APP_CERTIFICATE', defaultValue: _defaultKmcCertificate);

  static const String _prefKey = 'kmc_agora_app_id';
  static const String _prefCertKey = 'kmc_agora_certificate';

  static String? _runtimeAppId;
  static String? _runtimeCertificate;

  /// Load persisted App ID and Certificate from local device storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null && savedId.isNotEmpty) {
        _runtimeAppId = savedId.trim();
      }
      final savedCert = prefs.getString(_prefCertKey);
      if (savedCert != null && savedCert.isNotEmpty) {
        _runtimeCertificate = savedCert.trim();
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

  /// Persist new Agora Certificate dynamically at runtime
  static Future<void> saveCertificate(String cert) async {
    _runtimeCertificate = cert.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCertKey, _runtimeCertificate!);
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

  /// Active Agora Primary Certificate
  static String get certificate {
    if (_runtimeCertificate != null && _runtimeCertificate!.isNotEmpty) {
      return _runtimeCertificate!;
    }
    return _envCertificate;
  }

  /// Whether an Agora App ID is provided and real-time cloud streaming is active
  static bool get isConfigured => appId.isNotEmpty;

  /// Dynamically mints a valid Agora AccessToken 2.0 signed with the KMC Primary Certificate
  static String generateRtcToken({
    required String channelName,
    int uid = 0,
    int expireSeconds = 86400 * 7, // 7 days expiration
  }) {
    if (!isConfigured || certificate.isEmpty) return '';
    try {
      return RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: certificate,
        channelName: channelName,
        uid: uid,
        tokenExpireSeconds: expireSeconds,
      );
    } catch (e) {
      debugPrint('[AgoraConfig] Token generation error: $e');
      return '';
    }
  }
}
