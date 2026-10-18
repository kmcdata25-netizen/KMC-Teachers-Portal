import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_notification_service.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_communication_sheet.dart';
import '../widgets/teacher_empty_state.dart';
import 'kmc_live_studio_screen.dart';
import 'teacher_notifications_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const TeacherDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  TeacherProfile profile = MockTeacherData.currentTeacher;
  Map<String, dynamic> _stats = {
    'activeStudents': 0,
    'classesToday': 0,
    'pendingReviews': 0,
    'teachingHours': 0.0,
  };
  List<TeacherClass> classes = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadLiveDashboard();
  }

  Future<void> _loadLiveDashboard() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      TeacherProfile? teacher = TeacherSupabaseService.instance.activeTeacher;
      teacher ??= await TeacherSupabaseService.instance.checkSavedSession();
      teacher ??= MockTeacherData.currentTeacher;

      final statsFuture = TeacherSupabaseService.instance.fetchTeacherDashboardStats(teacher);
      final scheduleFuture = TeacherSupabaseService.instance.fetchTeacherSchedule(teacher, DateTime.now());
      final results = await Future.wait([statsFuture, scheduleFuture]);

      if (mounted) {
        setState(() {
          profile = teacher!;
          _stats = results[0] as Map<String, dynamic>;
          classes = results[1] as List<TeacherClass>;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _cycleAttendance(TeacherClass tc) async {
    setState(() {
      switch (tc.attendance) {
        case AttendanceState.unmarked:
          tc.attendance = AttendanceState.present;
          break;
        case AttendanceState.present:
          tc.attendance = AttendanceState.absent;
          break;
        case AttendanceState.absent:
          tc.attendance = AttendanceState.excused;
          break;
        case AttendanceState.excused:
          tc.attendance = AttendanceState.present;
          break;
      }
    });

    await TeacherSupabaseService.instance.updateSessionAttendance(tc.id, tc.attendance);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Attendance for ${tc.studentName}: ${tc.attendance.name.toUpperCase()} (Saved to Central Mind)',
          ),
          backgroundColor: AppTheme.brandGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<TeacherMetric> get metrics {
    return [
      TeacherMetric(
        label: 'Active Students',
        value: '${_stats['activeStudents'] ?? 0}',
        subtitle: 'Enrolled in Department',
        iconKey: 'students',
      ),
      TeacherMetric(
        label: 'Classes Today',
        value: '${_stats['classesToday'] ?? 0}',
        subtitle: '${classes.length} Sessions on Timetable',
        iconKey: 'schedule',
      ),
      TeacherMetric(
        label: 'Pending Reviews',
        value: '${_stats['pendingReviews'] ?? 0}',
        subtitle: 'Student Practice Drills',
        iconKey: 'reviews',
      ),
      TeacherMetric(
        label: 'Teaching Hours',
        value: '${_stats['teachingHours'] ?? 0} hrs',
        subtitle: 'Verified Cycle Hours',
        iconKey: 'hours',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLiveDashboard,
          color: AppTheme.brandGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(color: AppTheme.brandGreen, backgroundColor: AppTheme.surfaceElevated),
                  ),

                // Top Profile & Greeting Row
                _buildHeader(context),
                const SizedBox(height: 20),

                // Active / Next Class Alert Banner
                _buildNextClassCard(context),
                const SizedBox(height: 24),

                // Quick Metrics Grid (2x2)
                _buildMetricsGrid(context),
                const SizedBox(height: 24),

                // Quick Action Bar
                _buildQuickActionBar(context),
                const SizedBox(height: 24),

                // Today's Teaching Schedule Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onNavigateTab(1), // Go to Schedule tab
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.brandGreen),
                      label: const Text(
                        'View Timetable',
                        style: TextStyle(
                          color: AppTheme.brandGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Classes List for Today
                if (classes.isEmpty)
                  _hasError
                      ? TeacherEmptyState.offline(
                          title: 'Timetable Offline',
                          message: 'Data not available. Please connect to the internet.',
                          onRetry: _loadLiveDashboard,
                          isRetrying: _isLoading,
                        )
                      : TeacherEmptyState.empty(
                          title: 'No Classes Today',
                          message: 'You have no scheduled masterclasses on your timetable today.',
                          icon: Icons.event_busy_rounded,
                          onRefresh: _loadLiveDashboard,
                          isRefreshing: _isLoading,
                        )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: classes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = classes[index];
                      return _buildScheduleItemCard(context, item);
                    },
                  ),
                const SizedBox(height: 24),

                // Pending Submissions Queue Teaser
                _buildSubmissionsTeaser(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Teacher Avatar with Initials
        Container(
          width: 52,
          height: 52,
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
              profile.avatarInitials,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Teacher Title & ID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${profile.name}',
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      profile.facultyId,
                      style: const TextStyle(
                        color: AppTheme.accentSky,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      profile.status,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.brandGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Notification Bell Icon with Live Dynamic Unread Counter Badge
        ValueListenableBuilder<int>(
          valueListenable: TeacherNotificationService.instance.unreadCountNotifier,
          builder: (context, unreadCount, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _openTeacherAnnouncements(context),
                  icon: const Icon(Icons.notifications_outlined, color: AppTheme.textWhite),
                  tooltip: unreadCount > 0
                      ? 'School Announcements ($unreadCount unread)'
                      : 'School Announcements',
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppTheme.surfaceCard, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandGreen.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _openTeacherAnnouncements(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TeacherNotificationsScreen(),
      ),
    );
  }

  Widget _buildNextClassCard(BuildContext context) {
    if (classes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderOutline, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_available_rounded, color: AppTheme.brandGreen, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Classes Scheduled Today',
                        style: TextStyle(color: AppTheme.textWhite, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ready to teach? Open the live studio to broadcast or book a student class.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final defaultStudio = profile.assignedStudio.trim().isNotEmpty
                          ? profile.assignedStudio.trim()
                          : (profile.studio.trim().isNotEmpty ? profile.studio.trim() : 'Studio 1');
                      final courseName = profile.department.trim().isNotEmpty
                          ? '${profile.department.trim()} Masterclass'
                          : 'Faculty Studio Masterclass';
                      final onDemandSession = TeacherClass(
                        id: 'live_studio_${DateTime.now().millisecondsSinceEpoch}',
                        courseName: courseName,
                        level: 'All Levels',
                        studentName: 'Studio Cohort (Open Masterclass)',
                        studentId: 'STUDIO-OPEN',
                        timeSlot: 'Live Masterclass Broadcast',
                        studio: defaultStudio,
                        attendance: AttendanceState.present,
                        topic: 'Faculty Live Masterclass Session',
                        isLiveNow: true,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KMCLiveStudioScreen(session: onDemandSession),
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Start Live Masterclass'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandGreen,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 38),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigateTab(1),
                  icon: const Icon(Icons.calendar_month_rounded, size: 15, color: AppTheme.brandGreen),
                  label: const Text('Schedule Class', style: TextStyle(color: AppTheme.textWhite, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderOutline),
                    minimumSize: const Size(0, 38),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Find active or next upcoming class
    final nextClass = classes.firstWhere(
      (c) => c.isLiveNow || c.attendance == AttendanceState.unmarked,
      orElse: () => classes.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: nextClass.isLiveNow ? AppTheme.brandGreen : AppTheme.borderOutline,
          width: nextClass.isLiveNow ? 1.5 : 1,
        ),
        boxShadow: nextClass.isLiveNow
            ? [
                BoxShadow(
                  color: AppTheme.brandGreen.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: nextClass.isLiveNow
                      ? AppTheme.brandGreen.withValues(alpha: 0.2)
                      : AppTheme.brandBlue.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      nextClass.isLiveNow ? Icons.fiber_manual_record : Icons.access_time_rounded,
                      size: 12,
                      color: nextClass.isLiveNow ? AppTheme.brandGreen : AppTheme.accentSky,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      nextClass.isLiveNow ? 'IN SESSION NOW' : 'NEXT UPCOMING CLASS',
                      style: TextStyle(
                        color: nextClass.isLiveNow ? AppTheme.brandGreen : AppTheme.accentSky,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                nextClass.studio,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nextClass.courseName,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                '${nextClass.studentName} (${nextClass.studentId})',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  nextClass.timeSlot,
                  style: const TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.brandGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextClass.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    _cycleAttendance(nextClass);
                  },
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: Text(
                    nextClass.attendance == AttendanceState.unmarked
                        ? 'Mark Attendance'
                        : 'Status: ${nextClass.attendance.name.toUpperCase()}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: nextClass.attendance == AttendanceState.present
                        ? AppTheme.brandGreenDark
                        : AppTheme.brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  StudentCommunicationSheet.show(
                    context,
                    studentName: nextClass.studentName,
                    studentId: nextClass.studentId,
                    studentPhone: nextClass.studentPhone,
                    studentEmail: nextClass.studentEmail,
                    courseName: nextClass.courseName,
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 14, color: AppTheme.brandGreen),
                label: const Text('Notify Student'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => KMCLiveStudioScreen(session: nextClass),
                ),
              );
            },
            icon: const Icon(Icons.videocam_rounded, size: 16),
            label: Text(
              nextClass.isLiveNow
                  ? 'Enter Live Masterclass Studio'
                  : 'Open Studio Room: ${nextClass.studio}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: nextClass.isLiveNow ? AppTheme.brandGreen : AppTheme.brandBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        IconData icon;
        Color accentColor;

        switch (m.iconKey) {
          case 'students':
            icon = Icons.school_rounded;
            accentColor = AppTheme.brandGreen;
            break;
          case 'schedule':
            icon = Icons.event_available_rounded;
            accentColor = AppTheme.accentSky;
            break;
          case 'reviews':
            icon = Icons.assignment_late_rounded;
            accentColor = AppTheme.brandGold;
            break;
          default:
            icon = Icons.timelapse_rounded;
            accentColor = AppTheme.brandGreen;
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderOutline, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    m.label,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(icon, size: 18, color: accentColor),
                ],
              ),
              Text(
                m.value,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                m.subtitle,
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBar(BuildContext context) {
    final actions = [
      {'title': 'Roster', 'icon': Icons.people_rounded, 'tab': 2},
      {'title': 'Timetable', 'icon': Icons.calendar_today_rounded, 'tab': 1},
      {'title': 'Submissions', 'icon': Icons.rate_review_rounded, 'tab': 3},
      {'title': 'Materials', 'icon': Icons.library_music_rounded, 'tab': -1},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((act) {
          final tabIndex = act['tab'] as int;
          return InkWell(
            onTap: () {
              if (tabIndex >= 0) {
                widget.onNavigateTab(tabIndex);
              } else {
                _showFacultyMaterialsSheet(context);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderOutline, width: 1),
                    ),
                    child: Icon(act['icon'] as IconData, size: 20, color: AppTheme.brandGreen),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    act['title'] as String,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScheduleItemCard(BuildContext context, TeacherClass item) {
    Color statusColor;
    String statusText;

    switch (item.attendance) {
      case AttendanceState.present:
        statusColor = AppTheme.brandGreen;
        statusText = 'PRESENT';
        break;
      case AttendanceState.absent:
        statusColor = AppTheme.danger;
        statusText = 'ABSENT';
        break;
      case AttendanceState.excused:
        statusColor = AppTheme.brandGold;
        statusText = 'EXCUSED';
        break;
      case AttendanceState.unmarked:
        statusColor = AppTheme.textMuted;
        statusText = 'UNMARKED';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isLiveNow ? AppTheme.brandGreen : AppTheme.borderOutline,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Time Column
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.timeSlot.split('–')[0].trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.brandGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  item.studio,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.studentName,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${item.courseName} • ${item.level}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Attendance Quick-Toggle Pill
          InkWell(
            onTap: () => _cycleAttendance(item),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.brandGreen),
            tooltip: 'Notify ${item.studentName}',
            onPressed: () {
              StudentCommunicationSheet.show(
                context,
                studentName: item.studentName,
                studentId: item.studentId,
                studentPhone: item.studentPhone,
                studentEmail: item.studentEmail,
                courseName: item.courseName,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsTeaser(BuildContext context) {
    final pendingCount = _stats['pendingReviews'] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_rounded, size: 20, color: AppTheme.brandGold),
              const SizedBox(width: 8),
              const Text(
                'Student Practice Submissions',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount Pending',
                  style: const TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Students have uploaded recent rhythm drills and video submissions awaiting instructor evaluation and grading.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => widget.onNavigateTab(3), // Navigate to Submissions tab
            icon: const Icon(Icons.rate_review_rounded, size: 16),
            label: const Text('Review Practice Drills'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.surfaceElevated,
              foregroundColor: AppTheme.textWhite,
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }

  void _showFacultyMaterialsSheet(BuildContext context) {
    final materialsFuture = TeacherSupabaseService.instance.fetchCurriculumSheetMusic(
      teacherId: profile.id,
    );

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty Resource Library',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Syllabi, Lead Sheets & Backing Stems',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.brandGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CENTRAL MIND R2',
                          style: TextStyle(
                            color: AppTheme.brandGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: materialsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.brandGold),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: TeacherEmptyState.offline(),
                          );
                        }
                        final materials = snapshot.data ?? [];
                        if (materials.isEmpty) {
                          return Center(
                            child: TeacherEmptyState.empty(
                              title: 'Resource Library Empty',
                              message: 'There are currently no instructional materials or stems in the library.',
                              icon: Icons.library_music_outlined,
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: materials.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = materials[index];
                            final typeStr = (item['type'] ?? 'PDF').toString().toUpperCase();
                            final isPdf = typeStr == 'PDF';
                            final isMp3 = typeStr == 'MP3' || typeStr == 'AUDIO';
                            final titleStr = (item['title'] ?? 'Curriculum Resource').toString();
                            final categoryStr = (item['category'] ?? item['course'] ?? 'Curriculum').toString();
                            final sizeStr = (item['size'] ?? 'Cloudflare R2').toString();
                            final descStr = (item['desc'] ?? item['notes'] ?? '').toString();
                            final urlStr = (item['url'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderOutline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceElevated,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isPdf
                                                ? AppTheme.brandGold.withValues(alpha: 0.5)
                                                : isMp3
                                                    ? AppTheme.brandGreen.withValues(alpha: 0.5)
                                                    : AppTheme.accentSky.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Icon(
                                          isPdf
                                              ? Icons.picture_as_pdf_rounded
                                              : isMp3
                                                  ? Icons.audiotrack_rounded
                                                  : Icons.description_rounded,
                                          color: isPdf
                                              ? AppTheme.brandGold
                                              : isMp3
                                                  ? AppTheme.brandGreen
                                                  : AppTheme.accentSky,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              titleStr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.textWhite,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '$categoryStr • $typeStr • $sizeStr',
                                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (descStr.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      descStr,
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          if (urlStr.isNotEmpty) {
                                            final uri = Uri.tryParse(urlStr);
                                            if (uri != null) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('✓ Material ready: $titleStr'),
                                                backgroundColor: AppTheme.brandGreen,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.download_rounded, size: 14),
                                        label: const Text('Open / Save', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
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
}
