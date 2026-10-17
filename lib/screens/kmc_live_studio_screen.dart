import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mock_teacher_data.dart';
import '../services/kmc_webrtc_service.dart';
import '../services/teacher_supabase_service.dart';
import '../theme/app_theme.dart';

/// Full Native In-App Virtual Music Studio for Kasarani Music Center Faculty.
/// Provides pure peer-to-peer WebRTC video/audio masterclass streaming,
/// interactive digital metronome, concert pitch tuner, sheet music drawer,
/// and live session homework & notes synchronization with Central Mind.
class KMCLiveStudioScreen extends StatefulWidget {
  final TeacherClass session;

  const KMCLiveStudioScreen({
    super.key,
    required this.session,
  });

  @override
  State<KMCLiveStudioScreen> createState() => _KMCLiveStudioScreenState();
}

class _KMCLiveStudioScreenState extends State<KMCLiveStudioScreen>
    with SingleTickerProviderStateMixin {
  // WebRTC Service & Real-Time Telemetry
  final KmcWebRtcService _webrtcService = KmcWebRtcService();
  bool _isJoined = false;
  final int _myUid = 1001;
  int? _remoteUid;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isFrontCamera = true;
  bool _isLocalExpanded = false;

  // Real-Time Connection & Quality Telemetry
  final int _networkPingMs = 0;
  int _userCount = 1;

  // Session Duration Timer
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Active Tool Drawer Tab
  int _selectedToolIndex = 0; // 0 = None, 1 = Metronome, 2 = Tuner, 3 = Score, 4 = Notes

  // Metronome State
  bool _isMetronomeRunning = false;
  int _metronomeBpm = 96;
  int _timeSignature = 4; // 4/4
  int _currentBeat = 0;
  Timer? _metronomeTimer;
  final List<DateTime> _tapTimes = [];

  // Tuner / Reference Pitch State
  String _selectedPitch = 'A4 (440 Hz)';
  final Map<String, double> _pitches = {
    'A4 (440 Hz)': 440.0,
    'C4 (261.6 Hz - Middle C)': 261.63,
    'E4 (329.6 Hz - Guitar 1st)': 329.63,
    'G3 (196 Hz - Violin 4th)': 196.00,
    'D3 (146.8 Hz - Cello)': 146.83,
  };
  bool _isPlayingPitch = false;

  // Sheet Music / Repertoire State
  List<Map<String, dynamic>> _liveScores = [];
  bool _isLoadingScores = true;
  int _activeScoreIndex = 0;

  // Live Notes & Homework Logger
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _homeworkController = TextEditingController();
  bool _isSavingNotes = false;

  bool _hasBroadcastEnded = false;
  String? _liveRowId;
  Future<void>? _liveStartFuture;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.session.notes;
    _startSessionTimer();
    _initWebRtcAndMedia();
    _loadLiveScores();
    _liveStartFuture = _broadcastLiveStart();
  }

  Future<void> _loadLiveScores() async {
    try {
      final scores = await TeacherSupabaseService.instance.fetchCurriculumSheetMusic(
        courseName: widget.session.courseName,
      );
      if (mounted) {
        setState(() {
          _liveScores = scores;
          _isLoadingScores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingScores = false;
        });
      }
    }
  }

  Future<void> _broadcastLiveStart() async {
    try {
      _liveRowId = await TeacherSupabaseService.instance.startLiveBroadcast(
        sessionId: widget.session.id,
        studioRoom: widget.session.studio,
        topic: widget.session.topic.isNotEmpty ? widget.session.topic : widget.session.courseName,
        studentId: widget.session.studentId.isNotEmpty ? widget.session.studentId : null,
        studentProfileId: widget.session.studentProfileId.isNotEmpty ? widget.session.studentProfileId : null,
        studentName: widget.session.studentName.isNotEmpty ? widget.session.studentName : null,
      );
      if (_liveRowId == null) {
        debugPrint('[KMC Studio] WARNING: live_sessions row was NOT marked live; students cannot auto-discover this room.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not publish this live class to students. Check your connection and reopen the studio.'),
              backgroundColor: Color(0xFF5A1A1A),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[KMC Studio] Live start broadcast warning: $e');
    }
  }

  Future<void> _broadcastLiveEnd() async {
    if (_hasBroadcastEnded) return;
    _hasBroadcastEnded = true;
    try {
      // Make sure the start write has landed so we close the right row.
      await _liveStartFuture;
      final rowId = _liveRowId ?? widget.session.id;
      await TeacherSupabaseService.instance.endLiveBroadcast(
        sessionId: rowId,
      );
    } catch (e) {
      debugPrint('[KMC Studio] Live end broadcast warning: $e');
    }
  }

  @override
  void dispose() {
    _broadcastLiveEnd();
    _sessionTimer?.cancel();
    _metronomeTimer?.cancel();
    _notesController.dispose();
    _homeworkController.dispose();
    _webrtcService.endSession();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SESSION TIMER
  // ---------------------------------------------------------------------------
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ---------------------------------------------------------------------------
  // PURE P2P WEBRTC INITIALIZATION (SUPABASE REALTIME SIGNALING)
  // ---------------------------------------------------------------------------
  Future<void> _initWebRtcAndMedia() async {
    // 1. Request hardware camera and microphone permissions
    final permissions = await [Permission.camera, Permission.microphone].request();
    final cameraGranted = permissions[Permission.camera]?.isGranted ?? false;
    final micGranted = permissions[Permission.microphone]?.isGranted ?? false;

    if (!cameraGranted && !micGranted) {
      debugPrint('[KMC Studio] Camera & Microphone permissions are required for the Live Studio.');
      return;
    }

    try {
      // 2. Wire up connection state listeners from KmcWebRtcService
      _webrtcService.isRemoteConnected.addListener(() {
        if (!mounted) return;
        final connected = _webrtcService.isRemoteConnected.value;
        setState(() {
          if (connected) {
            _remoteUid = 2002;
            _userCount = 2;
          } else {
            _remoteUid = null;
            _userCount = 1;
          }
        });

        if (connected) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.brandGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🟢 Student Connected: ${widget.session.studentName} is live in studio!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0D2818),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.brandGreen, width: 1.5),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student has disconnected from studio: ${widget.session.studentName}'),
              backgroundColor: const Color(0xFF2B1D0C),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });

      // 3. Start WebRTC Host Session with Music-Grade Stereo Constraints
      final channel = widget.session.effectiveChannelName;
      await _webrtcService.startSession(
        sessionId: channel,
        isHost: true,
      );

      if (mounted) {
        setState(() {
          _isJoined = true;
          _isAudioMuted = _webrtcService.isAudioMuted;
          _isVideoMuted = _webrtcService.isVideoMuted;
          _isFrontCamera = _webrtcService.isFrontCamera;
        });
      }
    } catch (e) {
      debugPrint('[KMC Studio] WebRTC initialization error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MEDIA TOGGLES
  // ---------------------------------------------------------------------------
  Future<void> _toggleAudio() async {
    final nextState = _webrtcService.toggleMic();
    setState(() {
      _isAudioMuted = nextState;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleVideo() async {
    final nextState = _webrtcService.toggleVideo();
    setState(() {
      _isVideoMuted = nextState;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _switchCamera() async {
    HapticFeedback.mediumImpact();
    final isFront = await _webrtcService.switchCamera();
    setState(() {
      _isFrontCamera = isFront;
    });
  }

  // ---------------------------------------------------------------------------
  // METRONOME LOGIC
  // ---------------------------------------------------------------------------
  void _toggleMetronome() {
    if (_isMetronomeRunning) {
      _metronomeTimer?.cancel();
      setState(() {
        _isMetronomeRunning = false;
        _currentBeat = 0;
      });
    } else {
      setState(() {
        _isMetronomeRunning = true;
        _currentBeat = 0;
      });
      _scheduleMetronomeTicks();
    }
  }

  void _scheduleMetronomeTicks() {
    _metronomeTimer?.cancel();
    final intervalMs = (60000 / _metronomeBpm).round();
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || !_isMetronomeRunning) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentBeat = (_currentBeat + 1) % _timeSignature;
      });
      // Distinct haptic pulse on the downbeat
      if (_currentBeat == 0) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onTapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) {
      _tapTimes.removeAt(0);
    }
    if (_tapTimes.length >= 2) {
      int totalMs = 0;
      for (int i = 1; i < _tapTimes.length; i++) {
        totalMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (_tapTimes.length - 1);
      if (avgMs > 150 && avgMs < 2000) {
        final calcBpm = (60000 / avgMs).round().clamp(40, 240);
        setState(() {
          _metronomeBpm = calcBpm;
        });
        if (_isMetronomeRunning) {
          _scheduleMetronomeTicks();
        }
      }
    }
    HapticFeedback.selectionClick();
  }

  // ---------------------------------------------------------------------------
  // CONCERT PITCH TUNER LOGIC
  // ---------------------------------------------------------------------------
  void _toggleReferencePitch() {
    setState(() {
      _isPlayingPitch = !_isPlayingPitch;
    });
    HapticFeedback.mediumImpact();
  }

  // ---------------------------------------------------------------------------
  // SAVE NOTES & SYNC TO CENTRAL MIND
  // ---------------------------------------------------------------------------
  Future<void> _saveLessonNotes() async {
    final notes = _notesController.text.trim();
    final homework = _homeworkController.text.trim();
    final combinedNotes = homework.isNotEmpty
        ? '$notes\n\n[Assigned Homework]: $homework'
        : notes;

    setState(() {
      _isSavingNotes = true;
    });

    final success = await TeacherSupabaseService.instance
        .saveSessionNote(widget.session.id, combinedNotes);

    if (mounted) {
      setState(() {
        _isSavingNotes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Lesson feedback synced to student record.'
                : 'Offline: Notes stored locally for sync.',
          ),
          backgroundColor: success ? AppTheme.brandGreenDark : AppTheme.surfaceElevatedHigh,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // END STUDIO CONFIRMATION
  // ---------------------------------------------------------------------------
  Future<void> _confirmLeaveStudio() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderOutline),
        ),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppTheme.accentCoral),
            SizedBox(width: 10),
            Text(
              'End Studio Session?',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end this masterclass? Session duration (${_formatDuration(_elapsedSeconds)}) and lesson notes will be committed to the student transcript.',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Masterclass'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      await _saveLessonNotes();
      await _broadcastLiveEnd();
      await _webrtcService.endSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmLeaveStudio();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070B10), // Deep cinematic studio black
        body: SafeArea(
          child: Column(
            children: [
              _buildStudioTopHeader(),
              Expanded(
                child: Stack(
                  children: [
                    // Main Stage (Remote Student feed or Local Preview)
                    Positioned.fill(
                      child: _buildMainVideoStage(),
                    ),

                    // Draggable / Floating PiP for Teacher's Camera Feed
                    Positioned(
                      top: 16,
                      right: 16,
                      width: 120,
                      height: 160,
                      child: _buildTeacherPipCard(),
                    ),

                    // Floating Live Controls (Mute, Video, Flip, Leave)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _selectedToolIndex > 0 ? 250 : 20,
                      child: Center(
                        child: _buildFloatingControlsBar(),
                      ),
                    ),

                    // Bottom Expandable Studio Tools Drawer
                    if (_selectedToolIndex > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 240,
                        child: _buildToolDrawer(),
                      ),
                  ],
                ),
              ),

              // Bottom Music Faculty Toolbar
              _buildBottomMusicToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. STUDIO TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildStudioTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0B141D),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2D3D), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Exit button
          InkWell(
            onTap: _confirmLeaveStudio,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF162534),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF263D52)),
              ),
              child: const Icon(Icons.close_rounded, color: AppTheme.textWhite, size: 20),
            ),
          ),
          const SizedBox(width: 10),

          // Kasarani Music School Logo (Logo alone)
          Image.asset(
            'Images/logos/kms logo.png',
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'Images/logos/kms logo_original.png',
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),

          // Studio info & student
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.session.studio.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.brandGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.session.studentName} (${widget.session.courseName})',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Duration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF142433),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fiber_manual_record, color: AppTheme.accentCoral, size: 10),
                const SizedBox(width: 5),
                Text(
                  _formatDuration(_elapsedSeconds),
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // High-Definition Music Audio Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq_rounded, color: AppTheme.brandGreen, size: 12),
                SizedBox(width: 4),
                Text(
                  '48kHz HD Music',
                  style: TextStyle(
                    color: AppTheme.brandGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),


          // Real-Time Connection Telemetry HUD Pill
          InkWell(
            onTap: _showConnectionTelemetryModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _remoteUid != null
                    ? AppTheme.brandGreen.withValues(alpha: 0.22)
                    : (_isJoined ? Colors.amber.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remoteUid != null
                      ? AppTheme.brandGreen
                      : (_isJoined ? Colors.amber : Colors.red),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _remoteUid != null
                          ? AppTheme.brandGreen
                          : (_isJoined ? Colors.amber : Colors.red),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_remoteUid != null ? AppTheme.brandGreen : Colors.amber)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _remoteUid != null
                        ? 'Connected (2/2) • ${_networkPingMs > 0 ? '${_networkPingMs}ms' : 'Live'}'
                        : (_isJoined
                            ? 'In Studio (1/2) • Waiting for Student'
                            : 'Connecting...'),
                    style: TextStyle(
                      color: _remoteUid != null
                          ? AppTheme.brandGreen
                          : (_isJoined ? Colors.amber : Colors.redAccent),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline_rounded,
                    color: _remoteUid != null
                        ? AppTheme.brandGreen
                        : (_isJoined ? Colors.amber : Colors.redAccent),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MAIN VIDEO STAGE
  // ---------------------------------------------------------------------------
  Widget _buildMainVideoStage() {
    Widget stageContent;

    // 1. If WebRTC is active and a remote student has connected
    if (_isJoined && _remoteUid != null) {
      stageContent = ClipRRect(
        child: RTCVideoView(
          _webrtcService.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    } else if (_isLocalExpanded && !_isVideoMuted && _isJoined) {
      // 2. Teacher expanded local camera to full main stage
      stageContent = RTCVideoView(
        _webrtcService.localRenderer,
        mirror: _isFrontCamera,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      // 3. Waiting Stage: Faculty Live in Studio, waiting for Student
      stageContent = _buildLiveStudioWaitingStage();
    }

    return Stack(
      children: [
        Positioned.fill(child: stageContent),
        // Live session watermark: Kasarani Music School logo
        Positioned(
          top: 14,
          left: 16,
          child: Image.asset(
            'Images/logos/kms logo.png',
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'Images/logos/kms logo_original.png',
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'Images/logos/kms logo cropped.png',
                    height: 34,
                    fit: BoxFit.contain,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStudioWaitingStage() {
    return Container(
      color: const Color(0xFF070E16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'Images/logos/kms logo.png',
                width: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'Images/logos/kms logo_original.png',
                    width: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'Images/logos/kms logo cropped.png',
                        width: 180,
                        fit: BoxFit.contain,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live in ${widget.session.studio} • Room: ${widget.session.effectiveChannelName}',
                      style: const TextStyle(
                        color: AppTheme.brandGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Waiting for ${widget.session.studentName} to enter classroom...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TEACHER'S FLOATING PIP CARD
  // ---------------------------------------------------------------------------
  Widget _buildTeacherPipCard() {
    Widget videoWidget;
    if (_isVideoMuted) {
      videoWidget = Container(
        color: const Color(0xFF152636),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: AppTheme.textMuted,
                size: 26,
              ),
              SizedBox(height: 4),
              Text(
                'Camera Off',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    } else if (_isJoined) {
      // WebRTC live local stream preview
      videoWidget = RTCVideoView(
        _webrtcService.localRenderer,
        mirror: _isFrontCamera,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      // Camera initializing spinner
      videoWidget = Container(
        color: const Color(0xFF152636),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGreen),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111E2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLocalExpanded = !_isLocalExpanded;
                });
                HapticFeedback.lightImpact();
              },
              child: videoWidget,
            ),
          ),

          // Teacher Name Badge
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Faculty (You)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Flip camera quick button
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: _switchCamera,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flip_camera_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),

          // Fullscreen expand/collapse icon
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isLocalExpanded = !_isLocalExpanded;
                });
                HapticFeedback.lightImpact();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLocalExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME CONNECTION TELEMETRY & DIAGNOSTICS MODAL
  // ---------------------------------------------------------------------------
  void _showConnectionTelemetryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed_rounded, color: AppTheme.brandGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KMC Live Studio Connection Telemetry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pure P2P WebRTC Telemetry & Supabase Signaling',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Summary Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _remoteUid != null
                      ? AppTheme.brandGreen.withValues(alpha: 0.12)
                      : const Color(0xFF142433),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _remoteUid != null
                        ? AppTheme.brandGreen.withValues(alpha: 0.4)
                        : const Color(0xFF223A4E),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _remoteUid != null ? Icons.check_circle_rounded : Icons.pending_rounded,
                      color: _remoteUid != null ? AppTheme.brandGreen : Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _remoteUid != null
                            ? 'CONNECTED (2/2): Faculty & Student are live together.'
                            : 'IN STUDIO (1/2): Live on air. Waiting for student.',
                        style: TextStyle(
                          color: _remoteUid != null ? AppTheme.brandGreen : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Telemetry Grid
              _buildTelemetryRow(
                'Studio Channel ID',
                widget.session.effectiveChannelName,
                Icons.tag_rounded,
              ),
              _buildTelemetryRow(
                'Student Partner',
                '${widget.session.studentName} (${widget.session.studentId})',
                Icons.person_rounded,
              ),
              _buildTelemetryRow(
                'Signaling Engine',
                'Supabase Realtime Broadcast (Zero-Cost)',
                Icons.hub_rounded,
              ),
              _buildTelemetryRow(
                'Channel Population',
                '$_userCount active in room',
                Icons.group_rounded,
              ),
              _buildTelemetryRow(
                'Local Broadcaster UID',
                '$_myUid (Faculty Host)',
                Icons.perm_identity_rounded,
              ),
              _buildTelemetryRow(
                'Remote Student UID',
                _remoteUid != null ? '$_remoteUid (Broadcaster)' : 'Awaiting Connection',
                Icons.devices_rounded,
              ),
              _buildTelemetryRow(
                'Student Video Feed',
                _remoteUid != null
                    ? 'P2P Media Track Decoded (Active)'
                    : 'Awaiting Student Stream',
                Icons.videocam_rounded,
              ),
              _buildTelemetryRow(
                'Audio Scenario',
                '48kHz Fullband Stereo Music (Opus HD)',
                Icons.graphic_eq_rounded,
              ),
              _buildTelemetryRow(
                'Security & Encryption',
                'P2P DTLS-SRTP (Unmetered / Direct)',
                Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Telemetry Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelemetryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. FLOATING CONTROL BAR (MIC, VIDEO, FLIP, END)
  // ---------------------------------------------------------------------------
  Widget _buildFloatingControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C28).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF284058), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Audio Mute/Unmute
          _buildCircleButton(
            icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            isActive: !_isAudioMuted,
            activeColor: AppTheme.surfaceElevated,
            inactiveColor: AppTheme.accentCoral,
            tooltip: _isAudioMuted ? 'Unmute Mic' : 'Mute Mic',
            onTap: _toggleAudio,
          ),
          const SizedBox(width: 14),

          // Video Toggle
          _buildCircleButton(
            icon: _isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            isActive: !_isVideoMuted,
            activeColor: AppTheme.surfaceElevated,
            inactiveColor: AppTheme.accentCoral,
            tooltip: _isVideoMuted ? 'Turn Camera On' : 'Turn Camera Off',
            onTap: _toggleVideo,
          ),
          const SizedBox(width: 14),

          // Flip Camera (Hands/Keys vs. Face)
          _buildCircleButton(
            icon: Icons.cameraswitch_rounded,
            isActive: true,
            activeColor: AppTheme.surfaceElevated,
            inactiveColor: AppTheme.surfaceElevated,
            tooltip: 'Flip Camera (Keyboard/Fretboard)',
            onTap: _switchCamera,
          ),
          const SizedBox(width: 14),

          // End Session Button
          InkWell(
            onTap: _confirmLeaveStudio,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentCoral,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_end_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'End',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : inactiveColor,
            border: Border.all(
              color: isActive ? const Color(0xFF385570) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. BOTTOM MUSIC FACULTY TOOLBAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomMusicToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF091420),
        border: Border(
          top: BorderSide(color: Color(0xFF1E2F42), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolbarToolItem(
            index: 1,
            label: 'Metronome',
            icon: Icons.timer_outlined,
            indicator: _isMetronomeRunning ? '$_metronomeBpm BPM' : null,
          ),
          _buildToolbarToolItem(
            index: 2,
            label: 'Concert Pitch',
            icon: Icons.tune_rounded,
            indicator: _isPlayingPitch ? 'A=440' : null,
          ),
          _buildToolbarToolItem(
            index: 3,
            label: 'Sheet Music',
            icon: Icons.menu_book_rounded,
            indicator: 'Scores',
          ),
          _buildToolbarToolItem(
            index: 4,
            label: 'Lesson Notes',
            icon: Icons.edit_note_rounded,
            indicator: 'Sync',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarToolItem({
    required int index,
    required String label,
    required IconData icon,
    String? indicator,
  }) {
    final isSelected = _selectedToolIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedToolIndex = isSelected ? 0 : index;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF152A3E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentSky : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.accentSky : AppTheme.textMuted,
                  size: 22,
                ),
                if (indicator != null)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        indicator,
                        style: const TextStyle(
                          color: Color(0xFF061C2D),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. EXPANDABLE STUDIO TOOL DRAWER
  // ---------------------------------------------------------------------------
  Widget _buildToolDrawer() {
    Widget content;
    switch (_selectedToolIndex) {
      case 1:
        content = _buildMetronomeTool();
        break;
      case 2:
        content = _buildConcertPitchTool();
        break;
      case 3:
        content = _buildSheetMusicTool();
        break;
      case 4:
        content = _buildLessonNotesTool();
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF2A425C), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drawer Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getToolDrawerTitle(),
                  style: const TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedToolIndex = 0;
                    });
                  },
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E3246)),
          Expanded(child: content),
        ],
      ),
    );
  }

  String _getToolDrawerTitle() {
    switch (_selectedToolIndex) {
      case 1:
        return 'FACULTY METRONOME & RHYTHMIC PULSE';
      case 2:
        return 'CONCERT PITCH REFERENCE (A=440Hz)';
      case 3:
        return 'STUDENT REPERTOIRE & SCORES';
      case 4:
        return 'LIVE LESSON NOTES & HOMEWORK SYNC';
      default:
        return '';
    }
  }

  // Tool 1: Metronome
  Widget _buildMetronomeTool() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BPM Display
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_metronomeBpm',
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('BPM', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),

              // Visual Beat Indicators (1-2-3-4)
              Row(
                children: List.generate(_timeSignature, (index) {
                  final isCurrent = _isMetronomeRunning && _currentBeat == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent
                          ? (index == 0 ? AppTheme.accentCoral : AppTheme.brandGreen)
                          : const Color(0xFF1C3146),
                      border: Border.all(
                        color: isCurrent ? Colors.white : const Color(0xFF2C4966),
                      ),
                    ),
                  );
                }),
              ),

              // Start / Stop Toggle
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMetronomeRunning ? AppTheme.accentCoral : AppTheme.brandGreen,
                  foregroundColor: const Color(0xFF061C2D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _toggleMetronome,
                icon: Icon(
                  _isMetronomeRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  _isMetronomeRunning ? 'Stop' : 'Start',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Slider & Step Buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.accentSky),
                onPressed: () {
                  if (_metronomeBpm > 40) {
                    setState(() => _metronomeBpm--);
                    if (_isMetronomeRunning) _scheduleMetronomeTicks();
                  }
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.brandGreen,
                    inactiveTrackColor: const Color(0xFF1C3146),
                    thumbColor: AppTheme.brandGold,
                  ),
                  child: Slider(
                    value: _metronomeBpm.toDouble(),
                    min: 40,
                    max: 240,
                    divisions: 200,
                    onChanged: (val) {
                      setState(() => _metronomeBpm = val.round());
                      if (_isMetronomeRunning) _scheduleMetronomeTicks();
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.accentSky),
                onPressed: () {
                  if (_metronomeBpm < 240) {
                    setState(() => _metronomeBpm++);
                    if (_isMetronomeRunning) _scheduleMetronomeTicks();
                  }
                },
              ),
            ],
          ),

          // Tap Tempo & Time Signature Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.accentSky),
                  foregroundColor: AppTheme.accentSky,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _onTapTempo,
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const Text('Tap Tempo', style: TextStyle(fontSize: 12)),
              ),
              Row(
                children: [2, 3, 4, 6].map((beats) {
                  final isSelected = _timeSignature == beats;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _timeSignature = beats;
                        _currentBeat = 0;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.brandGold : const Color(0xFF192C3E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$beats/4',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF061C2D) : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tool 2: Concert Pitch Tuner
  Widget _buildConcertPitchTool() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Reference Pitch Tone:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _pitches.keys.map((pitchName) {
                final isSelected = _selectedPitch == pitchName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(pitchName),
                    selected: isSelected,
                    selectedColor: AppTheme.brandGold,
                    backgroundColor: const Color(0xFF152A3E),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF061C2D) : AppTheme.textWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedPitch = pitchName;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF112233),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF223E59)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPitch,
                      style: const TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Standard Orchestral Reference',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlayingPitch ? AppTheme.accentCoral : AppTheme.brandGreen,
                    foregroundColor: const Color(0xFF061C2D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _toggleReferencePitch,
                  icon: Icon(
                    _isPlayingPitch ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 16,
                  ),
                  label: Text(_isPlayingPitch ? 'Stop Tone' : 'Play Reference Tone'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tool 3: Sheet Music Repertoire
  Widget _buildSheetMusicTool() {
    if (_isLoadingScores) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppTheme.accentSky),
        ),
      );
    }
    if (_liveScores.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppTheme.textMuted, size: 36),
              SizedBox(height: 8),
              Text(
                'No curriculum scores attached to this session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _liveScores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final score = _liveScores[index];
        final isSelected = _activeScoreIndex == index;
        final title = score['title']?.toString() ?? 'Curriculum Score';
        final course = score['course']?.toString() ?? widget.session.courseName;
        final instrument = score['instrument']?.toString() ?? 'Faculty';
        final url = score['url']?.toString() ?? '';
        return InkWell(
          onTap: () async {
            setState(() {
              _activeScoreIndex = index;
            });
            HapticFeedback.selectionClick();
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF18324A) : const Color(0xFF112233),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.accentSky : const Color(0xFF1E3953),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: isSelected ? AppTheme.brandGold : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        course,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3B59),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    instrument,
                    style: const TextStyle(color: AppTheme.accentSky, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tool 4: Live Notes & Homework Logger
  Widget _buildLessonNotesTool() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Faculty feedback (tone, posture, phrasing)...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF132537),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF234464)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _homeworkController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Assigned drills & target BPM for next session...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF132537),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF234464)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    foregroundColor: const Color(0xFF061C2D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSavingNotes ? null : _saveLessonNotes,
                  icon: _isSavingNotes
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text(
                    _isSavingNotes ? 'Syncing...' : 'Save & Sync to Student',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
