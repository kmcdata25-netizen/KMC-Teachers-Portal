import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_communication_sheet.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  int _selectedDayIndex = 0;
  String _selectedStudioFilter = 'All Studios';
  List<TeacherClass> _classList = [];
  bool _isLoading = true;
  late List<DateTime> _weekDays;
  TeacherProfile? _teacher;

  @override
  void initState() {
    super.initState();
    _initWeek();
    _loadTeacherAndSchedule();
  }

  void _initWeek() {
    final now = DateTime.now();
    // Start from Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekDays = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    _selectedDayIndex = (now.weekday - 1).clamp(0, 6);
  }

  Future<void> _loadTeacherAndSchedule() async {
    setState(() => _isLoading = true);
    _teacher = TeacherSupabaseService.instance.activeTeacher;
    _teacher ??= await TeacherSupabaseService.instance.checkSavedSession();
    _teacher ??= MockTeacherData.currentTeacher;

    await _fetchScheduleForDate(_weekDays[_selectedDayIndex]);
  }

  Future<void> _fetchScheduleForDate(DateTime date) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final schedule = await TeacherSupabaseService.instance.fetchTeacherSchedule(_teacher!, date);
      if (mounted) {
        setState(() {
          _classList = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classList = [];
          _isLoading = false;
        });
      }
    }
  }

  List<String> get _studioFilters {
    final studios = <String>{'All Studios'};
    for (final c in _classList) {
      if (c.studio.isNotEmpty) {
        studios.add(c.studio);
      }
    }
    return studios.toList();
  }

  void _showAddNoteDialog(TeacherClass item) {
    final noteController = TextEditingController(text: item.notes);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final noteText = noteController.text.trim();
                          final success = await TeacherSupabaseService.instance.saveSessionNote(item.id, noteText);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {
                              item.notes = noteText;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '✓ Lesson note saved to Central Mind database.'
                                      : 'Note cached locally.',
                                ),
                                backgroundColor: AppTheme.brandGreen,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Note'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setAttendance(TeacherClass item, AttendanceState state) async {
    setState(() {
      item.attendance = state;
    });

    final success = await TeacherSupabaseService.instance.updateSessionAttendance(item.id, state);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
              ? '✓ ${item.studentName} marked ${state.name.toUpperCase()} (Synced with Central Mind)'
              : '${item.studentName} marked ${state.name.toUpperCase()}',
          ),
          backgroundColor: AppTheme.brandGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
            onPressed: _showScheduleSessionDialog,
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.brandGreen),
            tooltip: 'Schedule Studio Class',
          ),
          IconButton(
            onPressed: () => _fetchScheduleForDate(_weekDays[_selectedDayIndex]),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Schedule',
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('KMC Live Timetable connected directly to Central Mind.')),
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

          if (_isLoading)
            const LinearProgressIndicator(
              color: AppTheme.brandGreen,
              backgroundColor: AppTheme.surfaceElevated,
            ),

          // Schedule List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.brandGreen),
                  )
                : filteredClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_note_rounded, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No sessions scheduled for ${_getDayName(_weekDays[_selectedDayIndex].weekday)}, ${_weekDays[_selectedDayIndex].day}/${_weekDays[_selectedDayIndex].month}.',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Studio rooms are open for faculty practice.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
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
        onPressed: _showScheduleSessionDialog,
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

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Widget _buildDaySelector() {
    return Container(
      color: AppTheme.surfaceCard,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_weekDays.length, (index) {
          final isSelected = index == _selectedDayIndex;
          final d = _weekDays[index];
          final dayName = _getDayName(d.weekday);
          final dayNum = '${d.day}';

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
              _fetchScheduleForDate(d);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
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
                    dayName,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryBackground : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNum,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryBackground : AppTheme.textWhite,
                      fontSize: 15,
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
    final filters = _studioFilters;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primaryBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((studio) {
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.brandGreen),
                tooltip: 'Notify / Message Student',
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
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_rounded, size: 14, color: AppTheme.brandGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: ${item.notes}',
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 11.5, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  label: Text(item.notes.isEmpty ? 'Add Lesson Note' : 'Edit Note'),
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
                    StudentCommunicationSheet.show(
                      context,
                      studentName: item.studentName,
                      studentId: item.studentId,
                      studentPhone: item.studentPhone,
                      studentEmail: item.studentEmail,
                      courseName: item.courseName,
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('Message Student'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Launching Studio Room: ${item.studio}...'),
                  backgroundColor: AppTheme.brandBlue,
                  duration: const Duration(seconds: 2),
                ),
              );
              final ok = await TeacherSupabaseService.instance.launchLiveStudioRoom(item.studio);
              if (!ok) {
                final cleanRoom = item.studio
                    .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
                    .toLowerCase()
                    .replaceAll(RegExp(r'_+'), '_')
                    .replaceAll(RegExp(r'^_|_$'), '');
                final roomUrl = 'https://meet.jit.si/kmc_masterclass_$cleanRoom';
                await Clipboard.setData(ClipboardData(text: roomUrl));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Studio link copied to clipboard: $roomUrl'),
                    backgroundColor: AppTheme.brandGreen,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            icon: const Icon(Icons.videocam_rounded, size: 15),
            label: Text(
              item.isLiveNow ? 'Join Studio Video Room (Jitsi Meet)' : 'Open Studio Room: ${item.studio}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: item.isLiveNow ? AppTheme.brandGreen : AppTheme.brandBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
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

  void _showScheduleSessionDialog() async {
    final students = await TeacherSupabaseService.instance.fetchAssignedStudents(_teacher!);
    if (!mounted) return;

    StudentRosterItem? selectedStudent = students.isNotEmpty ? students.first : null;
    String selectedStudio = 'Studio 3 (Yamaha C7 Grand)';
    final topicController = TextEditingController(text: 'Repertoire Drill & Technique Coaching');
    DateTime selectedDate = _weekDays[_selectedDayIndex];
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    bool isSaving = false;

    final studios = [
      'Studio 1 — Roland Digital Lab',
      'Studio 2 — Fender / Drum Clinician Suite',
      'Studio 3 (Yamaha C7 Grand)',
      'Studio 4 — Vocal & Wind Room',
      'Theory Lab 1',
    ];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderOutline),
              ),
              title: const Text(
                'Schedule Studio Masterclass',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Student', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<StudentRosterItem>(
                      initialValue: selectedStudent,
                      dropdownColor: AppTheme.surfaceElevated,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: students.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.studentId})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedStudent = val),
                    ),
                    const SizedBox(height: 12),

                    const Text('Studio Room', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStudio,
                      dropdownColor: AppTheme.surfaceElevated,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: studios.map((st) {
                        return DropdownMenuItem(value: st, child: Text(st, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedStudio = val ?? selectedStudio),
                    ),
                    const SizedBox(height: 12),

                    const Text('Lesson Topic', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: topicController,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Autumn Leaves rootless voicings',
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Session Date:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setDlgState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.brandGreen),
                          label: Text(
                            '${_getDayName(selectedDate.weekday)}, ${selectedDate.day}/${selectedDate.month}',
                            style: const TextStyle(color: AppTheme.brandGreen, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Session Time:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setDlgState(() => selectedTime = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.brandGreen),
                          label: Text(
                            selectedTime.format(context),
                            style: const TextStyle(color: AppTheme.brandGreen, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                FilledButton(
                  onPressed: isSaving || selectedStudent == null
                      ? null
                      : () async {
                          setDlgState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final scheduledDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          final teacherId = _teacher?.teacherTableId.isNotEmpty == true
                              ? _teacher!.teacherTableId
                              : (_teacher?.id ?? '');

                          final success = await TeacherSupabaseService.instance.scheduleStudioSession(
                            teacherId: teacherId,
                            studentId: selectedStudent!.id,
                            scheduledAt: scheduledDateTime,
                            studioRoom: selectedStudio,
                            topic: topicController.text.trim(),
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            final matchIdx = _weekDays.indexWhere((wd) =>
                                wd.year == selectedDate.year &&
                                wd.month == selectedDate.month &&
                                wd.day == selectedDate.day);
                            if (matchIdx != -1) {
                              setState(() {
                                _selectedDayIndex = matchIdx;
                              });
                            }
                            await _fetchScheduleForDate(_weekDays[_selectedDayIndex]);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '✓ Studio session for ${selectedStudent!.name} booked for ${_getDayName(selectedDate.weekday)} ${selectedDate.day}/${selectedDate.month}!'
                                      : 'Session scheduled on device.',
                                ),
                                backgroundColor: AppTheme.brandGreen,
                              ),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.brandGreen),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Confirm Booking', style: TextStyle(color: AppTheme.primaryBackground)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
