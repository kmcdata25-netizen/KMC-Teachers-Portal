import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import '../data/mock_teacher_data.dart';

/// Central Supabase Mind Service for Kasarani Music Center Teacher Portal.
/// Directly connects Faculty to Supabase Central Mind backend for live metrics,
/// schedules, attendance, student rosters, drill evaluations, and student messaging.
class TeacherSupabaseService {
  static final TeacherSupabaseService instance = TeacherSupabaseService._internal();
  TeacherSupabaseService._internal();

  SupabaseClient? get _client =>
      TeacherSupabaseConfig.isInitialized ? TeacherSupabaseConfig.client : null;

  static const String _prefKeyTeacherId = 'kmc_logged_in_teacher_id';
  static const String _prefKeyTeacherEmail = 'kmc_logged_in_teacher_email';

  // Cached active teacher profile
  TeacherProfile? _activeTeacher;
  TeacherProfile? get activeTeacher => _activeTeacher;
  TeacherProfile? get currentTeacher => _activeTeacher;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & FACULTY AUTHORIZATION
  // ---------------------------------------------------------------------------

  /// Check if a valid teacher session exists in local storage
  Future<TeacherProfile?> checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefKeyTeacherId);
    final savedEmail = prefs.getString(_prefKeyTeacherEmail);

    if (savedId != null && savedId.isNotEmpty) {
      final profile = await fetchTeacherProfile(savedId);
      if (profile != null) {
        _activeTeacher = profile;
        return profile;
      }
    } else if (savedEmail != null && savedEmail.isNotEmpty) {
      final profile = await fetchTeacherProfileByEmail(savedEmail);
      if (profile != null) {
        _activeTeacher = profile;
        return profile;
      }
    }

    return null;
  }

  /// Authenticate faculty credentials and verify role = 'teacher'
  Future<AuthResult> loginFaculty({
    required String identifier,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return AuthResult.failure('Cannot connect to Central Mind. Offline mode.');
    }

    final trimmed = identifier.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanPassword.isEmpty) {
      return AuthResult.failure('Please enter your portal password.');
    }

    try {
      String emailToAuth = trimmed;

      // If identifier is not an email (e.g. Faculty ID KMC-FAC-014 or digits), find associated email
      if (!trimmed.contains('@')) {
        final query = client
            .from('profiles')
            .select('email, role')
            .eq('role', 'teacher')
            .or('student_id.ilike.%$trimmed%,phone.ilike.%$trimmed%');

        final dynamic res = await query;
        final list = res as List;
        if (list.isNotEmpty && list.first['email'] != null) {
          emailToAuth = list.first['email'].toString().toLowerCase().trim();
        } else {
          // Check by digits in faculty code
          final all = await fetchAllFaculty();
          final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
          TeacherProfile? match;
          for (final f in all) {
            final fDigits = f.facultyId.replaceAll(RegExp(r'[^0-9]'), '');
            if (f.facultyId.toLowerCase() == trimmed ||
                (digits.isNotEmpty && fDigits.endsWith(digits))) {
              match = f;
              break;
            }
          }
          if (match != null && match.email.isNotEmpty) {
            emailToAuth = match.email.toLowerCase().trim();
          } else {
            return AuthResult.failure(
              'Faculty account "$identifier" was not found in the KMC database.',
            );
          }
        }
      }

      // Strictly authenticate credentials against Supabase Auth
      try {
        final res = await client.auth.signInWithPassword(
          email: emailToAuth,
          password: cleanPassword,
        );

        if (res.user == null) {
          return AuthResult.failure('Invalid email or password.');
        }

        // Verify role in profiles table
        final profileRes = await client
            .from('profiles')
            .select('role')
            .eq('id', res.user!.id)
            .maybeSingle();

        if (profileRes != null && profileRes['role'] != 'teacher') {
          await client.auth.signOut();
          return AuthResult.failure(
            'Access Denied: This account is registered as a student. Only authorized KMC faculty may access the Teacher Portal.',
          );
        }

        final teacherProfile = await fetchTeacherProfile(res.user!.id);
        if (teacherProfile != null) {
          await _saveSession(teacherProfile.id, teacherProfile.email);
          _activeTeacher = teacherProfile;
          return AuthResult.success(teacherProfile);
        } else {
          return AuthResult.failure('Faculty instructor profile could not be loaded.');
        }
      } on AuthApiException catch (authErr) {
        debugPrint('[TeacherApp] AuthApiException: ${authErr.message}');
        final msg = authErr.message.toLowerCase();
        if (msg.contains('invalid') || msg.contains('credentials') || msg.contains('password')) {
          return AuthResult.failure('Invalid email or password. Please verify your credentials.');
        }
        return AuthResult.failure(authErr.message);
      } catch (authError) {
        debugPrint('[TeacherApp] Auth error: $authError');
        return AuthResult.failure('Invalid login credentials. Please check your password.');
      }
    } catch (e) {
      debugPrint('[TeacherApp] Login exception: $e');
      return AuthResult.failure('Authentication error: $e');
    }
  }

  Map<String, dynamic>? _extractTeacherData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return {};
  }

  List<dynamic> _safeList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    if (raw is Map) return [raw];
    return [];
  }

  Future<void> _saveSession(String teacherId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTeacherId, teacherId);
    await prefs.setString(_prefKeyTeacherEmail, email);
  }

  /// Sign out current teacher and clear session
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyTeacherId);
    await prefs.remove(_prefKeyTeacherEmail);
    _activeTeacher = null;
    try {
      await _client?.auth.signOut();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PROFILE & FACULTY RECORDS
  // ---------------------------------------------------------------------------

  /// Fetch teacher profile by faculty ID / Code, profile UUID, or email
  Future<TeacherProfile?> fetchTeacherProfile(String identifier) async {
    final client = _client;
    if (client == null) return null;

    try {
      final trimmed = identifier.trim();
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(trimmed);

      final query = client.from('profiles').select('*, teachers(*)').eq('role', 'teacher');
      final dynamic res;
      if (isUuid) {
        res = await query.eq('id', trimmed);
      } else {
        res = await query.or('student_id.ilike.%$trimmed%,email.ilike.%$trimmed%,phone.ilike.%$trimmed%');
      }

      final list = res as List;
      if (list.isNotEmpty) {
        final row = list.first as Map<String, dynamic>;
        final teacherData = _extractTeacherData(row['teachers']);
        return _mapToTeacherProfile(row, teacherData);
      }

      // Fallback matching against all faculty
      final all = await fetchAllFaculty();
      for (final f in all) {
        if (f.id == trimmed ||
            f.teacherTableId == trimmed ||
            f.facultyId.toLowerCase() == trimmed.toLowerCase() ||
            f.email.toLowerCase() == trimmed.toLowerCase() ||
            f.name.toLowerCase().contains(trimmed.toLowerCase())) {
          return f;
        }
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch teacher profile notice: $e');
    }
    return null;
  }

  /// Fetch teacher profile by email
  Future<TeacherProfile?> fetchTeacherProfileByEmail(String email) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client
          .from('profiles')
          .select('*, teachers(*)')
          .eq('role', 'teacher')
          .eq('email', email.trim().toLowerCase());

      final list = res as List;
      if (list.isNotEmpty) {
        final row = list.first as Map<String, dynamic>;
        final teacherData = _extractTeacherData(row['teachers']);
        return _mapToTeacherProfile(row, teacherData);
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch profile by email notice: $e');
    }
    return null;
  }

  /// Fetch all registered faculty members from Central Mind
  Future<List<TeacherProfile>> fetchAllFaculty() async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client
          .from('profiles')
          .select('*, teachers(*)')
          .eq('role', 'teacher')
          .order('created_at', ascending: true);

      final list = res as List;
      if (list.isNotEmpty) {
        return list.map((row) {
          final m = row as Map<String, dynamic>;
          final teacherData = _extractTeacherData(m['teachers']);
          return _mapToTeacherProfile(m, teacherData);
        }).toList();
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch all faculty notice: $e');
    }
    return [];
  }

  TeacherProfile _mapToTeacherProfile(Map<String, dynamic> prof, Map<String, dynamic>? teacher) {
    final firstName = prof['first_name']?.toString() ?? '';
    final lastName = prof['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final rawStudentId = prof['student_id']?.toString() ?? '';

    // Format into standard KMC faculty code (e.g. KMC-FAC-014 or KMC-FAC-004)
    String facultyCode = rawStudentId;
    if (rawStudentId.startsWith('KMC-2026-')) {
      final suffix = rawStudentId.replaceFirst('KMC-2026-', '');
      facultyCode = 'KMC-FAC-$suffix';
    } else if (facultyCode.isEmpty && prof['id'] != null) {
      final idStr = prof['id'].toString();
      facultyCode = 'KMC-FAC-${idStr.length >= 4 ? idStr.substring(0, 4).toUpperCase() : "001"}';
    }

    final email = prof['email']?.toString() ?? '';
    final phone = prof['phone']?.toString() ?? '';
    final teacherTableId = teacher?['id']?.toString() ?? '';

    List<String> instruments = [];
    if (teacher != null && teacher['instruments'] != null) {
      final raw = teacher['instruments'];
      if (raw is List) {
        instruments = raw.map((i) => i.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        instruments = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    final hourlyRate = (teacher?['hourly_rate'] as num?)?.toDouble() ?? 0.0;
    final rating = (teacher?['rating'] as num?)?.toDouble() ?? 0.0;
    final isActive = teacher?['is_active'] != false;

    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : 'FC';

    List<String> availableDays = [];
    if (teacher != null && teacher['available_days'] != null) {
      final rawDays = teacher['available_days'];
      if (rawDays is List) {
        availableDays = rawDays.map((d) => _normalizeDayName(d.toString())).toList();
      }
    }

    final assignedStudio = teacher?['assigned_studio']?.toString() ??
        (prof['studio']?.toString() ?? '');
    final department = teacher?['department']?.toString() ??
        (prof['department']?.toString() ?? 'Faculty of Music');

    return TeacherProfile(
      id: prof['id']?.toString() ?? '',
      teacherTableId: teacherTableId,
      name: fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : 'Faculty Instructor'),
      title: instruments.isNotEmpty ? 'Instructor of ${instruments.first}' : 'Faculty Instructor',
      facultyId: facultyCode,
      department: department,
      email: email,
      phone: phone,
      studio: assignedStudio,
      status: isActive ? '🟢 Available & In Studio' : '🟡 On Leave',
      avatarInitials: initials,
      hourlyRate: hourlyRate,
      rating: rating,
      instruments: instruments,
      availableDays: availableDays,
    );
  }

  String _normalizeDayName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('mon')) return 'Mon';
    if (lower.startsWith('tue')) return 'Tue';
    if (lower.startsWith('wed')) return 'Wed';
    if (lower.startsWith('thu')) return 'Thu';
    if (lower.startsWith('fri')) return 'Fri';
    if (lower.startsWith('sat')) return 'Sat';
    if (lower.startsWith('sun')) return 'Sun';
    return raw.trim();
  }

  /// Resolves the canonical `public.teachers(id)` primary key UUID for a teacher
  Future<String?> _resolveTeacherTableId([String? candidateId]) async {
    final client = _client;
    if (client == null) return null;

    final cachedTableId = _activeTeacher?.teacherTableId.trim() ?? '';
    if (_isUuid(cachedTableId)) return cachedTableId;

    final searchIds = <String>{
      if (candidateId != null && _isUuid(candidateId.trim())) candidateId.trim(),
      if (_activeTeacher != null && _isUuid(_activeTeacher!.id.trim())) _activeTeacher!.id.trim(),
      if (client.auth.currentUser != null && _isUuid(client.auth.currentUser!.id))
        client.auth.currentUser!.id,
    };

    for (final id in searchIds) {
      try {
        final tRow = await client
            .from('teachers')
            .select('id')
            .or('id.eq.$id,profile_id.eq.$id')
            .maybeSingle();
        final resolved = tRow?['id']?.toString().trim();
        if (_isUuid(resolved)) {
          return resolved;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Unified relational student resolution shared between Dashboard KPIs and My Students Roster.
  /// Resolves both `profileId` (`profiles.id`) and `teacherTableId` (`teachers.id`) + `specializations`,
  /// collecting student UUIDs from:
  /// a) `live_sessions` where `teacher_id` is in `idCandidates`
  /// b) `enrollments` where `course_id` is in courses assigned to this teacher
  ///    (`courses.instructor_id` in `idCandidates`, OR where `courses.instructor_id == null`
  ///    and `courses.instrument` matches `specialization`).
  Future<Map<String, dynamic>> _resolveAssignedStudentsData(TeacherProfile teacher) async {
    final client = _client;
    if (client == null) {
      return {
        'idCandidates': <String>[],
        'teacherSessions': <dynamic>[],
        'teacherCourses': <Map<String, dynamic>>[],
        'teacherEnrollments': <dynamic>[],
        'assignedStudentIds': <String>{},
      };
    }

    String teacherTableId = teacher.teacherTableId.trim();
    String teacherProfileId = teacher.id.trim();
    List<String> specializations = List<String>.from(teacher.instruments);

    if ((teacherTableId.isEmpty || specializations.isEmpty) &&
        (teacherProfileId.isNotEmpty || teacherTableId.isNotEmpty)) {
      try {
        final lookupId = teacherProfileId.isNotEmpty ? teacherProfileId : teacherTableId;
        if (_isUuid(lookupId)) {
          final tRow = await client
              .from('teachers')
              .select('id, profile_id, instruments')
              .or('id.eq.$lookupId,profile_id.eq.$lookupId')
              .maybeSingle();
          if (tRow != null) {
            if (teacherTableId.isEmpty && tRow['id'] != null) {
              teacherTableId = tRow['id'].toString().trim();
            }
            if (teacherProfileId.isEmpty && tRow['profile_id'] != null) {
              teacherProfileId = tRow['profile_id'].toString().trim();
            }
            if (specializations.isEmpty && tRow['instruments'] != null) {
              final rawInst = tRow['instruments'];
              if (rawInst is List) {
                specializations = rawInst.map((e) => e.toString()).toList();
              } else if (rawInst is String && rawInst.isNotEmpty) {
                specializations = rawInst
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              }
            }
          }
        }
      } catch (_) {}
    }

    final idCandidates = <String>{
      if (_isUuid(teacherTableId)) teacherTableId,
      if (_isUuid(teacherProfileId)) teacherProfileId,
    }.toList();

    // a) Collect sessions & student UUIDs from live_sessions where teacher_id is in idCandidates
    List<dynamic> teacherSessions = [];
    if (idCandidates.isNotEmpty) {
      try {
        final orFilter = idCandidates.map((tid) => 'teacher_id.eq.$tid').join(',');
        final sRes = await client
            .from('live_sessions')
            .select('id, teacher_id, student_id, course_id, scheduled_at, status, instructor_notes, agora_channel_name, jitsi_room_name, courses(title, instrument)')
            .or(orFilter)
            .order('scheduled_at', ascending: false);
        teacherSessions = _safeList(sRes);
      } catch (se) {
        debugPrint('[TeacherApp] Sessions query note: $se');
      }
    }

    // b) Collect courses assigned to this teacher (instructor_id in idCandidates, OR instructor_id == null & instrument matches specialization)
    final teacherCourses = <Map<String, dynamic>>[];
    try {
      final cRes = await client
          .from('courses')
          .select('id, title, instrument, instructor_id');
      for (final rawCourse in _safeList(cRes)) {
        final c = _safeMap(rawCourse);
        final instId = c['instructor_id']?.toString().trim() ?? '';
        final courseInstrument = (c['instrument']?.toString() ?? '').trim().toLowerCase();
        final courseTitle = (c['title']?.toString() ?? '').trim().toLowerCase();

        final bool matchedByInstructorId = instId.isNotEmpty && idCandidates.contains(instId);
        final bool matchedBySpecialization = instId.isEmpty &&
            specializations.any((spec) {
              final cleanSpec = spec.trim().toLowerCase();
              if (cleanSpec.isEmpty) return false;
              final firstWord = cleanSpec.split(' ').first;
              return (courseInstrument.isNotEmpty &&
                      (courseInstrument.contains(cleanSpec) ||
                          cleanSpec.contains(courseInstrument) ||
                          (firstWord.isNotEmpty && courseInstrument.contains(firstWord)))) ||
                  (firstWord.isNotEmpty && courseTitle.contains(firstWord));
            });

        if (matchedByInstructorId || matchedBySpecialization) {
          teacherCourses.add(c);
        }
      }
    } catch (ce) {
      debugPrint('[TeacherApp] Courses query note: $ce');
    }

    final courseIds = teacherCourses
        .map((c) => c['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    List<dynamic> teacherEnrollments = [];
    if (courseIds.isNotEmpty) {
      try {
        final enRes = await client
            .from('enrollments')
            .select('id, student_id, course_id, item_title, status, created_at')
            .inFilter('course_id', courseIds);
        teacherEnrollments = _safeList(enRes);
      } catch (ee) {
        debugPrint('[TeacherApp] Enrollments query note: $ee');
      }
    }

    final assignedStudentIds = <String>{};
    for (final s in teacherSessions) {
      final sid = _safeMap(s)['student_id']?.toString().trim() ?? '';
      if (_isUuid(sid)) assignedStudentIds.add(sid);
    }
    for (final e in teacherEnrollments) {
      final sid = _safeMap(e)['student_id']?.toString().trim() ?? '';
      if (_isUuid(sid)) assignedStudentIds.add(sid);
    }

    return {
      'idCandidates': idCandidates,
      'teacherSessions': teacherSessions,
      'teacherCourses': teacherCourses,
      'teacherEnrollments': teacherEnrollments,
      'assignedStudentIds': assignedStudentIds,
    };
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD METRICS (COMPUTED LIVE DIRECTLY FROM DATABASE)
  // ---------------------------------------------------------------------------

  /// Dynamically computes active student count, classes today, pending drill reviews, and teaching hours
  Future<Map<String, dynamic>> fetchTeacherDashboardStats(TeacherProfile teacher) async {
    int activeStudents = 0;
    int classesToday = 0;
    int pendingReviews = 0;
    double teachingHours = 0.0;

    final client = _client;
    if (client != null) {
      try {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // 1 & 2. Resolve sessions and active students using the unified relational resolver
        final resolved = await _resolveAssignedStudentsData(teacher);
        final teacherSessions = resolved['teacherSessions'] as List<dynamic>;
        final assignedStudentIds = resolved['assignedStudentIds'] as Set<String>;

        for (final rawSession in teacherSessions) {
          final s = _safeMap(rawSession);
          final sched = s['scheduled_at']?.toString() ?? '';
          final parsedLocal = DateTime.tryParse(sched)?.toLocal();
          final isToday = parsedLocal != null
              ? (parsedLocal.year == now.year &&
                  parsedLocal.month == now.month &&
                  parsedLocal.day == now.day)
              : sched.startsWith(todayStr);
          if (isToday) {
            classesToday++;
          }
          if (s['status'] == 'completed') {
            teachingHours += 1.0; // 1-hour standard session
          }
        }

        activeStudents = assignedStudentIds.length;

        // 3. Pending drill submissions: verified_by_teacher == null and (is_completed == true or student_submission_url != null)
        final drillsRes = await client
            .from('student_checklist_progress')
            .select('*')
            .isFilter('verified_by_teacher', null);
        for (final rawDrill in _safeList(drillsRes)) {
          final d = _safeMap(rawDrill);
          final feedbackText = (d['teacher_notes'] ?? d['teacher_feedback'])?.toString().trim() ?? '';
          if (feedbackText.isNotEmpty) continue;
          final isCompleted = d['is_completed'] == true;
          final submissionUrl = (d['student_submission_url'] ?? d['media_url'])?.toString().trim() ?? '';
          if (isCompleted || submissionUrl.isNotEmpty) {
            pendingReviews++;
          }
        }
      } catch (e) {
        debugPrint('[TeacherApp] Fetch dashboard stats notice: $e');
      }
    }

    return {
      'activeStudents': activeStudents,
      'classesToday': classesToday,
      'pendingReviews': pendingReviews,
      'teachingHours': teachingHours,
    };
  }

  // ---------------------------------------------------------------------------
  // STUDIO TIMETABLE & SESSIONS
  // ---------------------------------------------------------------------------

  AttendanceState _mapSessionStatus(String? status, [bool attendanceMarked = false, String? notes]) {
    switch (status?.toLowerCase().trim()) {
      case 'completed':
      case 'present':
        return AttendanceState.present;
      case 'cancelled':
      case 'absent':
        return AttendanceState.absent;
      case 'excused':
        return AttendanceState.excused;
      default:
        if (notes != null && notes.contains('[Attendance: EXCUSED]')) {
          return AttendanceState.excused;
        }
        return AttendanceState.unmarked;
    }
  }

  /// Fetch studio schedule for the selected day from live_sessions table
  Future<List<TeacherClass>> fetchTeacherSchedule(TeacherProfile teacher, DateTime date) async {
    final client = _client;
    if (client == null) return [];

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final teacherIds = <String>[];
      if (teacher.id.isNotEmpty) teacherIds.add(teacher.id);
      if (teacher.teacherTableId.isNotEmpty && teacher.teacherTableId != teacher.id) {
        teacherIds.add(teacher.teacherTableId);
      }

      final query = client.from('live_sessions').select('*, profiles(*), courses(*)');
      final dynamic res;
      if (teacherIds.isNotEmpty) {
        final orFilter = teacherIds.map((tid) => 'teacher_id.eq.$tid').join(',');
        res = await query.or(orFilter).order('scheduled_at', ascending: true);
      } else {
        res = await query.order('scheduled_at', ascending: true);
      }

      final list = res as List;
      final dayMatches = <TeacherClass>[];

      for (final row in list) {
        final m = row as Map<String, dynamic>;
        final schedAt = m['scheduled_at']?.toString() ?? '';
        final prof = _safeMap(m['profiles']);
        final course = _safeMap(m['courses']);

        final studentName = "${prof['first_name'] ?? ''} ${prof['last_name'] ?? ''}".trim();
        final courseTitle = course['title']?.toString() ?? (m['course_id'] != null ? 'Music Performance' : 'Studio Session');
        final studioRoom = m['studio_name']?.toString() ??
            (m['jitsi_room_name']?.toString() ?? (teacher.studio.isNotEmpty ? teacher.studio : 'Assigned Studio'));
        final statusStr = m['status']?.toString() ?? 'scheduled';
        final notes = m['instructor_notes']?.toString() ?? '';

        final AttendanceState state = _mapSessionStatus(
          statusStr,
          m['attendance_marked'] == true,
          notes,
        );

        final sessionDate = DateTime.tryParse(schedAt)?.toLocal();
        String timeFormatted = '10:00 AM';
        if (sessionDate != null) {
          final hour = sessionDate.hour;
          final minute = sessionDate.minute.toString().padLeft(2, '0');
          final period = hour >= 12 ? 'PM' : 'AM';
          final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          timeFormatted = '$h12:$minute $period';
        } else if (schedAt.contains('T')) {
          timeFormatted = schedAt.split('T')[1].substring(0, 5);
        }

        final profId = prof['id']?.toString() ?? m['student_id']?.toString() ?? '';
        final studentAdmissionId = prof['student_id']?.toString() ??
            (profId.length >= 6 ? 'KMC-${profId.substring(0, 6).toUpperCase()}' : '');

        final tc = TeacherClass(
          id: m['id']?.toString() ?? '',
          courseName: courseTitle,
          level: course['level']?.toString() ?? '',
          studentName: studentName.isNotEmpty ? studentName : (prof['email']?.toString() ?? 'Enrolled Student'),
          studentId: studentAdmissionId,
          studentProfileId: profId,
          studentPhone: prof['phone']?.toString() ?? '',
          studentEmail: prof['email']?.toString() ?? '',
          timeSlot: '$timeFormatted – 1 hour',
          studio: studioRoom,
          topic: notes.isNotEmpty ? notes : (courseTitle.isNotEmpty ? courseTitle : 'Scheduled Session'),
          notes: notes,
          attendance: state,
          isLiveNow: statusStr == 'live',
          agoraChannelName: m['agora_channel_name']?.toString() ?? '',
          agoraToken: m['agora_token']?.toString() ?? '',
        );

        final matchesDay = sessionDate != null
            ? (sessionDate.year == date.year && sessionDate.month == date.month && sessionDate.day == date.day)
            : schedAt.startsWith(dateStr);

        if (matchesDay) {
          dayMatches.add(tc);
        }
      }

      // Return ONLY the sessions that belong to the queried date
      return dayMatches;
    } catch (e) {
      debugPrint('[TeacherApp] Fetch schedule notice: $e');
    }

    return [];
  }

  /// Mark attendance in Central Mind live_sessions table
  Future<bool> updateSessionAttendance(String sessionId, AttendanceState state) async {
    final client = _client;
    if (client == null || sessionId.isEmpty) return false;

    String statusValue = 'scheduled';
    bool attendanceMarked = false;
    switch (state) {
      case AttendanceState.present:
        statusValue = 'completed';
        attendanceMarked = true;
        break;
      case AttendanceState.absent:
        statusValue = 'cancelled';
        attendanceMarked = true;
        break;
      case AttendanceState.excused:
        statusValue = 'excused';
        attendanceMarked = true;
        break;
      case AttendanceState.unmarked:
        statusValue = 'scheduled';
        attendanceMarked = false;
        break;
    }

    try {
      await client.from('live_sessions').update({
        'status': statusValue,
      }).eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Update attendance primary notice ($attendanceMarked): $e');
      if (state == AttendanceState.excused) {
        try {
          await saveSessionNote(sessionId, '[Attendance: EXCUSED]');
          return true;
        } catch (_) {}
      }
      return false;
    }
  }

  Future<bool> updateAttendance(String sessionId, AttendanceState state) =>
      updateSessionAttendance(sessionId, state);

  /// Save teacher notes for a studio session while preserving Director proctor or assignment metadata
  Future<bool> saveSessionNote(String sessionId, String notes) async {
    final client = _client;
    if (client == null || sessionId.isEmpty) return false;

    try {
      String finalNotes = notes.trim();
      try {
        final existingRow = await client
            .from('live_sessions')
            .select('instructor_notes')
            .eq('id', sessionId)
            .maybeSingle();
        final existingNotes = existingRow?['instructor_notes']?.toString().trim() ?? '';
        if (existingNotes.isNotEmpty &&
            (existingNotes.contains('[Proctor:') || existingNotes.contains('Assigned to faculty'))) {
          final preservedParts = <String>[];
          for (final part in existingNotes.split(RegExp(r'\s*\|\s*|\n'))) {
            final trimmedPart = part.trim();
            if (trimmedPart.contains('[Proctor:') || trimmedPart.contains('Assigned to faculty')) {
              preservedParts.add(trimmedPart);
            }
          }
          if (preservedParts.isNotEmpty) {
            final preservedPrefix = preservedParts.join(' | ');
            if (!finalNotes.contains(preservedPrefix)) {
              finalNotes = finalNotes.isEmpty
                  ? preservedPrefix
                  : '$preservedPrefix | Lesson Note: $finalNotes';
            }
          }
        }
      } catch (_) {}

      await client.from('live_sessions').update({
        'instructor_notes': finalNotes,
      }).eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Save note notice: $e');
      return false;
    }
  }

  Future<bool> updateSessionLessonNote(String sessionId, String lessonNote) =>
      saveSessionNote(sessionId, lessonNote);

  // ---------------------------------------------------------------------------
  // ASSIGNED STUDENTS ROSTER
  // ---------------------------------------------------------------------------

  /// Fetch genuine students assigned to this teacher from Central Mind (Supabase).
  /// Uses the unified `_resolveAssignedStudentsData` resolver so Dashboard KPIs
  /// and the My Students Roster match 100%.
  Future<List<StudentRosterItem>> fetchAssignedStudents(TeacherProfile teacher) async {
    final client = _client;
    if (client == null) return [];

    try {
      final resolved = await _resolveAssignedStudentsData(teacher);
      final teacherSessions = resolved['teacherSessions'] as List<dynamic>;
      final teacherCourses = resolved['teacherCourses'] as List<Map<String, dynamic>>;
      final teacherEnrollments = resolved['teacherEnrollments'] as List<dynamic>;
      final assignedStudentIds = resolved['assignedStudentIds'] as Set<String>;

      // If no students assigned to this teacher yet, return empty list (no phantom mock students)
      if (assignedStudentIds.isEmpty) {
        return [];
      }

      final coursesById = <String, Map<String, dynamic>>{};
      for (final c in teacherCourses) {
        final cid = c['id']?.toString() ?? '';
        if (cid.isNotEmpty) coursesById[cid] = c;
      }

      // Fetch profiles for assigned students
      final pRes = await client
          .from('profiles')
          .select('id, student_id, first_name, last_name, email, phone, is_verified, created_at, enrollments(*)')
          .inFilter('id', assignedStudentIds.toList())
          .order('created_at', ascending: false);

      final profileList = _safeList(pRes);
      final students = <StudentRosterItem>[];

      for (final row in profileList) {
        final m = _safeMap(row);
        final studentProfileId = m['id']?.toString() ?? '';
        final firstName = m['first_name']?.toString() ?? '';
        final lastName = m['last_name']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        final studentAdmissionId = m['student_id']?.toString() ??
            'KMC-2026-${studentProfileId.length >= 4 ? studentProfileId.substring(0, 4).toUpperCase() : "1001"}';
        final phone = m['phone']?.toString() ?? '';
        final email = m['email']?.toString() ?? '';

        // Sessions for this student
        final studentSessions = teacherSessions
            .where((s) => _safeMap(s)['student_id']?.toString() == studentProfileId)
            .toList();

        // Real attendance calculation from live_sessions
        int completedSessions = 0;
        int cancelledSessions = 0;
        DateTime? nextScheduledDate;
        String latestNote = '';

        final now = DateTime.now();
        for (final s in studentSessions) {
          final sm = _safeMap(s);
          final status = sm['status']?.toString().toLowerCase() ?? '';
          if (status == 'completed') completedSessions++;
          if (status == 'cancelled') cancelledSessions++;

          final schedStr = sm['scheduled_at']?.toString() ?? '';
          final schedDate = DateTime.tryParse(schedStr)?.toLocal();
          if (status == 'scheduled' && schedDate != null && schedDate.isAfter(now)) {
            if (nextScheduledDate == null || schedDate.isBefore(nextScheduledDate)) {
              nextScheduledDate = schedDate;
            }
          }

          final note = sm['instructor_notes']?.toString().trim() ?? '';
          if (latestNote.isEmpty && note.isNotEmpty) {
            latestNote = note;
          }
        }

        final totalConcluded = completedSessions + cancelledSessions;
        final int attendanceRate = totalConcluded > 0
            ? ((completedSessions / totalConcluded) * 100).round().clamp(0, 100)
            : 100;

        // Course & Instrument determination
        String courseName = teacher.instruments.isNotEmpty ? teacher.instruments.first : 'Contemporary Music';
        String instrument = teacher.instruments.isNotEmpty ? teacher.instruments.first : 'Piano';

        // Check if student has session with course title
        bool resolvedCourseFromSession = false;
        for (final s in studentSessions) {
          final sm = _safeMap(s);
          final cMap = sm['courses'] as Map<String, dynamic>?;
          if (cMap != null) {
            final t = cMap['title']?.toString() ?? '';
            final inst = cMap['instrument']?.toString() ?? '';
            if (t.isNotEmpty) {
              courseName = t;
              resolvedCourseFromSession = true;
            }
            if (inst.isNotEmpty) instrument = inst;
            if (resolvedCourseFromSession) break;
          }
        }

        // Fallback to student's enrollment in this teacher's courses
        if (!resolvedCourseFromSession) {
          for (final rawEn in teacherEnrollments) {
            final em = _safeMap(rawEn);
            if (em['student_id']?.toString() == studentProfileId) {
              final cid = em['course_id']?.toString() ?? '';
              final courseMap = coursesById[cid];
              final t = courseMap?['title']?.toString() ?? em['item_title']?.toString() ?? '';
              final inst = courseMap?['instrument']?.toString() ?? '';
              if (t.isNotEmpty) courseName = t;
              if (inst.isNotEmpty) instrument = inst;
              break;
            }
          }
        }

        // Format next class string dynamically
        String nextClassStr = 'No upcoming session scheduled';
        if (nextScheduledDate != null) {
          final isToday = nextScheduledDate.year == now.year &&
              nextScheduledDate.month == now.month &&
              nextScheduledDate.day == now.day;
          final isTomorrow = nextScheduledDate.year == now.year &&
              nextScheduledDate.month == now.month &&
              nextScheduledDate.day == (now.day + 1);

          final hour = nextScheduledDate.hour;
          final minute = nextScheduledDate.minute.toString().padLeft(2, '0');
          final period = hour >= 12 ? 'PM' : 'AM';
          final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final timeStr = '$h12:$minute $period';

          if (isToday) {
            nextClassStr = 'Today @ $timeStr';
          } else if (isTomorrow) {
            nextClassStr = 'Tomorrow @ $timeStr';
          } else {
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            nextClassStr = '${months[nextScheduledDate.month - 1]} ${nextScheduledDate.day} @ $timeStr';
          }
        }

        // Progress calculation based on completed sessions against total booked sessions
        final totalEnrolledSessions = studentSessions.isNotEmpty ? studentSessions.length : 1;
        final double progress = completedSessions > 0
            ? (completedSessions / totalEnrolledSessions).clamp(0.0, 1.0)
            : 0.0;

        students.add(StudentRosterItem(
          id: studentProfileId,
          name: fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : 'KMC Student'),
          studentId: studentAdmissionId,
          course: courseName,
          instrument: instrument,
          phone: phone,
          email: email,
          progressPercent: progress,
          attendancePercent: attendanceRate,
          completedLessons: completedSessions,
          nextClass: nextClassStr,
          lastLessonNote: latestNote.isNotEmpty ? latestNote : 'No instructor notes recorded yet.',
        ));
      }

      return students;
    } catch (e) {
      debugPrint('[TeacherApp] Fetch assigned students notice: $e');
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // STUDENT PRACTICE DRILL SUBMISSIONS
  // ---------------------------------------------------------------------------

  /// Fetch student drill submissions from student_checklist_progress
  Future<List<StudentSubmission>> fetchStudentSubmissions(TeacherProfile teacher) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client
          .from('student_checklist_progress')
          .select('*, profiles(*), practice_checklists(*, lessons(*))')
          .order('updated_at', ascending: false);

      final list = res as List;
      final subs = <StudentSubmission>[];

      for (final row in list) {
        final m = row as Map<String, dynamic>;
        final prof = _safeMap(m['profiles']);
        final chk = _safeMap(m['practice_checklists']);
        final lesson = _safeMap(chk['lessons']);

        final studentName = "${prof['first_name'] ?? ''} ${prof['last_name'] ?? ''}".trim();
        final profId = prof['id']?.toString() ?? m['student_id']?.toString() ?? '';
        final studentId = prof['student_id']?.toString() ??
            (profId.length >= 6 ? 'KMC-${profId.substring(0, 6).toUpperCase()}' : '');
        final drillTitle = chk['task_title']?.toString() ?? 'Practice Routine';
        final courseTitle = lesson['title']?.toString() ?? 'Masterclass Drill';
        final isCompleted = m['is_completed'] == true;

        final rawFeedback = (m['teacher_notes'] ?? m['teacher_feedback'])?.toString().trim() ?? '';
        final isReviewed = m['verified_by_teacher'] != null || rawFeedback.isNotEmpty;

        final mediaUrl = (m['media_url'] ?? m['student_submission_url'])?.toString();

        // Skip rows that have not been completed/submitted by the student and have not been reviewed
        if (!isReviewed && !isCompleted && (mediaUrl == null || mediaUrl.trim().isEmpty)) {
          continue;
        }

        double? ratingVal = (m['rating'] as num?)?.toDouble();
        String cleanFeedback = rawFeedback;
        if (rawFeedback.startsWith('[Rating:')) {
          final endBracket = rawFeedback.indexOf(']');
          if (endBracket != -1) {
            final ratingHeader = rawFeedback.substring(0, endBracket + 1);
            final numMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*\/\s*5\.0').firstMatch(ratingHeader);
            if (numMatch != null) {
              ratingVal ??= double.tryParse(numMatch.group(1)!);
            }
            cleanFeedback = rawFeedback.substring(endBracket + 1).trim();
          }
        }

        final createdAtStr = m['created_at']?.toString() ?? m['updated_at']?.toString() ?? '';
        final createdDt = DateTime.tryParse(createdAtStr)?.toLocal();
        String formattedSubmittedTime = 'Recent Take';
        if (createdDt != null) {
          final now = DateTime.now();
          final isToday = createdDt.year == now.year && createdDt.month == now.month && createdDt.day == now.day;
          final hour = createdDt.hour;
          final minute = createdDt.minute.toString().padLeft(2, '0');
          final period = hour >= 12 ? 'PM' : 'AM';
          final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          formattedSubmittedTime = isToday ? 'Today @ $h12:$minute $period' : '${createdDt.day}/${createdDt.month} @ $h12:$minute $period';
        }

        final rawDuration = m['duration_seconds'] ?? m['duration'];
        String formattedDuration = 'Practice Take';
        if (rawDuration != null) {
          final secs = int.tryParse(rawDuration.toString()) ?? 0;
          final mins = secs ~/ 60;
          final remSecs = secs % 60;
          formattedDuration = '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')} mins';
        }

        String mediaType = m['media_type']?.toString() ?? 'Audio';
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          final lower = mediaUrl.toLowerCase();
          if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm')) {
            mediaType = 'Video';
          } else if (lower.endsWith('.pdf')) {
            mediaType = 'Score';
          } else {
            mediaType = 'Audio';
          }
        }

        final studentNotes = m['student_notes']?.toString() ?? '';

        subs.add(StudentSubmission(
          id: m['id']?.toString() ?? '',
          studentName: studentName.isNotEmpty ? studentName : (prof['email']?.toString() ?? 'KMC Student'),
          studentId: studentId,
          courseTitle: courseTitle,
          drillTitle: drillTitle,
          submittedTime: formattedSubmittedTime,
          durationText: formattedDuration,
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          studentNotes: studentNotes,
          isReviewed: isReviewed,
          rating: ratingVal,
          teacherFeedback: cleanFeedback.isNotEmpty ? cleanFeedback : null,
        ));
      }

      if (subs.isNotEmpty) {
        return subs;
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch drill submissions notice: $e');
    }

    return [];
  }

  /// Submit drill review with rating and comments to Central Mind
  Future<bool> submitDrillReview({
    String? progressId,
    String? submissionId,
    required double rating,
    required String feedback,
    String? teacherId,
  }) async {
    final client = _client;
    final targetId = progressId ?? submissionId ?? '';
    if (client == null || targetId.isEmpty) return false;

    final teacherTableId = await _resolveTeacherTableId(teacherId);
    final cleanFeedback = feedback.trim();
    final formattedFeedback = cleanFeedback.startsWith('[Rating:')
        ? cleanFeedback
        : '[Rating: ${rating.toStringAsFixed(1)}/5.0] $cleanFeedback';

    try {
      await client.from('student_checklist_progress').update({
        'is_completed': true,
        if (teacherTableId != null && _isUuid(teacherTableId))
          'verified_by_teacher': teacherTableId,
        'teacher_notes': formattedFeedback,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', targetId);
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Submit drill review notice: $e');
      return false;
    }
  }

  /// Fetch authentic curriculum sheet music & PDF scores from Central Mind `lessons` and `store_items` tables
  Future<List<Map<String, dynamic>>> fetchCurriculumSheetMusic({
    String? teacherId,
    String? courseId,
    String? courseName,
  }) async {
    final client = _client;
    if (client == null) return [];

    final results = <Map<String, dynamic>>[];

    try {
      var query = client
          .from('lessons')
          .select('*, courses(title, instrument, instructor_id)');

      if (courseId != null && courseId.isNotEmpty && _isUuid(courseId)) {
        query = query.eq('course_id', courseId);
      }

      final res = await query.order('order_index');
      final list = _safeList(res);
      for (final rawRow in list) {
        final row = _safeMap(rawRow);
        final pdf = (row['pdf_attachment_url'] ?? row['sheet_music_url'])?.toString().trim() ?? '';
        if (pdf.isNotEmpty) {
          final course = _safeMap(row['courses']);
          final cTitle = course['title']?.toString() ?? courseName ?? 'Curriculum';
          final inst = course['instrument']?.toString() ?? 'General';
          final notes = row['notes']?.toString() ?? '';
          final lowerUrl = pdf.toLowerCase();
          final isAudio = lowerUrl.endsWith('.mp3') || lowerUrl.endsWith('.wav') || lowerUrl.endsWith('.m4a');
          results.add({
            'id': row['id']?.toString() ?? '',
            'title': row['title']?.toString() ?? 'Curriculum Sheet Music',
            'url': pdf,
            'type': isAudio ? 'MP3' : 'PDF',
            'course': cTitle,
            'category': cTitle,
            'instrument': inst,
            'size': 'Cloudflare R2',
            'notes': notes,
            'desc': notes.isNotEmpty ? notes : 'Official KMC curriculum score for $cTitle ($inst).',
          });
        }
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch curriculum lessons sheet music notice: $e');
    }

    try {
      final storeRes = await client
          .from('store_items')
          .select('id, title, category, description, author_or_brand, file_url')
          .not('file_url', 'is', null)
          .neq('file_url', '');
      for (final rawRow in _safeList(storeRes)) {
        final m = _safeMap(rawRow);
        final fileUrl = m['file_url']?.toString().trim() ?? '';
        if (fileUrl.isNotEmpty) {
          final lowerUrl = fileUrl.toLowerCase();
          final isAudio = lowerUrl.endsWith('.mp3') || lowerUrl.endsWith('.wav') || lowerUrl.endsWith('.m4a');
          final category = m['category']?.toString() ?? 'Digital Resource';
          final desc = m['description']?.toString() ?? '';
          results.add({
            'id': m['id']?.toString() ?? '',
            'title': m['title']?.toString() ?? 'Faculty Resource',
            'url': fileUrl,
            'type': isAudio ? 'MP3' : 'PDF',
            'course': category,
            'category': category,
            'instrument': m['author_or_brand']?.toString() ?? 'General',
            'size': 'Cloudflare R2',
            'notes': desc,
            'desc': desc.isNotEmpty ? desc : 'Digital publication from KMC Resource Library.',
          });
        }
      }
    } catch (e) {
      debugPrint('[TeacherApp] Fetch store_items sheet music notice: $e');
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // STUDENT COMMUNICATION & MULTI-CHANNEL SHARE (IN-APP, WHATSAPP, EMAIL)
  // ---------------------------------------------------------------------------

  /// Dispatch an in-app notification to a student via Central Mind notifications table
  Future<bool> sendStudentNotification({
    required String studentId,
    String? studentName,
    String? teacherId,
    String? teacherName,
    required String title,
    required String message,
    String category = 'instruction',
  }) async {
    final client = _client;
    if (client == null) return false;

    final tId = teacherId ?? _activeTeacher?.id ?? 'faculty';
    final tName = teacherName ?? _activeTeacher?.name ?? 'Faculty Instructor';
    final sName = studentName ?? 'Student';

    try {
      await client.from('notifications').insert({
        'sender_id': tId,
        'sender_name': tName,
        'sender_role': 'teacher',
        'recipient_type': 'individual_student',
        'recipient_id': studentId,
        'recipient_name': sName,
        'title': title,
        'message': message,
        'category': category.toLowerCase(),
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Send student notification notice: $e');
      return false;
    }
  }

  /// Launch WhatsApp with pre-formatted message directly to student
  Future<bool> launchWhatsApp(
    String phone, [
    String message = '',
  ]) async {
    return launchWhatsAppNamed(phone: phone, message: message);
  }

  Future<bool> launchWhatsAppNamed({
    required String phone,
    required String message,
  }) async {
    // Sanitize phone number to international format without spaces/dashes
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    if (!cleanPhone.startsWith('254') && cleanPhone.length == 9) {
      cleanPhone = '254$cleanPhone';
    }

    final encodedMsg = Uri.encodeComponent(message);
    final urlString = 'https://wa.me/$cleanPhone?text=$encodedMsg';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[TeacherApp] WhatsApp launch notice: $e');
    }
    return false;
  }

  /// Launch email client with pre-formatted subject and body
  Future<bool> launchEmail(
    String email, [
    String subject = '',
    String body = '',
  ]) async {
    return launchEmailNamed(email: email, subject: subject, body: body);
  }

  Future<bool> launchEmailNamed({
    required String email,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[TeacherApp] Email launch notice: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // PROFILE & AVAILABILITY SETTINGS
  // ---------------------------------------------------------------------------

  /// Update teacher availability days in Central Mind
  Future<bool> updateTeacherAvailability(String teacherId, List<String> days) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('teachers').update({
        'available_days': days,
      }).or('id.eq.$teacherId,profile_id.eq.$teacherId');
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Update availability notice: $e');
      return false;
    }
  }



  /// Schedule a new 1-on-1 Studio Session directly from the Teacher Portal
  Future<bool> scheduleStudioSession({
    required String teacherId,
    required String studentId,
    String? studentAdmissionId,
    String? studentName,
    String? courseId,
    required DateTime scheduledAt,
    required String studioRoom,
    required String topic,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final resolvedTeacherTableId = await _resolveTeacherTableId(teacherId) ?? teacherId;
      if (!_isUuid(resolvedTeacherTableId)) {
        debugPrint('[TeacherApp] Schedule session error: could not resolve valid teachers.id UUID.');
        return false;
      }

      final roomSlug = KmcChannelHelper.sanitize(studioRoom);
      // NOTE: live_sessions has no agora_token column. Tokens are minted on-device
      // at join time for the canonical channel, so we never persist them.
      await client.from('live_sessions').insert({
        'teacher_id': resolvedTeacherTableId,
        'student_id': studentId,
        if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'agora_channel_name': roomSlug,
        'jitsi_room_name': studioRoom,
        'status': 'scheduled',
        'instructor_notes': topic,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Dispatch direct real-time notification to the student
      try {
        final teacherName = _activeTeacher?.name ?? 'KMC Faculty Master';
        final formattedDate = '${scheduledAt.day}/${scheduledAt.month} @ ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
        await client.from('notifications').insert({
          'sender_name': teacherName,
          'sender_role': 'teacher',
          'recipient_type': 'individual_student',
          'recipient_id': studentId,
          'recipient_name': studentName,
          'secondary_recipient_id': studentAdmissionId,
          'title': 'Studio Lesson Scheduled: $topic',
          'message': 'Your 1-on-1 session in $studioRoom with $teacherName has been booked for $formattedDate.',
          'category': 'lesson',
          'action_url': '/live-classroom',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (notifErr) {
        debugPrint('[TeacherApp] Notice dispatch warning: $notifErr');
      }

      return true;
    } catch (e) {
      debugPrint('[TeacherApp] Schedule session notice: $e');
      return false;
    }
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

  /// Broadcast "Live Now" to Central Mind live_sessions and push real-time alert to students.
  ///
  /// Returns the id of the `live_sessions` row that is now `live` (so the caller can
  /// mark exactly that row `completed` later), or `null` if the database write failed.
  Future<String?> startLiveBroadcast({
    required String sessionId,
    required String studioRoom,
    required String topic,
    String? studentId,
    String? studentProfileId,
    String? studentName,
  }) async {
    final client = _client;
    if (client == null) return null;

    String? liveRowId;
    final teacherName = _activeTeacher?.name ?? 'KMC Faculty Master';
    final roomSlug = KmcChannelHelper.sanitize(studioRoom);

    try {
      // 1. Flip an existing scheduled row to live. Only real UUID rows can match;
      //    local schedule ids (e.g. 'tc_101') would make Postgres reject the filter.
      if (_isUuid(sessionId)) {
        final updated = await client
            .from('live_sessions')
            .update({
              'status': 'live',
              'agora_channel_name': roomSlug,
              'jitsi_room_name': studioRoom,
            })
            .eq('id', sessionId)
            .select('id');
        if ((updated as List).isNotEmpty) {
          liveRowId = updated.first['id']?.toString();
        }
      }

      // 2. Ad-hoc studio session (or the update matched nothing): insert a fresh live row.
      if (liveRowId == null) {
        final teacherTableId = await _resolveTeacherTableId(_activeTeacher?.teacherTableId);
        if (teacherTableId == null || !_isUuid(teacherTableId)) {
          debugPrint('[TeacherApp] Start live broadcast error: could not resolve valid teachers.id for active faculty.');
          return null;
        }
        // student_id is a UUID FK to profiles; admission numbers like 'KMC-2026-1042'
        // would fail the insert, so they fall back to an open (student_id = null) room.
        final targetStudentId = _isUuid(studentProfileId)
            ? studentProfileId
            : (_isUuid(studentId) ? studentId : null);

        final inserted = await client
            .from('live_sessions')
            .insert({
              'teacher_id': teacherTableId,
              'student_id': targetStudentId,
              'scheduled_at': DateTime.now().toUtc().toIso8601String(),
              'agora_channel_name': roomSlug,
              'jitsi_room_name': studioRoom,
              'status': 'live',
              'instructor_notes': topic.isNotEmpty ? topic : 'Live Masterclass Practice Lab',
            })
            .select('id')
            .single();
        liveRowId = inserted['id']?.toString();
      }
      debugPrint('[TeacherApp] Live broadcast row $liveRowId is LIVE on channel $roomSlug');
    } catch (e) {
      debugPrint('[TeacherApp] Start live broadcast DB error: $e');
      return null;
    }

    // 3. Notification is best-effort: a failure here must not hide a successful live row.
    try {
      final isOpenMasterclass = !_isUuid(studentProfileId) && !_isUuid(studentId);

      // Dispatch real-time live alert into notifications table
      await client.from('notifications').insert({
        'sender_name': teacherName,
        'sender_role': 'teacher',
        'recipient_type': isOpenMasterclass ? 'all_students' : 'individual_student',
        'recipient_id': isOpenMasterclass
            ? null
            : (_isUuid(studentProfileId) ? studentProfileId : studentId),
        'recipient_name': studentName,
        'secondary_recipient_id': isOpenMasterclass ? null : studentId,
        'title': '🔴 LIVE NOW: $teacherName in $studioRoom',
        'message': 'Masterclass "$topic" is now streaming live in $studioRoom. Tap to join the live studio!',
        'category': 'masterclass',
        'action_url': '/live-classroom',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[TeacherApp] Live alert notification warning: $e');
    }

    return liveRowId;
  }

  /// Mark live session as completed when teacher concludes masterclass
  Future<bool> endLiveBroadcast({required String sessionId}) async {
    final client = _client;
    if (client == null) return false;

    try {
      if (_isUuid(sessionId)) {
        await client.from('live_sessions').update({
          'status': 'completed',
        }).eq('id', sessionId);
      }
      return true;
    } catch (e) {
      debugPrint('[TeacherApp] End live broadcast error: $e');
      return false;
    }
  }
}

/// Result object for authentication actions
class AuthResult {
  final bool isSuccess;
  final TeacherProfile? teacher;
  final String? errorMessage;

  const AuthResult._({required this.isSuccess, this.teacher, this.errorMessage});

  factory AuthResult.success(TeacherProfile teacher) =>
      AuthResult._(isSuccess: true, teacher: teacher);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
