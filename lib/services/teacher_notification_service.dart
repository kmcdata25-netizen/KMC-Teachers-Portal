import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service managing native Android notifications for KMC Faculty & Teachers.
/// Listens to real-time broadcasts and targeted memos dispatched by the Admin Suite.
class TeacherNotificationService {
  TeacherNotificationService._internal();
  static final TeacherNotificationService instance =
      TeacherNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Timer? _pollerTimer;
  RealtimeChannel? _realtimeChannel;

  String? _currentTeacherId;
  String? _currentFacultyCode;

  final Set<String> _seenNoticeIds = {};
  static const String _prefsSeenKey = 'kmc_teacher_seen_notices_v1';

  final Set<String> _readNoticeIds = {};
  static const String _prefsReadKey = 'kmc_teacher_read_notices_v1';

  /// Reactive notifier for total unread notices (powers UI badges without polling)
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  List<Map<String, dynamic>> _cachedAnnouncements = [];

  /// Global callback for when a native Android notification is tapped
  void Function(String? payload)? onNotificationClicked;

  /// Android channel details for Kasarani Music Center Faculty Broadcasts
  static const String channelId = 'kmc_teacher_broadcasts';
  static const String channelName = 'KMC Faculty Announcements & Notices';
  static const String channelDescription =
      'High-priority notifications for school broadcasts, emergency notices, and administration memos.';

  /// Primary KMC brand neon green used to tint Android notifications
  static const Color kmsNotificationColor = Color(0xFF00FF66);

