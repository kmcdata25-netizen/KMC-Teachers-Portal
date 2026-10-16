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

  RTCSessionDescription? _myOffer;
  RTCSessionDescription? _myAnswer;
  final List<RTCIceCandidate> _myIceCandidates = [];
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  Timer? _presenceTimer;

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
    _myOffer = null;
    _myAnswer = null;
    _myIceCandidates.clear();
    _pendingIceCandidates.clear();
    _presenceTimer?.cancel();

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
        _presenceTimer?.cancel();
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
        _presenceTimer?.cancel();
      }
    };

    // Store and trickle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _myIceCandidates.add(candidate);
      _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'signalType': 'candidate',
          'msgType': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'role': isInstructor ? 'teacher' : 'student',
        },
      );
    };

    // 3. Connect Supabase Realtime Signaling Channel
    final channelName = 'kmc_webrtc_${sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    _signalingChannel = _supabase.channel(channelName);

    _signalingChannel!.onBroadcast(event: 'signal', callback: (payload) async {
      // Robust signal type extraction immune to Supabase internal envelopes
      final signalType = payload['signalType'] as String? ??
          payload['msgType'] as String? ??
          payload['action'] as String? ??
          (payload['type'] != null && payload['type'] != 'broadcast'
              ? payload['type'] as String
              : null);

      final senderRole = payload['role'] as String?;

      // Ignore messages from self
      if ((isInstructor && senderRole == 'teacher') ||
          (!isInstructor && senderRole == 'student')) {
        return;
      }

      debugPrint('[KmcWebRtc] Signal received: signalType=$signalType from=$senderRole');

      if (signalType == 'ready') {
        debugPrint('[KmcWebRtc] Peer ready announcement from $senderRole.');
        if (isInstructor) {
          if (_myOffer != null) {
            debugPrint('[KmcWebRtc] Resending existing SDP Offer to newly ready student.');
            await _signalingChannel?.sendBroadcastMessage(
              event: 'signal',
              payload: {
                'signalType': 'offer',
                'msgType': 'offer',
                'sdp': _myOffer!.sdp,
                'role': 'teacher',
              },
            );
            _sendAllGatheredCandidates();
          } else {
            await _createAndSendOffer();
          }
        } else {
          // If student has already answered, re-send answer & candidates
          if (_myAnswer != null) {
            await _signalingChannel?.sendBroadcastMessage(
              event: 'signal',
              payload: {
                'signalType': 'answer',
                'msgType': 'answer',
                'sdp': _myAnswer!.sdp,
                'role': 'student',
              },
            );
            _sendAllGatheredCandidates();
          }
        }
      } else if (signalType == 'offer' && !isInstructor) {
        // Student receives Teacher's offer
        final sdp = payload['sdp'] as String?;
        if (sdp != null) {
          debugPrint('[KmcWebRtc] Student setting remote description from Teacher Offer...');
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
          _myAnswer = answer;

          await _signalingChannel?.sendBroadcastMessage(
            event: 'signal',
            payload: {
              'signalType': 'answer',
              'msgType': 'answer',
              'sdp': answer.sdp,
              'role': 'student',
            },
          );
          debugPrint('[KmcWebRtc] Student dispatched SDP Answer.');
          _sendAllGatheredCandidates();
        }
      } else if (signalType == 'answer' && isInstructor) {
        // Teacher receives Student's answer
        final sdp = payload['sdp'] as String?;
        if (sdp != null) {
          debugPrint('[KmcWebRtc] Teacher setting remote description from Student Answer...');
          final description = RTCSessionDescription(sdp, 'answer');
          await _peerConnection!.setRemoteDescription(description);
          _isRemoteDescriptionSet = true;
          await _flushPendingIceCandidates();
          _sendAllGatheredCandidates();
          debugPrint('[KmcWebRtc] Remote description established. P2P flow active.');
        }
      } else if (signalType == 'candidate') {
        final candidateMap = payload['candidate'] as Map<String, dynamic>?;
        if (candidateMap != null) {
          final candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );

          if (_isRemoteDescriptionSet) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              debugPrint('[KmcWebRtc] Add candidate error: $e');
            }
          } else {
            _pendingIceCandidates.add(candidate);
          }
        }
      } else if (signalType == 'candidates-batch') {
        final batch = payload['candidates'] as List<dynamic>?;
        if (batch != null) {
          for (final item in batch) {
            if (item is Map) {
              final candidate = RTCIceCandidate(
                item['candidate'],
                item['sdpMid'],
                item['sdpMLineIndex'],
              );
              if (_isRemoteDescriptionSet) {
                try {
                  await _peerConnection!.addCandidate(candidate);
                } catch (_) {}
              } else {
                _pendingIceCandidates.add(candidate);
              }
            }
          }
          if (_isRemoteDescriptionSet) {
            await _flushPendingIceCandidates();
          }
        }
      } else if (signalType == 'proctor-join') {
        debugPrint('[KmcWebRtc] Proctor join detected. Preparing observation stream.');
        await _handleProctorJoin();
      } else if (signalType == 'proctor-answer') {
        final target = payload['target'] as String?;
        final myRole = isInstructor ? 'teacher' : 'student';
        if (target == myRole || target == null) {
          final sdp = payload['sdp'] as String?;
          if (sdp != null) {
            final description = RTCSessionDescription(sdp, 'answer');
            await _proctorPeerConnection?.setRemoteDescription(description);
            debugPrint('[KmcWebRtc] Proctor answer set successfully for $myRole.');
          }
        }
      } else if (signalType == 'proctor-candidate') {
        final target = payload['target'] as String?;
        final myRole = isInstructor ? 'teacher' : 'student';
        if (target == myRole || target == null) {
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
      } else if (signalType == 'proctor-leave') {
        debugPrint('[KmcWebRtc] Proctor left observation.');
        await _proctorPeerConnection?.close();
        _proctorPeerConnection = null;
      }
    });

    _signalingChannel!.subscribe((status, [error]) async {
      debugPrint('[KmcWebRtc] Signaling subscription status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Announce presence immediately
        await _signalingChannel?.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'signalType': 'ready',
            'msgType': 'ready',
            'role': isInstructor ? 'teacher' : 'student',
          },
        );

        if (isInstructor) {
          await _createAndSendOffer();
        }
      }
    });

    // 4. Start periodic handshake keepalive (runs until connection established)
    int attempts = 0;
    _presenceTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (isRemoteConnected.value || attempts > 30 || _peerConnection == null) {
        timer.cancel();
        return;
      }

      debugPrint('[KmcWebRtc] Periodic presence heartbeat #$attempts...');
      await _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'signalType': 'ready',
          'msgType': 'ready',
          'role': isInstructor ? 'teacher' : 'student',
        },
      );

      if (isInstructor && _myOffer != null) {
        await _signalingChannel?.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'signalType': 'offer',
            'msgType': 'offer',
            'sdp': _myOffer!.sdp,
            'role': 'teacher',
          },
        );
        _sendAllGatheredCandidates();
      }
    });
  }

  void _sendAllGatheredCandidates() {
    if (_myIceCandidates.isEmpty || _signalingChannel == null) return;
    final batchPayload = _myIceCandidates.map((c) => {
      'candidate': c.candidate,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    }).toList();

    _signalingChannel?.sendBroadcastMessage(
      event: 'signal',
      payload: {
        'signalType': 'candidates-batch',
        'msgType': 'candidates-batch',
        'candidates': batchPayload,
        'role': isInstructor ? 'teacher' : 'student',
      },
    );
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
      _myOffer = offer;

      await _signalingChannel?.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'signalType': 'offer',
          'msgType': 'offer',
          'sdp': offer.sdp,
          'role': 'teacher',
        },
      );
      debugPrint('[KmcWebRtc] SDP Offer broadcasted with signalType=offer.');
      _sendAllGatheredCandidates();
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
            'signalType': 'proctor-candidate',
            'msgType': 'proctor-candidate',
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
          'signalType': 'proctor-offer',
          'msgType': 'proctor-offer',
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
      _presenceTimer?.cancel();
      _presenceTimer = null;

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
      isRemoteConnected.value = false;
      isLocalStreamActive.value = false;
      _myIceCandidates.clear();
      _pendingIceCandidates.clear();
      _myOffer = null;
      _myAnswer = null;
      _isRemoteDescriptionSet = false;
    } catch (e) {
      debugPrint('[KmcWebRtc] Cleanup error: $e');
    }
  }
}
