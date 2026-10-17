/// Mock data models and placeholder state for Kasarani Music Center Teacher Portal.
/// Enables comprehensive UI review and client alignment before backend wiring.
library;

class TeacherProfile {
  final String id;
  final String teacherTableId;
  final String name;
  final String title;
  final String facultyId;
  final String department;
  final String email;
  final String phone;
  final String studio;
  final String status;
  final String avatarInitials;
  final double hourlyRate;
  final double rating;
  final List<String> instruments;
  final List<String> availableDays;

  const TeacherProfile({
    this.id = '',
    this.teacherTableId = '',
    required this.name,
    required this.title,
    required this.facultyId,
    required this.department,
    required this.email,
    required this.phone,
    required this.studio,
    required this.status,
    required this.avatarInitials,
    this.hourlyRate = 0.0,
    this.rating = 0.0,
    this.instruments = const [],
    this.availableDays = const [],
  });

  String get assignedStudio => studio;
}

class TeacherMetric {
  final String label;
  final String value;
  final String subtitle;
  final String iconKey;

  const TeacherMetric({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.iconKey,
  });
}

enum AttendanceState {
  unmarked,
  present,
  absent,
  excused,
}

class KmcChannelHelper {
  static String sanitize(String studio) {
    final lower = studio.toLowerCase().trim();
    if (lower.contains('studio 3') || lower.contains('studio_3') || lower.contains('yamaha c7') || lower.contains('grand')) {
      return 'kmc_studio_3';
    }
    if (lower.contains('studio 1') || lower.contains('studio_1')) {
      return 'kmc_studio_1';
    }
    if (lower.contains('studio 2') || lower.contains('studio_2')) {
      return 'kmc_studio_2';
    }
    if (lower.contains('studio 4') || lower.contains('studio_4')) {
      return 'kmc_studio_4';
    }
    if (lower.contains('sound lab') || lower.contains('lab 1')) {
      return 'kmc_sound_lab_1';
    }
    if (lower.contains('main hall') || lower.contains('hall')) {
      return 'kmc_main_hall';
    }
    final clean = lower
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return clean.isNotEmpty ? 'kmc_studio_$clean' : 'kmc_studio_3';
  }
}

class TeacherClass {
  final String id;
  final String courseName;
  final String level;
  final String studentName;
  final String studentId;
  final String studentPhone;
  final String studentEmail;
  final String timeSlot;
  final String studio;
  final String topic;
  String notes;
  AttendanceState attendance;
  final bool isLiveNow;
  final String agoraChannelName;
  final String agoraToken;
  final String studentProfileId;

  TeacherClass({
    required this.id,
    required this.courseName,
    required this.level,
    required this.studentName,
    required this.studentId,
    this.studentProfileId = '',
    this.studentPhone = '',
    this.studentEmail = '',
    required this.timeSlot,
    required this.studio,
    required this.topic,
    this.notes = '',
    this.attendance = AttendanceState.unmarked,
    this.isLiveNow = false,
    this.agoraChannelName = '',
    this.agoraToken = '',
  });

  /// Canonical Agora channel. Must match the student app's
  /// `LiveSessionModel.effectiveChannelName` exactly: both are derived from the
  /// studio name, never from legacy stored channel strings.
  String get effectiveChannelName => KmcChannelHelper.sanitize(
        studio.trim().isNotEmpty ? studio : agoraChannelName,
      );
}

class StudentRosterItem {
  final String id;
  final String name;
  final String studentId;
  final String course;
  final String instrument;
  final String phone;
  final String email;
  final double progressPercent;
  final int attendancePercent;
  final int completedLessons;
  final String nextClass;
  final String lastLessonNote;

  const StudentRosterItem({
    required this.id,
    required this.name,
    required this.studentId,
    required this.course,
    required this.instrument,
    this.phone = '',
    this.email = '',
    required this.progressPercent,
    required this.attendancePercent,
    required this.completedLessons,
    required this.nextClass,
    required this.lastLessonNote,
  });

  String get studentPhone => phone;
  String get studentEmail => email;
}

class StudentSubmission {
  final String id;
  final String studentName;
  final String studentId;
  final String courseTitle;
  final String drillTitle;
  final String submittedTime;
  final String durationText;
  final String mediaType; // 'Video', 'Audio', or 'Score'
  final String? mediaUrl;
  final String studentNotes;
  bool isReviewed;
  double? rating;
  String? teacherFeedback;

  StudentSubmission({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.courseTitle,
    required this.drillTitle,
    required this.submittedTime,
    required this.durationText,
    required this.mediaType,
    this.mediaUrl,
    required this.studentNotes,
    this.isReviewed = false,
    this.rating,
    this.teacherFeedback,
  });
}

class MockTeacherData {
  static const TeacherProfile currentTeacher = TeacherProfile(
    id: '',
    teacherTableId: '',
    name: '',
    title: '',
    facultyId: '',
    department: '',
    email: '',
    phone: '',
    studio: '',
    status: '⚪ Offline',
    avatarInitials: '',
  );

  static const List<TeacherMetric> metrics = [];
  static final List<TeacherClass> todaySchedule = [];
  static final List<StudentSubmission> submissions = [];
}
