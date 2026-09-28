import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../theme/app_theme.dart';

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
  final profile = MockTeacherData.currentTeacher;
  final metrics = MockTeacherData.metrics;
  final classes = MockTeacherData.todaySchedule;

  void _cycleAttendance(TeacherClass tc) {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attendance for ${tc.studentName}: ${tc.attendance.name.toUpperCase()}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

        // Notification Bell Icon with Badge
        Stack(
          children: [
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications: 3 unread teacher alerts & drill submissions.'),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_outlined, color: AppTheme.textWhite),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextClassCard(BuildContext context) {
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
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening Studio Log for ${nextClass.studentName}...'),
                    ),
                  );
                },
                child: const Text('Studio Log'),
              ),
            ],
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('KMC Faculty Resource Library: Lesson sheets & scales.'),
                  ),
                );
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
        ],
      ),
    );
  }

  Widget _buildSubmissionsTeaser(BuildContext context) {
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
                child: const Text(
                  '7 Pending',
                  style: TextStyle(
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
}
