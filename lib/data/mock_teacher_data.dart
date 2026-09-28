/// Mock data models and placeholder state for Kasarani Music Center Teacher Portal.
/// Enables comprehensive UI review and client alignment before backend wiring.
library;

class TeacherProfile {
  final String name;
  final String title;
  final String facultyId;
  final String department;
  final String email;
  final String phone;
  final String studio;
  final String status;
  final String avatarInitials;

  const TeacherProfile({
    required this.name,
    required this.title,
    required this.facultyId,
    required this.department,
    required this.email,
    required this.phone,
    required this.studio,
    required this.status,
    required this.avatarInitials,
  });
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

class TeacherClass {
  final String id;
  final String courseName;
  final String level;
  final String studentName;
  final String studentId;
  final String timeSlot;
  final String studio;
  final String topic;
  AttendanceState attendance;
  final bool isLiveNow;

  TeacherClass({
    required this.id,
    required this.courseName,
    required this.level,
    required this.studentName,
    required this.studentId,
    required this.timeSlot,
    required this.studio,
    required this.topic,
    this.attendance = AttendanceState.unmarked,
    this.isLiveNow = false,
  });
}

class StudentRosterItem {
  final String id;
  final String name;
  final String studentId;
  final String course;
  final String instrument;
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
    required this.progressPercent,
    required this.attendancePercent,
    required this.completedLessons,
    required this.nextClass,
    required this.lastLessonNote,
  });
}

class StudentSubmission {
  final String id;
  final String studentName;
  final String studentId;
  final String courseTitle;
  final String drillTitle;
  final String submittedTime;
  final String durationText;
  final String mediaType; // 'Video' or 'Audio'
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
    required this.studentNotes,
    this.isReviewed = false,
    this.rating,
    this.teacherFeedback,
  });
}

class MockTeacherData {
  static const TeacherProfile currentTeacher = TeacherProfile(
    name: 'David Otieno',
    title: 'Senior Piano & Composition Faculty',
    facultyId: 'KMC-FAC-014',
    department: 'Keyboard & Theory Studies',
    email: 'david.otieno@kasaranimusic.ac.ke',
    phone: '+254 722 000 111',
    studio: 'Studio 3 — Yamaha C7 Acoustic Grand',
    status: '🟢 Available & In Studio',
    avatarInitials: 'DO',
  );

  static const List<TeacherMetric> metrics = [
    TeacherMetric(
      label: 'Active Students',
      value: '24',
      subtitle: 'Across 4 courses',
      iconKey: 'students',
    ),
    TeacherMetric(
      label: 'Classes Today',
      value: '4',
      subtitle: '2 remaining',
      iconKey: 'schedule',
    ),
    TeacherMetric(
      label: 'Pending Reviews',
      value: '7',
      subtitle: 'Drill submissions',
      iconKey: 'reviews',
    ),
    TeacherMetric(
      label: 'Teaching Hours',
      value: '38.5 hrs',
      subtitle: 'September cycle',
      iconKey: 'hours',
    ),
  ];

  static List<TeacherClass> todaySchedule = [
    TeacherClass(
      id: 'tc_101',
      courseName: 'Contemporary Jazz Piano',
      level: 'Intermediate (Module 2)',
      studentName: 'Brian Mwangi',
      studentId: 'KMC-2026-1042',
      timeSlot: '10:00 AM – 11:00 AM',
      studio: 'Studio 3',
      topic: 'Lesson 03: Rootless Type-A & Type-B 3-7 Shell Voicings',
      attendance: AttendanceState.present,
      isLiveNow: false,
    ),
    TeacherClass(
      id: 'tc_102',
      courseName: 'Contemporary Jazz Piano',
      level: 'Advanced',
      studentName: 'Faith Wanjiku',
      studentId: 'KMC-2026-1018',
      timeSlot: '11:30 AM – 12:30 PM',
      studio: 'Studio 3',
      topic: 'Bebop Scales & Left-Hand Comping Patterns',
      attendance: AttendanceState.present,
      isLiveNow: false,
    ),
    TeacherClass(
      id: 'tc_103',
      courseName: 'Music Theory & Harmony',
      level: 'Foundation',
      studentName: 'Kevin Kiprop',
      studentId: 'KMC-2026-1055',
      timeSlot: '03:00 PM – 04:00 PM',
      studio: 'Sound Lab 1',
      topic: 'Circle of Fifths & Secondary Dominants',
      attendance: AttendanceState.unmarked,
      isLiveNow: true,
    ),
    TeacherClass(
      id: 'tc_104',
      courseName: 'Contemporary Jazz Piano',
      level: 'Beginner',
      studentName: 'Joy Achieng',
      studentId: 'KMC-2026-1089',
      timeSlot: '04:30 PM – 05:30 PM',
      studio: 'Studio 3',
      topic: 'Major Triad Inversions & Arpeggio Fluency',
      attendance: AttendanceState.unmarked,
      isLiveNow: false,
    ),
  ];

