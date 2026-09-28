import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../theme/app_theme.dart';

class TeacherSubmissionsScreen extends StatefulWidget {
  const TeacherSubmissionsScreen({super.key});

  @override
  State<TeacherSubmissionsScreen> createState() => _TeacherSubmissionsScreenState();
}

class _TeacherSubmissionsScreenState extends State<TeacherSubmissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<StudentSubmission> _submissions = MockTeacherData.submissions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEvaluationSheet(StudentSubmission sub) {
    double rhythmRating = sub.rating ?? 4.0;
    double techniqueRating = sub.rating ?? 4.5;
    double phrasingRating = sub.rating ?? 4.0;
    final feedbackController = TextEditingController(text: sub.teacherFeedback ?? '');
    bool isPlaying = false;

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
                      onPressed: () {
                        setState(() {
                          sub.isReviewed = true;
                          sub.rating = ((rhythmRating + techniqueRating + phrasingRating) / 3 * 10).round() / 10;
                          sub.teacherFeedback = feedbackController.text.trim().isEmpty
                              ? 'Drill verified and approved with score ${sub.rating}/5.0.'
                              : feedbackController.text.trim();
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Drill approved for ${sub.studentName}! Notification dispatched.'),
                            backgroundColor: AppTheme.brandGreenDark,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Approve Drill & Send Feedback'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending Evaluation (${pending.length})'),
            Tab(text: 'Reviewed (${reviewed.length})'),
          ],
        ),
      ),
      body: TabBarView(
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
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sub = list[index];
        return _buildSubmissionCard(sub, isPending: isPending);
      },
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