  /// Initializes the local notification plugin and configures notification channels.
  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTapped,
  }) async {
    if (_isInitialized) return;

    // Small icon uses the KMC piano mark in android/app/src/main/res/drawable-*/ic_notification.png
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[Teacher Notifications] Tapped notification payload: ${response.payload}');
          onNotificationTapped?.call(response);
        },
      );

      // Create the high-priority notification channel for Android 8.0+
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: kmsNotificationColor,
        );

        await androidPlugin?.createNotificationChannel(channel);
      }

      // Load previously seen notice IDs to prevent re-alerting historical notices
      await _loadSeenNoticeIds();

      _isInitialized = true;
      debugPrint('[Teacher Notifications] Initialized successfully.');
    } catch (e) {
      debugPrint('[Teacher Notifications] Initialize platform fallback: $e');
      _isInitialized = true;
    }
  }

  /// Explicitly requests POST_NOTIFICATIONS permission on Android 13+ (API 33+)
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlugin?.requestNotificationsPermission() ?? false;
        debugPrint('[Teacher Notifications] Permission granted: $granted');
        return granted;
      } else if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return granted;
      }
    } catch (e) {
      debugPrint('[Teacher Notifications] Permission request error: $e');
    }
    return true;
  }

  /// Dispatches a high-priority heads-up notification in the Android notification shade/tray.
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String? subText,
    AndroidNotificationCategory category = AndroidNotificationCategory.event,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: kmsNotificationColor,
      subText: subText ?? 'Director Office Notice',
      category: category,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: subText ?? 'KMC Faculty Notice',
        htmlFormatSummaryText: false,
      ),
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      debugPrint('[Teacher Notifications] Dispatched notification: "$title"');
    } catch (e) {
      debugPrint('[Teacher Notifications] showNotification error: $e');
    }
  }

  /// Starts listening to live broadcasts from Central Mind in real-time.
  /// Also starts a background periodic poller (15s) for guaranteed delivery.
  Future<void> startRealtimeBroadcastListener({
    String? teacherId,
    String? facultyCode,
  }) async {
    _currentTeacherId = teacherId;
    _currentFacultyCode = facultyCode;

    await initialize();
    await requestPermission();

    // 1. Initial sync & populate seen notices
    await _pollForNewBroadcasts(isInitialWarmup: true);

    // 2. Setup Supabase Realtime channel subscription
    _setupSupabaseRealtimeChannel();

    // 3. Periodic polling fallback (every 15 seconds)
    _pollerTimer?.cancel();
    _pollerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollForNewBroadcasts(isInitialWarmup: false);
    });
  }

  /// Sets up Supabase Realtime subscription on 'notifications' table
  void _setupSupabaseRealtimeChannel() {
    if (!TeacherSupabaseConfig.isInitialized) return;

    try {
      _realtimeChannel?.unsubscribe();
      final client = TeacherSupabaseConfig.client;

      _realtimeChannel = client.channel('public:teacher_notifications');
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          final newRecord = payload.newRecord;
          debugPrint('[Teacher Notifications] Realtime INSERT received: ${newRecord['title']}');
          _processIncomingNotice(newRecord, canTriggerNotification: true);
        },
      ).subscribe();

      debugPrint('[Teacher Notifications] Subscribed to Supabase notifications table in realtime.');
    } catch (e) {
      debugPrint('[Teacher Notifications] Realtime subscription error: $e');
    }
  }

  /// Polls Supabase for latest broadcasts
  Future<void> _pollForNewBroadcasts({bool isInitialWarmup = false}) async {
    if (!TeacherSupabaseConfig.isInitialized) return;

    try {
      final client = TeacherSupabaseConfig.client;
      final res = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      final list = res as List;
      for (final row in list) {
        final m = row as Map<String, dynamic>;
        _processIncomingNotice(m, canTriggerNotification: !isInitialWarmup);
      }
    } catch (e) {
      // Quietly ignore polling network glitches
    }
  }

  /// Evaluates an incoming notice record, checks targeting, and triggers an Android notification.
  Future<void> _processIncomingNotice(
    Map<String, dynamic> notice, {
    required bool canTriggerNotification,
  }) async {
    final rawId = notice['id']?.toString();
    if (rawId == null || rawId.isEmpty) return;

    // If already seen and alerted, skip
    if (_seenNoticeIds.contains(rawId)) return;

    // Check targeting
    final recipientType = notice['recipient_type']?.toString().toLowerCase() ?? 'all';
    final recipientId = notice['recipient_id']?.toString() ?? '';
    final recipientName = notice['recipient_name']?.toString() ?? '';
    final secRecipientId = notice['secondary_recipient_id']?.toString() ?? '';

    bool isForFaculty = false;

    if (recipientType == 'all' ||
        recipientType == 'everyone' ||
        recipientType == 'faculty' ||
        recipientType == 'all_faculty') {
      isForFaculty = true;
    } else if (recipientType == 'individual_teacher' ||
        recipientType == 'single' ||
        recipientType == 'teacher') {
      if (_currentTeacherId != null && _currentTeacherId!.isNotEmpty) {
        isForFaculty = (recipientId == _currentTeacherId ||
            recipientName.toLowerCase() == _currentFacultyCode?.toLowerCase());
      } else {
        isForFaculty = true;
      }
    } else if (recipientType == 'pair') {
      if (_currentTeacherId != null && _currentTeacherId!.isNotEmpty) {
        isForFaculty = (recipientId == _currentTeacherId ||
            secRecipientId == _currentTeacherId);
      } else {
        isForFaculty = true;
      }
    }

    // Always register as seen so we don't alert on next poll
    _seenNoticeIds.add(rawId);
    _saveSeenNoticeIds();

    if (!isForFaculty) return;

    if (canTriggerNotification) {
      final title = notice['title']?.toString() ?? 'Faculty Notice';
      final body = notice['message']?.toString() ?? '';
      final category = notice['category']?.toString() ?? 'Official Notice';
      final sender = notice['sender_name']?.toString() ?? 'Director Office';

      final notifId = rawId.hashCode & 0x7FFFFFFF;
      await showNotification(
        id: notifId,
        title: title,
        body: body,
        payload: rawId,
        subText: '$sender • $category',
      );
    }

    // Insert into cached announcements and refresh unread counter
    final existingIdx = _cachedAnnouncements.indexWhere((item) => item['id']?.toString() == rawId);
    final enriched = Map<String, dynamic>.from(notice);
    enriched['is_read_local'] = _readNoticeIds.contains(rawId);
    if (existingIdx != -1) {
      _cachedAnnouncements[existingIdx] = enriched;
    } else {
      _cachedAnnouncements.insert(0, enriched);
    }
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    if (_cachedAnnouncements.isEmpty) {
      unreadCountNotifier.value = 0;
      return;
    }
    final count = _cachedAnnouncements.where((m) {
      final id = m['id']?.toString() ?? '';
      return id.isNotEmpty && !_readNoticeIds.contains(id);
    }).length;
    unreadCountNotifier.value = count;
  }

  bool isNoticeRead(String id) => _readNoticeIds.contains(id);

  Future<void> markNoticeAsRead(String id) async {
    _readNoticeIds.add(id);
    await _saveReadNoticeIds();
    for (var m in _cachedAnnouncements) {
      if (m['id']?.toString() == id) {
        m['is_read_local'] = true;
      }
    }
    _updateUnreadCount();
  }

  Future<void> markAllAsRead(List<String> ids) async {
    _readNoticeIds.addAll(ids);
    await _saveReadNoticeIds();
    for (var m in _cachedAnnouncements) {
      m['is_read_local'] = true;
    }
    unreadCountNotifier.value = 0;
  }

  /// Fetches all active faculty notices, broadcasts, and administration memos.
  Future<List<Map<String, dynamic>>> fetchFacultyAnnouncements({bool forceRefresh = false}) async {
    if (!TeacherSupabaseConfig.isInitialized) return _cachedAnnouncements;

    try {
      final client = TeacherSupabaseConfig.client;
      final res = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(40);

      final list = res as List;
      final results = <Map<String, dynamic>>[];

      for (final row in list) {
        final m = Map<String, dynamic>.from(row as Map);
        final rawId = m['id']?.toString() ?? '';
        final recipientType = m['recipient_type']?.toString().toLowerCase() ?? 'all';
        final recipientId = m['recipient_id']?.toString() ?? '';
        final recipientName = m['recipient_name']?.toString() ?? '';
        final secRecipientId = m['secondary_recipient_id']?.toString() ?? '';

        bool isForFaculty = false;
        if (recipientType == 'all' ||
            recipientType == 'everyone' ||
            recipientType == 'faculty' ||
            recipientType == 'all_faculty') {
          isForFaculty = true;
        } else if (recipientType == 'individual_teacher' ||
            recipientType == 'single' ||
            recipientType == 'teacher') {
          if (_currentTeacherId != null && _currentTeacherId!.isNotEmpty) {
            isForFaculty = (recipientId == _currentTeacherId ||
                recipientName.toLowerCase() == _currentFacultyCode?.toLowerCase());
          } else {
            isForFaculty = true;
          }
        } else if (recipientType == 'pair') {
          if (_currentTeacherId != null && _currentTeacherId!.isNotEmpty) {
            isForFaculty = (recipientId == _currentTeacherId ||
                secRecipientId == _currentTeacherId);
          } else {
            isForFaculty = true;
          }
        } else {
          final cat = m['category']?.toString().toLowerCase() ?? '';
          if (cat == 'masterclass' || cat == 'general' || cat == 'academic') {
            isForFaculty = true;
          }
        }

        if (isForFaculty) {
          m['is_read_local'] = _readNoticeIds.contains(rawId);
          results.add(m);
        }
      }

      _cachedAnnouncements = results;
      _updateUnreadCount();
      return results;
    } catch (e) {
      debugPrint('[Teacher Notifications] fetchFacultyAnnouncements error: $e');
      return _cachedAnnouncements;
    }
  }

  Future<void> _loadSeenNoticeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenList = prefs.getStringList(_prefsSeenKey) ?? [];
      _seenNoticeIds.addAll(seenList);

      final readList = prefs.getStringList(_prefsReadKey) ?? [];
      _readNoticeIds.addAll(readList);
    } catch (_) {}
  }

  Future<void> _saveSeenNoticeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _seenNoticeIds.toList();
      if (toSave.length > 200) {
        toSave.removeRange(0, toSave.length - 200);
      }
      await prefs.setStringList(_prefsSeenKey, toSave);
    } catch (_) {}
  }

  Future<void> _saveReadNoticeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _readNoticeIds.toList();
      if (toSave.length > 200) {
        toSave.removeRange(0, toSave.length - 200);
      }
      await prefs.setStringList(_prefsReadKey, toSave);
    } catch (_) {}
  }

  void dispose() {
    _pollerTimer?.cancel();
    _realtimeChannel?.unsubscribe();
  }
}
