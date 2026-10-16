import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified Peer-to-Peer WebRTC Service for Kasarani Music Center (KMC).
/// 
/// Powers unmetered, $0.00/month 1-on-1 studio music lessons directly device-to-device.
/// Utilizes Supabase Realtime Broadcast channel for zero-cost SDP/ICE signaling.
/// Configured with custom music-grade audio constraints (Stereo Opus 48kHz, disabled
/// aggressive noise suppression & auto gain control) to preserve musical instrument acoustics.
class KmcWebRtcService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _signalingChannel;
  RTCPeerConnection? _peerConnection;
  RTCPeerConnection? _proctorPeerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool isInstructor = false;
  String currentSessionId = '';

  final ValueNotifier<bool> isRemoteConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLocalStreamActive = ValueNotifier<bool>(false);
  final ValueNotifier<RTCPeerConnectionState> connectionState =
      ValueNotifier<RTCPeerConnectionState>(
          RTCPeerConnectionState.RTCPeerConnectionStateNew);

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isFrontCamera = true;
  bool _isInitialized = false;
  bool _isRemoteDescriptionSet = false;

  final List<RTCIceCandidate> _pendingIceCandidates = [];

  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isFrontCamera => _isFrontCamera;
  bool get isInitialized => _isInitialized;

  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Initialize video renderers before rendering UI
  Future<void> initializeRenderers() async {
    if (_isInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
  }

  /// Start or join a live studio session
  Future<void> startSession({
    required String sessionId,
    required bool isHost,
  }) async {
    isInstructor = isHost;
    currentSessionId = sessionId;
    _isRemoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    await initializeRenderers();

    // 1. Acquire Camera and Microphone with Music-Grade Constraints
    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': false, // Preserves guitar/piano/violin acoustic resonances
        'autoGainControl': false,  // Preserves expressive pianissimo/fortissimo dynamics
        'highpassFilter': false,
        'channelCount': 2,         // Stereo 48kHz audio capture
      },
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      isLocalStreamActive.value = true;
    } catch (e) {
      debugPrint('[KmcWebRtc] Error acquiring user media: $e');
      // Fallback with minimal constraints if high-def stereo fails
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'}
      });
      localRenderer.srcObject = _localStream;
      isLocalStreamActive.value = true;
    }

    // 2. Create Peer Connection
    _peerConnection = await createPeerConnection(rtcConfiguration);

    // Add local tracks to peer connection
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Listen for remote tracks (Unified Plan)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[KmcWebRtc] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        isRemoteConnected.value = true;
      }
    };

    // Fallback stream listener
    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('[KmcWebRtc] Remote stream added');
      remoteRenderer.srcObject = stream;
      isRemoteConnected.value = true;
    };

    _peerConnection!.onRemoveStream = (MediaStream stream) {
      debugPrint('[KmcWebRtc] Remote stream removed');
      remoteRenderer.srcObject = null;
      isRemoteConnected.value = false;
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[KmcWebRtc] Connection state: $state');
      connectionState.value = state;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        isRemoteConnected.value = true;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        isRemoteConnected.value = false;
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[KmcWebRtc] ICE state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        isRemoteConnected.value = true;
      }
    };

    // 3. Connect Supabase Realtime Signaling Channel
    final channelName = 'kmc_webrtc_${sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    _signalingChannel = _supabase.channel(channelName);

    _signalingChannel!.onBroadcast(event: 'signal', callback: (payload) async {
      final type = payload['type'] as String?;
      final senderRole = payload['role'] as String?;

      // Ignore messages from self
      if ((isInstructor && senderRole == 'teacher') ||
          (!isInstructor && senderRole == 'student')) {
        return;
      }

      debugPrint('[KmcWebRtc] Signal received: type=$type from=$senderRole');

      if (type == 'ready') {
        // If peer announces readiness and we are the host, send an offer
        if (isInstructor) {
          debugPrint('[KmcWebRtc] Peer ready detected. Sending fresh SDP Offer.');
          await _createAndSendOffer();
        }
      } else if (type == 'offer' && !isInstructor) {
        // Student receives Teacher's offer
        final sdp = payload['sdp'] as String;
        final description = RTCSessionDescription(sdp, 'offer');
        await _peerConnection!.setRemoteDescription(description);
        _isRemoteDescriptionSet = true;
        await _flushPendingIceCandidates();

        // Create answer
        var answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });

        final optimizedSdp = _optimizeSdpForMusic(answer.sdp ?? '');
        answer = RTCSessionDescription(optimizedSdp, answer.type);
        await _peerConnection!.setLocalDescription(answer);

        _signalingChannel!.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'type': 'answer',
            'sdp': answer.sdp,
            'role': 'student',
          },
        );
      } else if (type == 'answer' && isInstructor) {
        // Teacher receives Student's answer
        final sdp = payload['sdp'] as String;
        final description = RTCSessionDescription(sdp, 'answer');
        await _peerConnection!.setRemoteDescription(description);
        _isRemoteDescriptionSet = true;
        await _flushPendingIceCandidates();
      } else if (type == 'candidate') {
        final candidateMap = payload['candidate'] as Map<String, dynamic>?;
        if (candidateMap != null) {
          final candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );

          if (_isRemoteDescriptionSet) {
            await _peerConnection!.addCandidate(candidate);
          } else {
            _pendingIceCandidates.add(candidate);
          }
        }
      } else if (type == 'proctor-join') {
        debugPrint('[KmcWebRtc] Proctor join detected. Preparing observation stream.');
        await _handleProctorJoin();
      } else if (type == 'proctor-answer') {
        final target = payload['target'] as String?;
        final myRole = isInstructor ? 'teacher' : 'student';
        if (target == myRole) {
          final sdp = payload['sdp'] as String;
          final description = RTCSessionDescription(sdp, 'answer');
          await _proctorPeerConnection?.setRemoteDescription(description);
          debugPrint('[KmcWebRtc] Proctor answer set successfully for $myRole.');
        }
      } else if (type == 'proctor-candidate') {
        final target = payload['target'] as String?;
        final myRole = isInstructor ? 'teacher' : 'student';
        if (target == myRole) {
          final candidateMap = payload['candidate'] as Map<String, dynamic>?;
          if (candidateMap != null) {
            final candidate = RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex'],
            );
            await _proctorPeerConnection?.addCandidate(candidate);
          }
        }
      } else if (type == 'proctor-leave') {
        debugPrint('[KmcWebRtc] Proctor left observation.');
        await _proctorPeerConnection?.close();
        _proctorPeerConnection = null;
      }
    });

    _signalingChannel!.subscribe();

    // 4. Send ICE candidates as they are discovered
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'role': isInstructor ? 'teacher' : 'student',
        },
      );
    };

    // 5. Announce presence to room
    _signalingChannel!.sendBroadcastMessage(
      event: 'signal',
      payload: {
        'type': 'ready',
        'role': isInstructor ? 'teacher' : 'student',
      },
    );

    // If host (teacher), initiate the SDP Offer
    if (isInstructor) {
      await _createAndSendOffer();
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;
    try {
      var offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      final optimizedSdp = _optimizeSdpForMusic(offer.sdp ?? '');
      offer = RTCSessionDescription(optimizedSdp, offer.type);
      await _peerConnection!.setLocalDescription(offer);

      _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'type': 'offer',
          'sdp': offer.sdp,
          'role': 'teacher',
        },
      );
      debugPrint('[KmcWebRtc] SDP Offer broadcasted.');
    } catch (e) {
      debugPrint('[KmcWebRtc] Error creating SDP Offer: $e');
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[KmcWebRtc] Error flushing candidate: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  /// Optimize Opus SDP string for uncompressed stereo musical instrument transmission
  String _optimizeSdpForMusic(String sdp) {
    if (sdp.contains('useinbandfec=1')) {
      return sdp.replaceAll(
        'useinbandfec=1',
        'useinbandfec=1;stereo=1;sprop-stereo=1;maxaveragebitrate=128000',
      );
    }
    return sdp;
  }

  /// Toggle audio microphone mute state
  bool toggleMic([bool? forceState]) {
    if (_localStream == null) return _isAudioMuted;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      _isAudioMuted = forceState ?? !_isAudioMuted;
      for (final track in audioTracks) {
        track.enabled = !_isAudioMuted;
      }
    }
    return _isAudioMuted;
  }

  /// Toggle local camera video mute/freeze state
  bool toggleVideo([bool? forceState]) {
    if (_localStream == null) return _isVideoMuted;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      _isVideoMuted = forceState ?? !_isVideoMuted;
      for (final track in videoTracks) {
        track.enabled = !_isVideoMuted;
      }
    }
    return _isVideoMuted;
  }

  /// Switch front/rear camera
  Future<bool> switchCamera() async {
    if (_localStream == null) return _isFrontCamera;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      _isFrontCamera = !_isFrontCamera;
    }
    return _isFrontCamera;
  }

  /// Handle incoming Proctor observation requests from the School Director / Admin
  Future<void> _handleProctorJoin() async {
    if (_localStream == null) return;
    try {
      await _proctorPeerConnection?.close();
      _proctorPeerConnection = await createPeerConnection(rtcConfiguration);

      for (final track in _localStream!.getTracks()) {
        await _proctorPeerConnection!.addTrack(track, _localStream!);
      }

      _proctorPeerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _signalingChannel?.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'type': 'proctor-candidate',
            'sender': isInstructor ? 'teacher' : 'student',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          },
        );
      };

      var offer = await _proctorPeerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      final optimizedSdp = _optimizeSdpForMusic(offer.sdp ?? '');
      offer = RTCSessionDescription(optimizedSdp, offer.type);
      await _proctorPeerConnection!.setLocalDescription(offer);

      _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'type': 'proctor-offer',
          'sender': isInstructor ? 'teacher' : 'student',
          'sdp': offer.sdp,
        },
      );
      debugPrint('[KmcWebRtc] Proctor offer dispatched from ${isInstructor ? "teacher" : "student"}.');
    } catch (e) {
      debugPrint('[KmcWebRtc] Error handling proctor join: $e');
    }
  }

  /// Cleanly close peer connections, stream tracks, and channel subscriptions
  Future<void> endSession() async {
    try {
      await _signalingChannel?.unsubscribe();
      _signalingChannel = null;

      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;

      await _proctorPeerConnection?.close();
      await _proctorPeerConnection?.dispose();
      _proctorPeerConnection = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _isInitialized = false;

      isRemoteConnected.value = false;
      isLocalStreamActive.value = false;
      _pendingIceCandidates.clear();
      _isRemoteDescriptionSet = false;
    } catch (e) {
      debugPrint('[KmcWebRtc] Cleanup error: $e');
    }
  }
}
