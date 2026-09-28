import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../theme/app_theme.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  int _selectedDayIndex = 2; // Default to Wednesday
  String _selectedStudioFilter = 'All Studios';
  final List<TeacherClass> _classList = MockTeacherData.todaySchedule;

  final List<Map<String, String>> _days = [
    {'day': 'Mon', 'date': '24'},
    {'day': 'Tue', 'date': '25'},
    {'day': 'Wed', 'date': '26'},
    {'day': 'Thu', 'date': '27'},
    {'day': 'Fri', 'date': '28'},
    {'day': 'Sat', 'date': '29'},
  ];

  final List<String> _studioFilters = [
    'All Studios',
    'Studio 3',
    'Sound Lab 1',
    'Live Hall',
  ];

  void _showAddNoteDialog(TeacherClass item) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderOutline, width: 1),
          ),
          title: Text(
            'Lesson Note for ${item.studentName}',
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course: ${item.courseName}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Worked on thumb-tuck technique. Practice exercise 4 at 70 BPM with metronome.',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderOutline),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lesson note saved to ${item.studentName}\'s record.'),
                  ),
                );
              },
              child: const Text('Save Note'),
            ),
          ],
        );
      },
    );
  }

  void _setAttendance(TeacherClass item, AttendanceState state) {
    setState(() {
      item.attendance = state;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.studentName} marked ${state.name.toUpperCase()}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClasses = _selectedStudioFilter == 'All Studios'
        ? _classList
        : _classList.where((c) => c.studio == _selectedStudioFilter).toList();

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Teacher Timetable'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('KMC Studio Availability: All studios booked.')),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Studio Info',
          ),
        ],
      ),
      body: Column(
        children: [
          // Weekly Date Strip
          _buildDaySelector(),

          // Studio Room Filter Chips
          _buildFilterChips(),

          const Divider(color: AppTheme.borderOutline, height: 1),

          // Schedule List
          Expanded(
            child: filteredClasses.isEmpty
                ? const Center(
                    child: Text(
                      'No classes scheduled for this studio.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredClasses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _buildClassCard(filteredClasses[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Studio Booking: Request extra practice slot from Administration.'),
            ),
          );
        },
        backgroundColor: AppTheme.brandGreen,
        icon: const Icon(Icons.add_rounded, color: AppTheme.primaryBackground),
        label: const Text(
          'Book Studio',
          style: TextStyle(
            color: AppTheme.primaryBackground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: AppTheme.surfaceCard,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_days.length, (index) {
          final isSelected = index == _selectedDayIndex;
          final d = _days[index];

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.brandGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.borderOutline.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    d['day']!,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryBackground : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d['date']!,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryBackground : AppTheme.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primaryBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _studioFilters.map((studio) {
            final isSelected = _selectedStudioFilter == studio;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(studio),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedStudioFilter = studio;
                    });
                  }
                },
                selectedColor: AppTheme.brandBlue,
                backgroundColor: AppTheme.surfaceCard,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppTheme.accentSky : AppTheme.borderOutline,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClassCard(TeacherClass item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isLiveNow ? AppTheme.brandGreen : AppTheme.borderOutline,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time & Studio Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, size: 14, color: AppTheme.brandGreen),
                  const SizedBox(width: 6),
                  Text(
                    item.timeSlot,
                    style: const TextStyle(
                      color: AppTheme.brandGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.studio,
                  style: const TextStyle(
                    color: AppTheme.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Course and Student
          Text(
            item.courseName,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.studentName} • ${item.studentId} • ${item.level}',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Topic Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '🎯 Topic: ${item.topic}',
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Attendance Selector Segment
          Row(
            children: [
              const Text(
                'Attendance:',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildAttendanceChip(item, AttendanceState.present, 'Present', AppTheme.brandGreen),
              const SizedBox(width: 6),
              _buildAttendanceChip(item, AttendanceState.absent, 'Absent', AppTheme.danger),
              const SizedBox(width: 6),
              _buildAttendanceChip(item, AttendanceState.excused, 'Excused', AppTheme.brandGold),
            ],
          ),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddNoteDialog(item),
                  icon: const Icon(Icons.note_alt_outlined, size: 14),
                  label: const Text('Add Lesson Note'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening live lesson session for ${item.studentName}...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 14),
                  label: const Text('Start Lesson'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChip(
    TeacherClass item,
    AttendanceState targetState,
    String label,
    Color activeColor,
  ) {
    final isSelected = item.attendance == targetState;
    return InkWell(
      onTap: () => _setAttendance(item, targetState),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.25) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderOutline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppTheme.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