  static List<StudentRosterItem> students = [
    const StudentRosterItem(
      id: 'st_01',
      name: 'Brian Mwangi',
      studentId: 'KMC-2026-1042',
      course: 'Contemporary Jazz Piano',
      instrument: 'Piano',
      progressPercent: 0.68,
      attendancePercent: 95,
      completedLessons: 14,
      nextClass: 'Today @ 10:00 AM',
      lastLessonNote: 'Great left hand phrasing. Need to tighten metronome sync at 80 BPM.',
    ),
    const StudentRosterItem(
      id: 'st_02',
      name: 'Faith Wanjiku',
      studentId: 'KMC-2026-1018',
      course: 'Contemporary Jazz Piano',
      instrument: 'Piano',
      progressPercent: 0.85,
      attendancePercent: 100,
      completedLessons: 21,
      nextClass: 'Today @ 11:30 AM',
      lastLessonNote: 'Improvisation over ii-V-I turnaround is sounding mature and musical.',
    ),
    const StudentRosterItem(
      id: 'st_03',
      name: 'Kevin Kiprop',
      studentId: 'KMC-2026-1055',
      course: 'Music Theory & Harmony',
      instrument: 'Theory',
      progressPercent: 0.45,
      attendancePercent: 88,
      completedLessons: 8,
      nextClass: 'Today @ 3:00 PM',
      lastLessonNote: 'Struggling slightly with diminished 7th resolution; assign review drill.',
    ),
    const StudentRosterItem(
      id: 'st_04',
      name: 'Joy Achieng',
      studentId: 'KMC-2026-1089',
      course: 'Contemporary Jazz Piano',
      instrument: 'Piano',
      progressPercent: 0.32,
      attendancePercent: 92,
      completedLessons: 5,
      nextClass: 'Today @ 4:30 PM',
      lastLessonNote: 'Posture is improving. Work on thumb-under technique for C major scale.',
    ),
    const StudentRosterItem(
      id: 'st_05',
      name: 'Emmanuel Omondi',
      studentId: 'KMC-2026-1022',
      course: 'Contemporary Jazz Piano',
      instrument: 'Piano',
      progressPercent: 0.55,
      attendancePercent: 90,
      completedLessons: 11,
      nextClass: 'Tomorrow @ 10:00 AM',
      lastLessonNote: 'Mastered Autumn Leaves melody; transitioning to walking bass lines.',
    ),
    const StudentRosterItem(
      id: 'st_06',
      name: 'Priscilla Muthoni',
      studentId: 'KMC-2026-1077',
      course: 'Music Theory & Harmony',
      instrument: 'Theory',
      progressPercent: 0.72,
      attendancePercent: 96,
      completedLessons: 16,
      nextClass: 'Tomorrow @ 2:00 PM',
      lastLessonNote: 'Exam prep is on track. High marks on modulation exercises.',
    ),
  ];

  static List<StudentSubmission> submissions = [
    StudentSubmission(
      id: 'sub_01',
      studentName: 'Brian Mwangi',
      studentId: 'KMC-2026-1042',
      courseTitle: 'Contemporary Jazz Piano',
      drillTitle: 'Drill 03: Two-Hand Rootless Shell Voicings with Swing Feel',
      submittedTime: '2 hours ago',
      durationText: '01:24 min',
      mediaType: 'Video',
      studentNotes: 'I used a metronome at 75 BPM. The switch to Type B took some effort.',
      isReviewed: false,
    ),
    StudentSubmission(
      id: 'sub_02',
      studentName: 'Faith Wanjiku',
      studentId: 'KMC-2026-1018',
      courseTitle: 'Contemporary Jazz Piano',
      drillTitle: 'Drill 05: Dorian Improvisation over So What Vamp',
      submittedTime: '4 hours ago',
      durationText: '02:15 min',
      mediaType: 'Audio',
      studentNotes: 'Focused on rhythmic displacement and quartal motifs.',
      isReviewed: false,
    ),
    StudentSubmission(
      id: 'sub_03',
      studentName: 'Kevin Kiprop',
      studentId: 'KMC-2026-1055',
      courseTitle: 'Music Theory & Harmony',
      drillTitle: 'Exercise 04: Voice Leading Secondary Dominants in F Major',
      submittedTime: 'Yesterday',
      durationText: 'PDF / Score',
      mediaType: 'Score',
      studentNotes: 'Uploaded my scanned manuscript worksheet for feedback.',
      isReviewed: false,
    ),
    StudentSubmission(
      id: 'sub_04',
      studentName: 'Joy Achieng',
      studentId: 'KMC-2026-1089',
      courseTitle: 'Contemporary Jazz Piano',
      drillTitle: 'Drill 01: Hanon No. 1 Finger Independence at 60 BPM',
      submittedTime: 'Yesterday',
      durationText: '00:58 min',
      mediaType: 'Video',
      studentNotes: 'Trying to keep wrists level as requested during our last class.',
      isReviewed: false,
    ),
    StudentSubmission(
      id: 'sub_05',
      studentName: 'Emmanuel Omondi',
      studentId: 'KMC-2026-1022',
      courseTitle: 'Contemporary Jazz Piano',
      drillTitle: 'Drill 02: Autumn Leaves A-Section Harmony Run',
      submittedTime: '2 days ago',
      durationText: '01:45 min',
      mediaType: 'Audio',
      studentNotes: 'Here is my recorded take with backing drums.',
      isReviewed: true,
      rating: 4.5,
      teacherFeedback: 'Outstanding swing articulation! Your bass lines connect smoothly.',
    ),
  ];
}
