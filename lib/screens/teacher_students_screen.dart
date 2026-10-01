import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_communication_sheet.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<StudentRosterItem> _allStudents = [];
  bool _isLoading = true;
  TeacherProfile? _teacher;

  @override
  void initState() {
    super.initState();
    _loadLiveStudents();
  }

  Future<void> _loadLiveStudents() async {
    setState(() => _isLoading = true);
    _teacher = TeacherSupabaseService.instance.activeTeacher;
    _teacher ??= await TeacherSupabaseService.instance.checkSavedSession();
    _teacher ??= MockTeacherData.currentTeacher;

    try {
      final list = await TeacherSupabaseService.instance.fetchAssignedStudents(_teacher!);
      if (mounted) {
        setState(() {
          _allStudents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allStudents = MockTeacherData.students;
          _isLoading = false;
        });
      }
    }
  }

  List<String> get _filters {
    final filters = <String>{'All'};
    for (final s in _allStudents) {
      if (s.instrument.isNotEmpty) {
        filters.add(s.instrument);
      }
    }
    return filters.toList();
  }

  void _showStudentDossier(StudentRosterItem student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
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

                  // Student Top Profile
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceElevated,
                          border: Border.all(color: AppTheme.brandGreen, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            student.name.isNotEmpty
                                ? student.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                : 'ST',
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
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
                              student.name,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${student.studentId} • ${student.course}',
                              style: const TextStyle(
                                color: AppTheme.accentSky,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (student.studentPhone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '📞 ${student.studentPhone}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Dispatch Strip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderOutline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickActionBtn(
                          icon: Icons.send_rounded,
                          label: 'In-App',
                          color: AppTheme.brandGreen,
                          onTap: () {
                            Navigator.pop(ctx);
                            StudentCommunicationSheet.show(
                              context,
                              studentName: student.name,
                              studentId: student.studentId,
                              studentPhone: student.studentPhone,
                              studentEmail: student.studentEmail,
                              courseName: student.course,
                            );
                          },
                        ),
                        _buildQuickActionBtn(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (student.studentPhone.isNotEmpty) {
                              TeacherSupabaseService.instance.launchWhatsApp(
                                student.studentPhone,
                                'Hello ${student.name}, this is your instructor from Kasarani Music School.',
                              );
                            } else {
                              StudentCommunicationSheet.show(
                                context,
                                studentName: student.name,
                                studentId: student.studentId,
                                studentPhone: student.studentPhone,
                                studentEmail: student.studentEmail,
                                courseName: student.course,
                              );
                            }
                          },
                        ),
                        _buildQuickActionBtn(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          color: AppTheme.accentSky,
                          onTap: () {
                            Navigator.pop(ctx);
                            if (student.studentEmail.isNotEmpty) {
                              TeacherSupabaseService.instance.launchEmail(
                                student.studentEmail,
                                'KMC Musical Progress Update: ${student.course}',
                                'Hello ${student.name},\n\nHere is your weekly update and practice focus.',
                              );
                            } else {
                              StudentCommunicationSheet.show(
                                context,
                                studentName: student.name,
                                studentId: student.studentId,
                                studentPhone: student.studentPhone,
                                studentEmail: student.studentEmail,
                                courseName: student.course,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress & Attendance Bar
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Syllabus Mastery',
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${(student.progressPercent * 100).toInt()}% Complete',
                              style: const TextStyle(
                                color: AppTheme.brandGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: student.progressPercent,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryBackground,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.brandGreen),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Lessons: ${student.completedLessons} Completed',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                            Text(
                              'Attendance: ${student.attendancePercent}%',
                              style: const TextStyle(color: AppTheme.brandGold, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Last Lesson Note
                  const Text(
                    'Instructor Notes & Practice Drills',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderOutline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sticky_note_2_rounded, size: 14, color: AppTheme.brandGreen),
                            SizedBox(width: 6),
                            Text(
                              'Latest Observation',
                              style: TextStyle(color: AppTheme.brandGreen, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          student.lastLessonNote,
                          style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Primary Dispatch Button
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      StudentCommunicationSheet.show(
                        context,
                        studentName: student.name,
                        studentId: student.studentId,
                        studentPhone: student.studentPhone,
                        studentEmail: student.studentEmail,
                        courseName: student.course,
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Compose Student Notification / Dispatch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandGreen,
                      foregroundColor: AppTheme.primaryBackground,
                      minimumSize: const Size(double.infinity, 44),
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

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filteredStudents = _allStudents.where((s) {
      final matchesFilter = _selectedFilter == 'All' || s.instrument == _selectedFilter;
      final matchesQuery = query.isEmpty ||
          s.name.toLowerCase().contains(query) ||
          s.studentId.toLowerCase().contains(query) ||
          s.course.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Student Roster'),
        actions: [
          IconButton(
            onPressed: _loadLiveStudents,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Roster',
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Student Roster is connected live to Central Mind (Supabase).'),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_rounded),
            tooltip: 'Central Mind Connected',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLiveStudents,
        color: AppTheme.brandGreen,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by student name, KMC ID, or course...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderOutline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderOutline),
                  ),
                ),
              ),
            ),

            // Filter Segment Chips
            if (_filters.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                          selectedColor: AppTheme.brandGreen,
                          backgroundColor: AppTheme.surfaceCard,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryBackground : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppTheme.brandGreen : AppTheme.borderOutline,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 6),

            if (_isLoading)
              const LinearProgressIndicator(
                color: AppTheme.brandGreen,
                backgroundColor: AppTheme.surfaceElevated,
              ),

            // Students Roster List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.brandGreen))
                  : filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text(
                                'No enrolled students found.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: _loadLiveStudents,
                                child: const Text('Refresh from Central Mind', style: TextStyle(color: AppTheme.brandGreen)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildStudentCard(filteredStudents[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentRosterItem student) {
    return InkWell(
      onTap: () => _showStudentDossier(student),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOutline, width: 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initials Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceElevated,
                    border: Border.all(color: AppTheme.borderOutline),
                  ),
                  child: Center(
                    child: Text(
                      student.name.isNotEmpty
                          ? student.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                          : 'ST',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${student.studentId} • ${student.course}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Attendance Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${student.attendancePercent}% Att.',
                    style: const TextStyle(
                      color: AppTheme.brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.brandGreen),
                  tooltip: 'Notify ${student.name}',
                  onPressed: () {
                    StudentCommunicationSheet.show(
                      context,
                      studentName: student.name,
                      studentId: student.studentId,
                      studentPhone: student.studentPhone,
                      studentEmail: student.studentEmail,
                      courseName: student.course,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: student.progressPercent,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.brandGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(student.progressPercent * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Next class preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next: ${student.nextClass}',
                  style: const TextStyle(color: AppTheme.accentSky, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
