import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'services/teacher_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Central Mind connection
  try {
    await TeacherSupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[KMC Teacher] Supabase init warning: $e');
  }

  // Initialize Native Android Notification Service & Broadcast Listener
  try {
    await TeacherNotificationService.instance.initialize();
    unawaited(TeacherNotificationService.instance.startRealtimeBroadcastListener());
  } catch (e) {
    debugPrint('[KMC Teacher] Notification service init warning: $e');
  }

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const KasaraniTeacherApp());
}

class KasaraniTeacherApp extends StatelessWidget {
  const KasaraniTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KMC teacher Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
