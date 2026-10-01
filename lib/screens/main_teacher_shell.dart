import 'package:flutter/material.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_schedule_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_submissions_screen.dart';
import 'teacher_profile_screen.dart';
import '../services/teacher_notification_service.dart';
import '../services/teacher_supabase_service.dart';
import '../services/teacher_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/teacher_update_dialog.dart';

class MainTeacherShell extends StatefulWidget {
  final int initialTabIndex;

  const MainTeacherShell({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MainTeacherShell> createState() => _MainTeacherShellState();
}

class _MainTeacherShellState extends State<MainTeacherShell> {
  late int _currentIndex;
  int _pendingReviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _checkPendingReviews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      await TeacherUpdateService.instance.promptInstallPermissionOnFirstLaunch(context);
      final update = await TeacherUpdateService.instance.checkForUpdate();
      if (update != null && update.hasUpdate && mounted) {
        TeacherUpdateDialog.show(context, update);
      }
    } catch (e) {
      debugPrint('[TeacherShell] Update check notice: $e');
    }
  }

  Future<void> _checkPendingReviews() async {
    final teacher = TeacherSupabaseService.instance.activeTeacher ??
        await TeacherSupabaseService.instance.checkSavedSession();
    if (teacher != null) {
      TeacherNotificationService.instance.startRealtimeBroadcastListener(
        teacherId: teacher.id,
        facultyCode: teacher.facultyId,
      );
      final stats = await TeacherSupabaseService.instance.fetchTeacherDashboardStats(teacher);
      if (mounted) {
        setState(() {
          _pendingReviewsCount = stats['pendingReviews'] as int? ?? 0;
        });
      }
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTeacher = TeacherSupabaseService.instance.activeTeacher;
    final initials = activeTeacher?.avatarInitials ?? 'FC';

    final List<Widget> screens = [
      TeacherDashboardScreen(onNavigateTab: _onTabSelected),
      const TeacherScheduleScreen(),
      const TeacherStudentsScreen(),
      const TeacherSubmissionsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'Images/logos/KMS 2.Logo.png',
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.music_note_rounded,
                color: AppTheme.brandGreen,
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kasarani Music Center',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textWhite,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activeTeacher != null ? 'FACULTY: ${activeTeacher.name.split(' ').first.toUpperCase()}' : 'FACULTY PORTAL',
                        style: const TextStyle(
                          color: AppTheme.brandGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Faculty Profile & Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
              );
              if (mounted) setState(() {});
            },
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.brandGreen, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.surfaceElevated,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Schedule',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Students',
          ),
          NavigationDestination(
            icon: _pendingReviewsCount > 0
                ? Badge(
                    label: Text('$_pendingReviewsCount'),
                    backgroundColor: AppTheme.brandGold,
                    textColor: AppTheme.primaryBackground,
                    child: const Icon(Icons.rate_review_outlined),
                  )
                : const Icon(Icons.rate_review_outlined),
            selectedIcon: _pendingReviewsCount > 0
                ? Badge(
                    label: Text('$_pendingReviewsCount'),
                    backgroundColor: AppTheme.brandGold,
                    textColor: AppTheme.primaryBackground,
                    child: const Icon(Icons.rate_review_rounded),
                  )
                : const Icon(Icons.rate_review_rounded),
            label: 'Reviews',
          ),
        ],
      ),
    );
  }
}
