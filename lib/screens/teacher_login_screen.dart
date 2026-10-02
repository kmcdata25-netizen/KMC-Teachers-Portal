import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import 'main_teacher_shell.dart';

/// Dedicated Faculty Login Screen for Kasarani Music Center Teacher Portal.
/// Restricts access strictly to verified faculty instructors in the Supabase Central Mind.
class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _identifierController = TextEditingController(text: 'david.otieno@kasaranimusic.ac.ke');
  final _passwordController = TextEditingController(text: '123456');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('kmc_logged_in_teacher_email');
    if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
      setState(() {
        _identifierController.text = savedEmail;
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Faculty Email or Faculty ID.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await TeacherSupabaseService.instance.loginFaculty(
      identifier: identifier,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainTeacherShell()),
        );
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Access Denied: Invalid faculty credentials.';
        });
      }
    }
  }

  void _showFacultyPickerSheet() async {
    final facultyList = await TeacherSupabaseService.instance.fetchAllFaculty();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Registered KMC Faculty Member',
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your instructor account to pre-fill credentials for Central Mind verification:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ...facultyList.map((t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.15),
                    child: Text(
                      t.avatarInitials,
                      style: const TextStyle(color: AppTheme.brandGreen, fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(t.name, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${t.facultyId} • ${t.instruments.isNotEmpty ? t.instruments.first : "Faculty"}',
                    style: const TextStyle(color: AppTheme.accentSky, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _identifierController.text = t.email;
                    });
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Official Logo
                  Image.asset(
                    'Images/logos/KMS.Logo.png',
                    height: 84,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.music_note_rounded,
                      size: 72,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand Title
                  const Text(
                    'KASARANI MUSIC CENTER',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'TEACHER & INSTRUCTOR PORTAL',
                      style: TextStyle(
                        color: AppTheme.brandGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authorized faculty access only • Central Mind Security',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),

                  const SizedBox(height: 32),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderOutline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Faculty Credentials',
                          style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Error Banner
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCoral.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppTheme.accentCoral, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppTheme.accentCoral, fontSize: 12, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Identifier field
                        const Text(
                          'Faculty Email or ID Code',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _identifierController,
                          style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. david.otieno@kasaranimusic.ac.ke or KMC-FAC-014',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.badge_rounded, color: AppTheme.accentSky, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.people_outline_rounded, color: AppTheme.accentSky, size: 20),
                              tooltip: 'Select from Active Faculty Roster',
                              onPressed: _showFacultyPickerSheet,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.brandGreen),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        const Text(
                          'Faculty Password / PIN',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter your staff portal password',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.accentSky, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.brandGreen),
                            ),
                          ),
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text(
                                    'Sign In to Faculty Portal',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'KMC Central Administration • Version 1.0.0 (Central Mind Live)',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
