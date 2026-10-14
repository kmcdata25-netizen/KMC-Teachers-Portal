import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../services/teacher_notification_service.dart';
import '../theme/app_theme.dart';
import 'kmc_live_studio_screen.dart';

/// Dedicated Faculty Announcements and Notices Screen.
/// Displays direct administration memos, rehearsal updates, and live masterclass alerts.
class TeacherNotificationsScreen extends StatefulWidget {
  const TeacherNotificationsScreen({super.key});

  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notices = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements({bool force = false}) async {
    setState(() => _isLoading = true);
    final list = await TeacherNotificationService.instance
        .fetchFacultyAnnouncements(forceRefresh: force);
    if (mounted) {
      setState(() {
        _notices = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final ids = _notices
        .map((n) => n['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    await TeacherNotificationService.instance.markAllAsRead(ids);
    if (mounted) {
      setState(() {
        for (var n in _notices) {
          n['is_read_local'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All faculty notices marked as read.'),
          backgroundColor: AppTheme.brandGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markItemRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await TeacherNotificationService.instance.markNoticeAsRead(id);
    if (mounted) {
      setState(() {
        item['is_read_local'] = true;
      });
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return 'Recent';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notices
        .where((n) => n['is_read_local'] != true)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Faculty Announcements',
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount NEW',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Text(
              'Administration memos, notices & studio broadcasts',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_notices.isNotEmpty && unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.brandGreen),
              label: const Text(
                'Mark read',
                style: TextStyle(color: AppTheme.brandGreen, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textWhite),
            onPressed: () => _loadAnnouncements(force: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brandGreen),
            )
          : RefreshIndicator(
              color: AppTheme.brandGreen,
              backgroundColor: AppTheme.surfaceCard,
              onRefresh: () => _loadAnnouncements(force: true),
              child: _notices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.borderOutline),
                                ),
                                child: const Icon(
                                  Icons.campaign_outlined,
                                  color: AppTheme.brandGreen,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'All Caught Up!',
                                style: TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'There are no active faculty memos or administration announcements right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () => _loadAnnouncements(force: true),
                                icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.brandGreen),
                                label: const Text('Check for Updates'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.brandGreen,
                                  side: const BorderSide(color: AppTheme.borderOutline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _notices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _notices[index];
                        final title = item['title']?.toString() ?? 'Faculty Notice';
                        final body = item['message']?.toString() ?? '';
                        final category = item['category']?.toString() ?? 'Official Notice';
                        final sender = item['sender_name']?.toString() ?? 'Director Office';
                        final timeStr = _formatTime(item['created_at']);
                        final isRead = item['is_read_local'] == true;

                        final isLiveAlert = title.toUpperCase().contains('LIVE') ||
                            category.toLowerCase().contains('masterclass') ||
                            title.toLowerCase().contains('masterclass');

                        return InkWell(
                          onTap: () => _markItemRead(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead ? AppTheme.surfaceCard : AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLiveAlert
                                    ? AppTheme.brandGreen
                                    : (isRead ? AppTheme.borderOutline : AppTheme.brandGreen.withValues(alpha: 0.6)),
                                width: isLiveAlert || !isRead ? 1.5 : 1.0,
                              ),
                              boxShadow: !isRead
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.brandGreen.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isLiveAlert
                                            ? AppTheme.brandGreen.withValues(alpha: 0.2)
                                            : AppTheme.brandBlue.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isLiveAlert ? Icons.sensors_rounded : Icons.campaign_rounded,
                                            size: 12,
                                            color: isLiveAlert ? AppTheme.brandGreen : AppTheme.accentSky,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            category.toUpperCase(),
                                            style: TextStyle(
                                              color: isLiveAlert ? AppTheme.brandGreen : AppTheme.accentSky,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.brandGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: isRead ? AppTheme.textWhite : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_rounded,
                                          size: 13,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'From: $sender',
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isLiveAlert)
                                      FilledButton.icon(
                                        onPressed: () {
                                          _markItemRead(item);
                                          final fallbackSession = TeacherClass(
                                            id: item['id']?.toString() ?? 'session_live_notice',
                                            courseName: title,
                                            level: 'Masterclass',
                                            studentName: 'Studio Class Cohort',
                                            studentId: 'STUDIO-LIVE',
                                            timeSlot: '10:00 - 11:30 AM',
                                            studio: 'Studio 3 (Yamaha C7 Grand)',
                                            attendance: AttendanceState.present,
                                            topic: body.isNotEmpty ? body : 'Masterclass Broadcast',
                                            isLiveNow: true,
                                          );
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => KMCLiveStudioScreen(session: fallbackSession),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.videocam_rounded, size: 14),
                                        label: const Text('Open Studio Room'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.brandGreen,
                                          foregroundColor: Colors.black,
                                          minimumSize: const Size(0, 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
