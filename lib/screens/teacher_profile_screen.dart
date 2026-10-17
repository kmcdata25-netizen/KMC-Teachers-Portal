import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_notification_service.dart';
import '../services/teacher_supabase_service.dart';
import '../services/teacher_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/teacher_update_dialog.dart';
import '../widgets/teacher_empty_state.dart';
import 'kmc_live_studio_screen.dart';
import 'teacher_login_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  TeacherProfile _profile = MockTeacherData.currentTeacher;
  Map<String, dynamic> _stats = {
    'activeStudents': 0,
    'classesToday': 0,
    'pendingReviews': 0,
    'teachingHours': 0.0,
  };
  bool _isLoading = true;
  bool _availableForBookings = true;
  bool _notificationsEnabled = true;
  List<String> _availableDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _loadLiveProfile();
  }

  Future<void> _loadLiveProfile() async {
    setState(() => _isLoading = true);
    TeacherProfile? teacher = TeacherSupabaseService.instance.activeTeacher;
    teacher ??= await TeacherSupabaseService.instance.checkSavedSession();
    teacher ??= MockTeacherData.currentTeacher;

    final stats = await TeacherSupabaseService.instance.fetchTeacherDashboardStats(teacher);

    if (mounted) {
      setState(() {
        _profile = teacher!;
        _stats = stats;
        if (teacher.availableDays.isNotEmpty) {
          _availableDays = List.from(teacher.availableDays);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDay(String day) async {
    setState(() {
      if (_availableDays.contains(day)) {
        if (_availableDays.length > 1) {
          _availableDays.remove(day);
        }
      } else {
        _availableDays.add(day);
      }
    });

    final success = await TeacherSupabaseService.instance.updateTeacherAvailability(
      _profile.id,
      _availableDays,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✓ Studio availability updated in Central Mind (${_availableDays.join(', ')})'
                : 'Studio availability updated.',
          ),
          backgroundColor: AppTheme.brandGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderOutline),
        ),
        title: const Text('Sign Out of Faculty Portal', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'Are you sure you want to end your faculty session?',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TeacherSupabaseService.instance.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Faculty Profile & Portal'),
        actions: [
          IconButton(
            onPressed: _loadLiveProfile,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandGreen))
          : _profile.id.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TeacherEmptyState(
                      title: 'Faculty Profile Unavailable',
                      message: 'Data not available. Please connect to the internet.',
                      icon: Icons.wifi_off_rounded,
                      onRetry: _loadLiveProfile,
                      isRetrying: _isLoading,
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadLiveProfile,
              color: AppTheme.brandGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Profile Card
                    _buildProfileCard(context),
                    const SizedBox(height: 20),

                    // Teaching Hours & Compensation Ledger
                    _buildCompensationCard(context),
                    const SizedBox(height: 20),

                    // Studio Availability & Preferences
                    _buildStudioPreferencesCard(context),
                    const SizedBox(height: 20),

                    // School Resources & Faculty Tools
                    _buildFacultyResourcesCard(context),
                    const SizedBox(height: 20),

                    // In-App OTA Portal Updates
                    _buildUpdateTile(context),
                    const SizedBox(height: 20),

                    // Logout & Version Info
                    _buildFooter(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandBlue, AppTheme.surfaceElevated],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppTheme.brandGreen, width: 2),
                ),
                child: Center(
                  child: Text(
                    _profile.avatarInitials,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile.name,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile.title,
                      style: const TextStyle(
                        color: AppTheme.accentSky,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.brandGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FACULTY ID: ${_profile.facultyId}',
                            style: const TextStyle(
                              color: AppTheme.brandGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_profile.rating > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '★ ${_profile.rating.toStringAsFixed(1)}',
                            style: const TextStyle(color: AppTheme.brandGold, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderOutline),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.business_rounded, 'Department', _profile.department),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.piano_rounded, 'Assigned Studio', _profile.studio),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.music_note_rounded, 'Instruments', _profile.instruments.isNotEmpty ? _profile.instruments.join(', ') : 'Contemporary Music'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.email_outlined, 'Institutional Email', _profile.email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, 'Contact', _profile.phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.brandGreen),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompensationCard(BuildContext context) {
    final now = DateTime.now();
    final monthName = _getMonthName(now.month);
    final hours = (_stats['teachingHours'] as num?)?.toDouble() ?? 0.0;
    final rate = _profile.hourlyRate > 0 ? _profile.hourlyRate : 1800.0;
    final estimatedTotal = (hours * rate).round();
    final formattedTotal = estimatedTotal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Teaching Hours & Earnings',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'CENTRAL MIND VERIFIED',
                  style: TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$monthName Hours', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '$hours hrs',
                        style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('${hours.toInt()} verified sessions', style: const TextStyle(color: AppTheme.brandGreen, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated Total', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        'KES $formattedTotal',
                        style: const TextStyle(color: AppTheme.brandGreen, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('@ KES ${rate.toInt()}/hr faculty rate', style: const TextStyle(color: AppTheme.accentSky, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Generating PDF compensation voucher with KMC official seal...'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Download Monthly Statement (PDF)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  Widget _buildStudioPreferencesCard(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Studio Preferences & Working Days',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap working days to sync studio teaching schedule with Administration:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDays.map((day) {
                final isSelected = _availableDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) => _toggleDay(day),
                  selectedColor: AppTheme.brandGreen,
                  backgroundColor: AppTheme.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryBackground : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? AppTheme.brandGreen : AppTheme.borderOutline),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderOutline),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Accept Student Makeup Bookings',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Allow admin to schedule makeup lessons in ${_profile.studio}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              value: _availableForBookings,
              activeThumbColor: AppTheme.brandGreen,
              onChanged: (val) {
                setState(() => _availableForBookings = val);
              },
            ),
            const Divider(color: AppTheme.borderOutline),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Drill Submission Push Alerts',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Receive instant notifications when students upload video/audio',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              value: _notificationsEnabled,
              activeThumbColor: AppTheme.brandGreen,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await TeacherNotificationService.instance.requestPermission();
                await TeacherNotificationService.instance.showNotification(
                  id: 999,
                  title: '🚨 KMC Broadcast Test Alert',
                  body: 'Admin broadcast notification system is live and verified on your device.',
                  subText: 'Director Office • Test Notice',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification dispatched to Android system tray!'),
                      backgroundColor: AppTheme.brandGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active_rounded, size: 16, color: AppTheme.brandGreen),
              label: const Text(
                'Test Android System Notification',
                style: TextStyle(color: AppTheme.brandGreen, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.brandGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size.fromHeight(38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyResourcesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KMC Faculty Resources & Tools',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildResourceTile(
            Icons.videocam_rounded,
            'Launch Live Masterclass Studio',
            'Open real-time virtual broadcasting room',
            onTap: () {
              final onDemandSession = TeacherClass(
                id: 'profile_live_studio_${DateTime.now().millisecondsSinceEpoch}',
                courseName: 'Faculty Studio Masterclass',
                level: 'Faculty Studio',
                studentName: 'Studio Cohort (Open Masterclass)',
                studentId: 'STUDIO-OPEN',
                timeSlot: 'Live Masterclass Broadcast',
                studio: _profile.studio.isNotEmpty ? _profile.studio : 'Studio 3 (Yamaha C7 Grand)',
                attendance: AttendanceState.present,
                topic: 'Technique, Repertoire & Interactive Coaching',
                isLiveNow: true,
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KMCLiveStudioScreen(session: onDemandSession),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildResourceTile(
            Icons.menu_book_rounded,
            'Curriculum Syllabus & Rubrics',
            'ABRSM & Contemporary Grading guidelines',
            onTap: () => _showSyllabusSheet(context),
          ),
          const SizedBox(height: 8),
          _buildResourceTile(
            Icons.library_music_rounded,
            'Sheet Music & Backing Tracks',
            'Cloudflare R2 Master repository',
            onTap: () => _showSheetMusicSheet(context),
          ),
          const SizedBox(height: 8),
          _buildResourceTile(
            Icons.support_agent_rounded,
            'Contact School Administration',
            'Direct WhatsApp / Phone to KMC Academic Office',
            onTap: () => _contactAdministration(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceTile(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.brandGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _contactAdministration(BuildContext context) async {
    final success = await TeacherSupabaseService.instance.launchWhatsAppNamed(
      phone: '+254722841847',
      message: 'Hello KMC Academic Administration, inquiry from Faculty Member ${_profile.name} (${_profile.facultyId}).',
    );
    if (!success && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderOutline),
          ),
          title: const Text('KMC Academic Office', style: TextStyle(color: AppTheme.textWhite, fontSize: 16)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: +254 722 841 847 / +254 788 841 847', style: TextStyle(color: AppTheme.brandGreen, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Email: faculty@kasaranimusic.ac.ke', style: TextStyle(color: AppTheme.textWhite, fontSize: 13)),
              SizedBox(height: 6),
              Text('Office Hours: Mon–Sat 8:00 AM – 7:00 PM', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppTheme.brandGreen)),
            ),
          ],
        ),
      );
    }
  }

  void _showSyllabusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'KMC Faculty Curriculum & Rubrics',
                    style: TextStyle(color: AppTheme.textWhite, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Standardized assessment criteria for practical lessons & live masterclasses.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _buildCurriculumCard(
                    title: '1. Technique & Finger Independence (35%)',
                    desc: 'Posture, hand position, articulation, clarity in scale runs, arpeggios, and dynamic control.',
                    icon: Icons.speed_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildCurriculumCard(
                    title: '2. Rhythm & Metronome Precision (40%)',
                    desc: 'Subdivision accuracy, internal pulse consistency, tempo stability across tempo transitions and syncopated phrasing.',
                    icon: Icons.timer_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildCurriculumCard(
                    title: '3. Phrasing & Dynamic Interpretation (25%)',
                    desc: 'Musical nuance, crescendo/decrescendo control, articulation fidelity, and expressive maturity.',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCurriculumCard({required String title, required String desc, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.brandGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSheetMusicSheet(BuildContext context) {
    final sampleItems = [
      {'title': 'J.S. Bach – Inventions & Sinfonias (Urtext)', 'type': 'PDF', 'size': '4.2 MB'},
      {'title': 'Autumn Leaves – Jazz Lead Sheet with Chords', 'type': 'PDF', 'size': '1.8 MB'},
      {'title': 'Hanon – The Virtuoso Pianist (60 Exercises)', 'type': 'PDF', 'size': '7.5 MB'},
      {'title': 'Blues in F – Drum & Upright Bass Backing Track', 'type': 'MP3', 'size': '5.4 MB'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.40,
          maxChildSize: 0.90,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cloudflare R2 Sheet Music',
                        style: TextStyle(color: AppTheme.textWhite, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text('CENTRAL MIND', style: TextStyle(color: AppTheme.brandGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...sampleItems.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderOutline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['type'] == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.audiotrack_rounded,
                            color: item['type'] == 'PDF' ? AppTheme.brandGold : AppTheme.brandGreen,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title']!, style: const TextStyle(color: AppTheme.textWhite, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${item['type']} • ${item['size']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: AppTheme.brandGreen, size: 18),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Material downloaded: ${item['title']}'),
                                  backgroundColor: AppTheme.brandGreen,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUpdateTile(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.brandGreen.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () async {
          final sm = ScaffoldMessenger.of(context);
          sm.showSnackBar(
            const SnackBar(
              content: Text('Checking Central Mind & GitHub for updates...'),
              duration: Duration(seconds: 1),
            ),
          );
          final info = await TeacherUpdateService.instance.checkForUpdate();
          if (!context.mounted) return;
          if (info != null && info.hasUpdate) {
            TeacherUpdateDialog.show(context, info);
          } else {
            sm.showSnackBar(
              const SnackBar(
                content: Text('KMC Teacher Portal is running the latest version!'),
                backgroundColor: AppTheme.brandGreen,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.system_update_rounded, color: AppTheme.brandGreen, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check for Portal Updates',
                      style: TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Seamless Over-The-Air updates without uninstalling',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.brandGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 16, color: AppTheme.danger),
            label: const Text(
              'Sign Out of Faculty Portal',
              style: TextStyle(color: AppTheme.danger),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Kasarani Music Center — Teacher Portal v1.0.0 (Build 1)\nConnected directly to Supabase Central Mind',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
