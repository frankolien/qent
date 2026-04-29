import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/core/providers/user_cache_provider.dart';

enum CallState { ringing, connecting, connected, ended }

class VoiceCallPage extends ConsumerStatefulWidget {
  final String targetId;
  final String targetName;
  final String conversationId;
  final bool isOutgoing;
  final Map<String, dynamic>? incomingOffer;

  const VoiceCallPage({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.conversationId,
    this.isOutgoing = true,
    this.incomingOffer,
  });

  @override
  ConsumerState<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends ConsumerState<VoiceCallPage>
    with TickerProviderStateMixin {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  CallState _callState = CallState.ringing;
  bool _isMuted = false;
  bool _isSpeaker = false;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription<WsEvent>? _wsSub;
  late AnimationController _pulseController;
  late AnimationController _bgController;

  /// ICE candidates that arrive before [_pc] exists or before
  /// [setRemoteDescription] completes get buffered here and flushed once the
  /// peer connection is ready. Without this, calls hang on "Connecting…".
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  final _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _listenToSignaling();
    if (widget.isOutgoing) {
      _startOutgoingCall();
    } else {
      _handleIncomingCall();
    }
  }

  void _listenToSignaling() {
    final ws = ref.read(wsServiceProvider);
    _wsSub = ws.events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case 'call_answer':
          _onCallAnswer(event.payload);
          break;
        case 'ice_candidate':
          _onIceCandidate(event.payload);
          break;
        case 'call_hangup':
          _endCall(remote: true);
          break;
        case 'call_reject':
          _endCall(remote: true);
          break;
      }
    });
  }

  Future<void> _startOutgoingCall() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      _pc = await createPeerConnection(_config);
      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _callState = CallState.connected);
            _startTimer();
          }
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState
                    .RTCPeerConnectionStateDisconnected) {
          _endCall();
        }
      };

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      setState(() => _callState = CallState.ringing);

      ref.read(wsServiceProvider).sendCallOffer(
        targetId: widget.targetId,
        sdp: offer.toMap(),
        conversationId: widget.conversationId,
      );

      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _callState == CallState.ringing) {
          _endCall();
        }
      });
    } catch (e) {
      debugPrint('[VoiceCall] Failed to start call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not start call. Check microphone permissions.')),
        );
        _endCall();
      }
    }
  }

  Future<void> _handleIncomingCall() async {
    if (widget.incomingOffer == null) return;
    setState(() => _callState = CallState.ringing);
  }

  Future<void> _acceptCall() async {
    if (widget.incomingOffer == null) return;
    setState(() => _callState = CallState.connecting);

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      _pc = await createPeerConnection(_config);
      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _callState = CallState.connected);
            _startTimer();
          }
        }
      };

      final sdpMap = widget.incomingOffer!['sdp'] as Map<String, dynamic>;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);

      ref.read(wsServiceProvider).sendCallAnswer(
        targetId: widget.targetId,
        sdp: answer.toMap(),
      );
    } catch (e) {
      if (mounted) _endCall();
    }
  }

  void _onCallAnswer(Map<String, dynamic> payload) async {
    final sdpMap = payload['sdp'] as Map<String, dynamic>?;
    if (sdpMap == null || _pc == null) return;
    setState(() => _callState = CallState.connecting);
    await _pc!.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
    );
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  void _onIceCandidate(Map<String, dynamic> payload) async {
    final candidateMap = payload['candidate'] as Map<String, dynamic>?;
    if (candidateMap == null) return;
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    // Buffer candidates that arrive before the peer connection is ready or
    // before remote description is set — adding them too early throws.
    if (_pc == null || !_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    await _pc!.addCandidate(candidate);
  }

  /// Drain any ICE candidates buffered before the remote description was set.
  Future<void> _flushPendingCandidates() async {
    if (_pc == null) return;
    for (final c in _pendingCandidates) {
      try {
        await _pc!.addCandidate(c);
      } catch (e) {
        debugPrint('[VoiceCall] Failed to add buffered candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _isMuted = !audioTrack.enabled);
      HapticFeedback.lightImpact();
    }
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(_isSpeaker);
    });
    HapticFeedback.lightImpact();
  }

  void _endCall({bool remote = false}) {
    _callTimer?.cancel();
    _localStream?.dispose();
    _pc?.close();
    _pc = null;

    if (!remote) {
      final ws = ref.read(wsServiceProvider);
      if (_callState == CallState.ringing && !widget.isOutgoing) {
        ws.sendCallReject(targetId: widget.targetId);
      } else {
        ws.sendCallHangup(targetId: widget.targetId);
      }
    }

    if (mounted) {
      setState(() => _callState = CallState.ended);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _callTimer?.cancel();
    _localStream?.dispose();
    _pc?.close();
    _pulseController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = switch (_callState) {
      CallState.ringing =>
        widget.isOutgoing ? 'Calling...' : 'Incoming call',
      CallState.connecting => 'Connecting...',
      CallState.connected => _formatDuration(_callDuration),
      CallState.ended => 'Call ended',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen blurred profile photo background
          Consumer(
            builder: (context, ref, _) {
              final userDataAsync = ref.watch(
                userDataStreamProvider(widget.targetId),
              );
              final photoUrl = userDataAsync.value?['profileImageUrl'] as String?;

              if (photoUrl != null && photoUrl.isNotEmpty) {
                return SizedBox.expand(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)),
                    ),
                  ),
                );
              }
              return Container(color: const Color(0xFF1a1a2e));
            },
          ),

          // Dark overlay for readability
          Container(color: Colors.black.withValues(alpha: 0.3)),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Profile image with green online dot
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    SizedBox(
                      width: 168, height: 168,
                      child: ClipOval(
                        child: ProfileImageWidget(userId: widget.targetId, size: 168),
                      ),
                    ),
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Name
                Text(
                  widget.targetName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Status / Timer
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom control bar
                _buildBottomBar(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_callState == CallState.ringing && !widget.isOutgoing) {
      // Incoming call: separate Accept / Decline pill (no shared capsule)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHangupButton(onTap: () => _endCall()),
            _buildAcceptButton(onTap: _acceptCall),
          ],
        ),
      );
    }

    if (_callState == CallState.ended) return const SizedBox.shrink();

    // Outgoing or connected: single dark capsule with 4 controls
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(48),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Video — placeholder, no-op until video calls land
            _buildFlatButton(
              icon: Icons.videocam_outlined,
              onTap: () {},
            ),
            // Speaker
            _buildFlatButton(
              icon: _isSpeaker
                  ? Icons.volume_up_rounded
                  : Icons.volume_up_outlined,
              active: _isSpeaker,
              onTap: _toggleSpeaker,
            ),
            // Mute
            _buildFlatButton(
              icon: _isMuted ? Icons.mic_off_outlined : Icons.mic_none_rounded,
              active: _isMuted,
              onTap: _toggleMute,
            ),
            // Hangup — red filled circle, slightly inset
            _buildHangupButton(onTap: () => _endCall()),
          ],
        ),
      ),
    );
  }

  /// Flat icon button used inside the dark control capsule.
  Widget _buildFlatButton({
    required IconData icon,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56, height: 56,
        child: Center(
          child: Icon(
            icon,
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildHangupButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFFE53E5C),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildAcceptButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF22C55E),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
