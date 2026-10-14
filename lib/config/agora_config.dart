import 'package:flutter/foundation.dart';
import 'package:agora_token_generator/agora_token_generator.dart';

/// Central Configuration for Kasarani Music Center Native Agora RTC Video/Audio Engine.
/// Powers the Native In-App "KMC Live Music Studio" for faculty masterclasses and student practice.
class AgoraConfig {
  AgoraConfig._();

  static const String appId = 'cdc6011254554a2bb8c2febe29b85af2';
  static const String certificate = '36b4693ce2794fde994c111454d795bc';

  static bool get isConfigured => true;

  static Future<void> init() async {}

  /// Dynamically mints a valid Agora AccessToken 2.0 signed with the KMC Primary Certificate
  static String generateRtcToken({
    required String channelName,
    int uid = 0,
    int expireSeconds = 86400 * 7, // 7 days expiration
  }) {
    if (channelName.isEmpty) return '';
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
