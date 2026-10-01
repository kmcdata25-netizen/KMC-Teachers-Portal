import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_communication_sheet.dart';

class TeacherSubmissionsScreen extends StatefulWidget {
  const TeacherSubmissionsScreen({super.key});

  @override
  State<TeacherSubmissionsScreen> createState() => _TeacherSubmissionsScreenState();
}

class _TeacherSubmissionsScreenState extends State<TeacherSubmissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudentSubmission> _submissions = [];
  bool _isLoading = true;
  TeacherProfile? _teacher;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubmissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    _teacher = TeacherSupabaseService.instance.activeTeacher;
    _teacher ??= await TeacherSupabaseService.instance.checkSavedSession();
    _teacher ??= MockTeacherData.currentTeacher;

    try {
      final list = await TeacherSupabaseService.instance.fetchStudentSubmissions(_teacher!);
      if (mounted) {
        setState(() {
          _submissions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissions = MockTeacherData.submissions;
          _isLoading = false;
        });
      }
    }
  }

  void _showEvaluationSheet(StudentSubmission sub) {
    double rhythmRating = sub.rating ?? 4.0;
    double techniqueRating = sub.rating ?? 4.5;
    double phrasingRating = sub.rating ?? 4.0;
    final feedbackController = TextEditingController(text: sub.teacherFeedback ?? '');
    bool isPlaying = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

                    // Header
                    const Text(
                      'Evaluate Student Practice Drill',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sub.studentName} (${sub.studentId}) • ${sub.courseTitle}',
                      style: const TextStyle(
                        color: AppTheme.accentSky,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Media Player Mockup Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderOutline),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.brandGreen),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: AppTheme.brandGreen,
                                  ),
                                  onPressed: () {
                                    setSheetState(() {
                                      isPlaying = !isPlaying;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.drillTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          isPlaying ? '00:34' : '00:00',
                                          style: const TextStyle(
                                            color: AppTheme.brandGreen,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Text(' / ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                        Text(
                                          sub.durationText,
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceElevated,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sub.mediaType.toUpperCase(),
                                            style: const TextStyle(
                                              color: AppTheme.brandGold,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: isPlaying ? 0.45 : 0.0,
                              minHeight: 4,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation(AppTheme.brandGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Student's Self-Reflection
                    if (sub.studentNotes.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '💬 Student Note: "${sub.studentNotes}"',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Rubric Grading Sliders
                    const Text(
                      'Rubric Scoring',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildRatingRow('Rhythm & Timing', rhythmRating, (val) {
                      setSheetState(() => rhythmRating = val);
                    }),
                    _buildRatingRow('Hand Technique / Posture', techniqueRating, (val) {
                      setSheetState(() => techniqueRating = val);
                    }),
                    _buildRatingRow('Expression & Dynamics', phrasingRating, (val) {
                      setSheetState(() => phrasingRating = val);
                    }),
                    const SizedBox(height: 14),

                    // Teacher Feedback Field
                    const Text(
                      'Instructor Feedback to Student',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Great phrasing! Keep an eye on the transition in bar 8...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.borderOutline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Feedback Button
                    FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              final calculatedRating = ((rhythmRating + techniqueRating + phrasingRating) / 3 * 10).round() / 10;
                              final feedback = feedbackController.text.trim().isEmpty
                                  ? 'Drill verified and approved with score $calculatedRating/5.0.'
                                  : feedbackController.text.trim();

                              final messenger = ScaffoldMessenger.of(context);
                              final success = await TeacherSupabaseService.instance.submitDrillReview(
                                submissionId: sub.id,
                                rating: calculatedRating,
                                feedback: feedback,
                              );

                              // Also send student a Central Mind notification
                              await TeacherSupabaseService.instance.sendStudentNotification(
                                studentId: sub.studentId,
                                title: 'Practice Drill Evaluated: ${sub.drillTitle}',
                                message: 'Your instructor scored this drill $calculatedRating/5.0. Notes: $feedback',
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() {
                                  sub.isReviewed = true;
                                  sub.rating = calculatedRating;
                                  sub.teacherFeedback = feedback;
                                });
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? '✓ Evaluation saved to Central Mind! Notification dispatched to ${sub.studentName}.'
                                          : 'Evaluation recorded for ${sub.studentName}.',
                                    ),
                                    backgroundColor: AppTheme.brandGreen,
                                  ),
                                );
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(isSubmitting ? 'Saving to Central Mind...' : 'Approve Drill & Send Feedback'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: AppTheme.primaryBackground,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingRow(String title, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            title,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 6,
          child: Slider(
            value: value,
            min: 1.0,
            max: 5.0,
            divisions: 8,
            activeColor: AppTheme.brandGreen,
            inactiveColor: AppTheme.surfaceElevated,
            onChanged: onChanged,
          ),
        ),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            color: AppTheme.brandGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _submissions.where((s) => !s.isReviewed).toList();
    final reviewed = _submissions.where((s) => s.isReviewed).toList();

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Student Submissions'),
        actions: [
          IconButton(
            onPressed: _loadSubmissions,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Submissions',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending Evaluation (${pending.length})'),
            Tab(text: 'Reviewed (${reviewed.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubmissionList(pending, isPending: true),
                _buildSubmissionList(reviewed, isPending: false),
              ],
            ),
    );
  }

  Widget _buildSubmissionList(List<StudentSubmission> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline_rounded : Icons.history_rounded,
              size: 48,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isPending ? 'All caught up! No pending submissions.' : 'No reviewed drills yet.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _loadSubmissions,
              child: const Text('Refresh from Central Mind', style: TextStyle(color: AppTheme.brandGreen)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      color: AppTheme.brandGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final sub = list[index];
          return _buildSubmissionCard(sub, isPending: isPending);
        },
      ),
    );
  }

  Widget _buildSubmissionCard(StudentSubmission sub, {required bool isPending}) {
    IconData mediaIcon;
    Color mediaColor;

    switch (sub.mediaType.toLowerCase()) {
      case 'video':
        mediaIcon = Icons.videocam_rounded;
        mediaColor = AppTheme.accentSky;
        break;
      case 'audio':
        mediaIcon = Icons.mic_rounded;
        mediaColor = AppTheme.brandGreen;
        break;
      default:
        mediaIcon = Icons.menu_book_rounded;
        mediaColor = AppTheme.brandGold;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? AppTheme.borderOutline : AppTheme.borderOutline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(mediaIcon, size: 18, color: mediaColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.studentName,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${sub.studentId} • ${sub.courseTitle}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppTheme.brandGold.withValues(alpha: 0.15)
                      : AppTheme.brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending ? 'PENDING' : '★ ${sub.rating ?? 5.0}',
                  style: TextStyle(
                    color: isPending ? AppTheme.brandGold : AppTheme.brandGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.brandGreen),
                tooltip: 'Message ${sub.studentName}',
                onPressed: () {
                  StudentCommunicationSheet.show(
                    context,
                    studentName: sub.studentName,
                    studentId: sub.studentId,
                    courseName: sub.courseTitle,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sub.drillTitle,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                'Submitted ${sub.submittedTime} • Length: ${sub.durationText}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          if (sub.isReviewed && sub.teacherFeedback != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Feedback: "${sub.teacherFeedback}"',
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isPending
                ? FilledButton.icon(
                    onPressed: () => _showEvaluationSheet(sub),
                    icon: const Icon(Icons.rate_review_rounded, size: 16),
                    label: const Text('Evaluate & Grade'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _showEvaluationSheet(sub),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Edit Evaluation'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
