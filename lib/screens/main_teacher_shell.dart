import 'package:flutter/material.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_schedule_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_submissions_screen.dart';
import 'teacher_profile_screen.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
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
                      child: const Text(
                        'FACULTY PORTAL',
                        style: TextStyle(
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
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.brandGreen, width: 1.5),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.surfaceElevated,
                child: Text(
                  'DO',
                  style: TextStyle(
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('7'),
              backgroundColor: AppTheme.brandGold,
              textColor: AppTheme.primaryBackground,
              child: Icon(Icons.rate_review_outlined),
            ),
            selectedIcon: Badge(
              label: Text('7'),
              backgroundColor: AppTheme.brandGold,
              textColor: AppTheme.primaryBackground,
              child: Icon(Icons.rate_review_rounded),
            ),
            label: 'Reviews',
          ),
        ],
      ),
    );
  }
}
