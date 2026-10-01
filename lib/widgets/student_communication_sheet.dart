import 'package:flutter/material.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';

/// Interactive Student Communication & Multi-Channel Dispatch Sheet.
/// Allows KMC Faculty to notify individual students through Central Mind in-app push,
/// direct WhatsApp messaging (wa.me), and official Email (mailto:).
class StudentCommunicationSheet extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String studentPhone;
  final String studentEmail;
  final String? courseTitle;
  final String? defaultTimeSlot;
  final String? defaultStudio;

  const StudentCommunicationSheet({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.studentPhone,
    required this.studentEmail,
    this.courseTitle,
    this.defaultTimeSlot,
    this.defaultStudio,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentName,
    required String studentId,
    String? studentPhone,
    String? studentEmail,
    String? courseTitle,
    String? courseName,
    String? defaultTimeSlot,
    String? defaultStudio,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StudentCommunicationSheet(
        studentName: studentName,
        studentId: studentId,
        studentPhone: studentPhone ?? '',
        studentEmail: studentEmail ?? '',
        courseTitle: courseTitle ?? courseName,
        defaultTimeSlot: defaultTimeSlot,
        defaultStudio: defaultStudio,
      ),
    );
  }

  @override
  State<StudentCommunicationSheet> createState() => _StudentCommunicationSheetState();
}

class _StudentCommunicationSheetState extends State<StudentCommunicationSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  String _selectedCategory = 'Lesson Schedule';
  bool _isSendingInApp = false;

  final List<String> _categories = [
    'Lesson Schedule',
    'Practice Rehearsal',
    'Drill Assignment',
    'Attendance Follow-up',
    'General Memo',
  ];

  @override
  void initState() {
    super.initState();
    final course = widget.courseTitle ?? 'Instrument Studies';
    final time = widget.defaultTimeSlot ?? 'Upcoming Session';
    final studio = widget.defaultStudio ?? 'Studio 3';

    _titleController = TextEditingController(
      text: '[$course] Session Update — $time',
    );

    _messageController = TextEditingController(
      text: 'Dear ${widget.studentName} (${widget.studentId}),\n\n'
          'This is a notification regarding your $course class at Kasarani Music Center.\n'
          'Location: $studio\n'
          'Time Slot: $time\n\n'
          'Please ensure your sheet music and practice drills are prepared ahead of time.\n\n'
          'Regards,\n'
          '${TeacherSupabaseService.instance.activeTeacher?.name ?? "Faculty Instructor"}\n'
          'Kasarani Music Center',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _dispatchInAppNotification() async {
    final title = _titleController.text.trim();
    final msg = _messageController.text.trim();
    if (title.isEmpty || msg.isEmpty) return;

    setState(() => _isSendingInApp = true);
    final teacher = TeacherSupabaseService.instance.activeTeacher;

    final success = await TeacherSupabaseService.instance.sendStudentNotification(
      studentId: widget.studentId,
      studentName: widget.studentName,
      teacherId: teacher?.id ?? 'faculty',
      teacherName: teacher?.name ?? 'Faculty Instructor',
      title: title,
      message: msg,
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() => _isSendingInApp = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Central Mind Notification sent to ${widget.studentName}!'),
            backgroundColor: AppTheme.brandGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send notification. Please check Central Mind connection.'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  void _shareViaWhatsApp() {
    final msg = _messageController.text.trim();
    final phone = widget.studentPhone.isNotEmpty ? widget.studentPhone : '+254700000000';
    TeacherSupabaseService.instance.launchWhatsApp(phone, msg);
  }

  void _shareViaEmail() {
    final title = _titleController.text.trim();
    final msg = _messageController.text.trim();
    final email = widget.studentEmail.isNotEmpty ? widget.studentEmail : 'student@kasaranimusic.ac.ke';
    TeacherSupabaseService.instance.launchEmail(email, title, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.send_rounded, color: AppTheme.brandGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dispatch Student Notification',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Target: ${widget.studentName} (${widget.studentId})',
                        style: const TextStyle(
                          color: AppTheme.accentSky,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Picker
            const Text('Notification Category', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSel,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : AppTheme.textWhite,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: AppTheme.brandGreen,
                      backgroundColor: AppTheme.surfaceElevated,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Subject / Title
            const Text('Announcement Subject', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w700),
              decoration: _inputDecoration('e.g. Studio Rehearsal Time Shift'),
            ),
            const SizedBox(height: 12),

            // Message Body
            const Text('Message Body', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 12.5, height: 1.4),
              decoration: _inputDecoration('Type the notification or lesson instructions here...'),
            ),
            const SizedBox(height: 18),

            // Action Buttons Bar
            Column(
              children: [
                // 1. Central Mind In-App Push Dispatch
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingInApp ? null : _dispatchInAppNotification,
                    icon: _isSendingInApp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.notifications_active_rounded, size: 18, color: Colors.black),
                    label: Text(
                      _isSendingInApp ? 'Sending to Student App...' : 'Send In-App Notification (Central Mind)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Multi-channel External Share Row (WhatsApp & Email)
                Row(
                  children: [
                    // WhatsApp Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareViaWhatsApp,
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                        label: const Text(
                          'Share via WhatsApp',
                          style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Email Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareViaEmail,
                        icon: const Icon(Icons.email_outlined, color: AppTheme.accentSky, size: 18),
                        label: const Text(
                          'Send via Email',
                          style: TextStyle(color: AppTheme.accentSky, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.accentSky, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      filled: true,
      fillColor: AppTheme.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.brandGreen),
      ),
    );
  }
}
