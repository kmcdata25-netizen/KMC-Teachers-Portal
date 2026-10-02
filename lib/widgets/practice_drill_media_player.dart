import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

/// Premium Real Media Player Widget for Student Practice Drill Submissions.
/// Supports both streaming Video and Audio drills via [video_player] with
/// responsive controls, animated sound wave equalizer for audio, and scrub timeline.
class PracticeDrillMediaPlayer extends StatefulWidget {
  final String? mediaUrl;
  final String mediaType; // 'Video', 'Audio', or 'Score'
  final String drillTitle;
  final String durationText;

  const PracticeDrillMediaPlayer({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    required this.drillTitle,
    required this.durationText,
  });

  @override
  State<PracticeDrillMediaPlayer> createState() => _PracticeDrillMediaPlayerState();
}

class _PracticeDrillMediaPlayerState extends State<PracticeDrillMediaPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;
  late AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.mediaUrl;
    if (url == null || url.isEmpty || widget.mediaType == 'Score') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
        });
      }
      return;
    }

    try {
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _duration = controller.value.duration;
      });

      controller.addListener(_onControllerUpdate);

      _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        if (!mounted || _controller == null || !_isInitialized) return;
        final currentPos = _controller!.value.position;
        if (currentPos != _position && mounted) {
          setState(() {
            _position = currentPos;
          });
        }
      });
    } catch (e) {
      debugPrint('[DrillPlayer] Player init notice: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Stream playback unavailable. Ready in offline mode.';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    if (val.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = val.errorDescription ?? 'Playback issue';
      });
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !_isInitialized) return;

    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  void _seekTo(double value) {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    final target = Duration(milliseconds: value.toInt());
    c.seekTo(target);
    setState(() {
      _position = target;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _waveAnimController.dispose();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType == 'Score') {
      return _buildScoreCard();
    }

    if (widget.mediaType == 'Video') {
      return _buildVideoPlayerCard();
    }

    return _buildAudioPlayerCard();
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brandGold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.drillTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sheet Music Manuscript • Attached PDF',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.brandGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PDF / SCORE',
              style: TextStyle(
                color: AppTheme.brandGold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerCard() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final totalDuration = _duration.inMilliseconds > 0 ? _duration : const Duration(minutes: 2, seconds: 15);
    final currentPos = _isInitialized ? _position : Duration.zero;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying ? AppTheme.brandGreen.withValues(alpha: 0.5) : AppTheme.borderOutline,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: AppTheme.brandGreen.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play / Pause Action Button
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPlaying ? AppTheme.brandGreen : AppTheme.borderOutline,
                    width: 1.5,
                  ),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.brandGreen,
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: AppTheme.brandGreen,
                          size: 26,
                        ),
                        onPressed: _isInitialized
                            ? _togglePlayPause
                            : () {
                                // Fallback mock toggle if offline stream fails
                                setState(() {
                                  if (isPlaying) {
                                    _controller?.pause();
                                  } else {
                                    _controller?.play();
                                  }
                                });
                              },
                      ),
              ),
              const SizedBox(width: 12),

              // Title and Sound Wave
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.drillTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AUDIO DRILL',
                            style: TextStyle(
                              color: AppTheme.brandGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Sound wave visualizer bars
                    Row(
                      children: [
                        _buildWaveBar(14, 0.2, isPlaying),
                        _buildWaveBar(22, 0.5, isPlaying),
                        _buildWaveBar(10, 0.8, isPlaying),
                        _buildWaveBar(28, 0.3, isPlaying),
                        _buildWaveBar(18, 0.7, isPlaying),
                        _buildWaveBar(24, 0.4, isPlaying),
                        _buildWaveBar(12, 0.9, isPlaying),
                        _buildWaveBar(20, 0.6, isPlaying),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDuration(currentPos)} / ${_isInitialized ? _formatDuration(totalDuration) : widget.durationText}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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

          // Audio Seek Bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: AppTheme.brandGreen,
              inactiveTrackColor: AppTheme.surfaceElevated,
              thumbColor: AppTheme.brandGreen,
            ),
            child: Slider(
              value: currentPos.inMilliseconds.toDouble().clamp(0.0, totalDuration.inMilliseconds.toDouble()),
              min: 0.0,
              max: totalDuration.inMilliseconds.toDouble() > 0 ? totalDuration.inMilliseconds.toDouble() : 100.0,
              onChanged: _isInitialized ? _seekTo : null,
            ),
          ),

          if (_hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: AppTheme.accentSky, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerCard() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final totalDuration = _duration.inMilliseconds > 0 ? _duration : const Duration(minutes: 1, seconds: 24);
    final currentPos = _isInitialized ? _position : Duration.zero;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying ? AppTheme.brandGreen.withValues(alpha: 0.5) : AppTheme.borderOutline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Video Surface Frame
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isInitialized && _controller != null)
                  VideoPlayer(_controller!)
                else
                  Container(
                    color: AppTheme.surfaceElevated,
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: AppTheme.brandGreen)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_rounded, color: AppTheme.brandGreen, size: 36),
                                const SizedBox(height: 6),
                                Text(
                                  widget.drillTitle,
                                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
                                ),
                              ],
                            ),
                    ),
                  ),

                // Play / Pause Center Overlay
                if (!_isLoading)
                  GestureDetector(
                    onTap: _isInitialized ? _togglePlayPause : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.brandGreen, width: 1.5),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: AppTheme.brandGreen,
                        size: 30,
                      ),
                    ),
                  ),

                // Top Media Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'STUDENT VIDEO DRILL',
                      style: TextStyle(
                        color: AppTheme.brandGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Video Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryBackground,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: AppTheme.brandGreen,
                    inactiveTrackColor: AppTheme.surfaceElevated,
                    thumbColor: AppTheme.brandGreen,
                  ),
                  child: Slider(
                    value: currentPos.inMilliseconds.toDouble().clamp(0.0, totalDuration.inMilliseconds.toDouble()),
                    min: 0.0,
                    max: totalDuration.inMilliseconds.toDouble() > 0 ? totalDuration.inMilliseconds.toDouble() : 100.0,
                    onChanged: _isInitialized ? _seekTo : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatDuration(currentPos)} / ${_isInitialized ? _formatDuration(totalDuration) : widget.durationText}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    Text(
                      widget.drillTitle,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveBar(double height, double delay, bool isPlaying) {
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, child) {
        final factor = isPlaying ? (0.4 + 0.6 * ((_waveAnimController.value + delay) % 1.0)) : 0.3;
        return Container(
          width: 3,
          height: height * factor,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: isPlaying ? AppTheme.brandGreen : AppTheme.textMuted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
