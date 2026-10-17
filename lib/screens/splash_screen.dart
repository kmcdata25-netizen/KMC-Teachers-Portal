import 'dart:async';
import 'package:flutter/material.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import 'main_teacher_shell.dart';
import 'teacher_login_screen.dart';

/// Preload / Splash Screen for Kasarani Music Center Teacher Portal.
/// Features guaranteed multi-step preload animation, official school logo,
/// dynamic progress counter (0% -> 100%), and smooth transition to the Faculty Dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.25;
  bool _entered = false;
  String _loadingMessage = 'Connecting to Central Mind...';

  @override
  void initState() {
    super.initState();
    debugPrint('[KMC] SplashScreen initialized on device');

    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _entered = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePortal();
    });
  }

  Future<void> _initializePortal() async {
    try {
      setState(() {
        _progress = 0.45;
        _loadingMessage = 'Verifying Faculty Credentials...';
      });

      final session = await TeacherSupabaseService.instance.checkSavedSession();
      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _loadingMessage = 'Welcome to Kasarani Music Center';
      });

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final targetScreen = session != null
          ? const MainTeacherShell()
          : const TeacherLoginScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      debugPrint('[KMC] Splash error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background instrument texture
          Opacity(
            opacity: 0.32,
            child: Image.asset(
              'Images/background images/guiter.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'Images/background images/guiter.jfif',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                );
              },
            ),
          ),

          // Multi-stop gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryBackground.withValues(alpha: 0.65),
                  AppTheme.primaryBackground.withValues(alpha: 0.85),
                  AppTheme.primaryBackground.withValues(alpha: 0.98),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Central Animated Brand Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Animated Kasarani Logo & Faculty Label
                  AnimatedOpacity(
                    opacity: _entered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: _entered ? 1.0 : 0.88,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Official KMS Logo
                          Image.asset(
                            'Images/logos/kms logo.png',
                            height: 78,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'Images/logos/kms logo_original.png',
                                height: 78,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.music_note_rounded,
                                    size: 64,
                                    color: AppTheme.brandGreen,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // School Title
                          const Text(
                            'KASARANI MUSIC CENTER',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Faculty Portal Pill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.brandGreen.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.brandGreen.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              'TEACHER & FACULTY PORTAL',
                              style: TextStyle(
                                color: AppTheme.brandGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tagline
                          const Text(
                            '"Passion to Profession"',
                            style: TextStyle(
                              color: AppTheme.accentSky,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Animated Preload Progress Bar & Live Status Text
                  AnimatedOpacity(
                    opacity: _entered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 210,
                            height: 6,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.brandGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.brandGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
