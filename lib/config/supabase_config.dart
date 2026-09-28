import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase Configuration for Kasarani Music Center Teacher Portal.
class TeacherSupabaseConfig {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static const String url = 'https://vsfvbaflosylrkpxfltg.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZnZiYWZsb3N5bHJrcHhmbHRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwODE3NzcsImV4cCI6MjEwNTY1Nzc3N30.PkX5VQCyYWk_A7DcckomvYkyFsyiUJppXJ8jwADIrTk';

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isInitialized = true;
      debugPrint('[KMC Teacher] Connected to Central Mind.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[KMC Teacher] Supabase notice: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
