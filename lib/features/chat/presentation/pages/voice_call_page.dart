import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';

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
  }

  void _onIceCandidate(Map<String, dynamic> payload) async {
    final candidateMap = payload['candidate'] as Map<String, dynamic>?;
    if (candidateMap == null || _pc == null) return;
    await _pc!.addCandidate(RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    ));
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
          // Blurred background with profile image
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.0,
                    -0.3 + (_bgController.value * 0.1),
                  ),
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1a1a2e).withValues(alpha: 0.8),
                    const Color(0xFF0a0a0a),
                  ],
                ),
              ),
            ),
          ),

          // Large blurred avatar in background
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -50,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Opacity(
                opacity: 0.3,
                child: ProfileImageWidget(
                  userId: widget.targetId,
                  size: MediaQuery.of(context).size.width + 100,
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Profile image with animated ring
                _buildProfileSection(),
                const SizedBox(height: 20),

                // Online indicator dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _callState == CallState.connected
                        ? const Color(0xFF22C55E)
                        : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: _callState == CallState.connected
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFF22C55E).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  widget.targetName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Status
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: _callState == CallState.connected
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom control bar
                _buildBottomBar(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final pulseValue = _pulseController.value;
        final isRinging = _callState == CallState.ringing;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse rings (only when ringing)
            if (isRinging) ...[
              _buildPulseRing(pulseValue, 160, 0.15),
              _buildPulseRing((pulseValue + 0.33) % 1.0, 180, 0.1),
              _buildPulseRing((pulseValue + 0.66) % 1.0, 200, 0.05),
            ],

            // Connected green ring
            if (_callState == CallState.connected)
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),

            // Profile image
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ProfileImageWidget(userId: widget.targetId, size: 120),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPulseRing(double value, double maxSize, double maxOpacity) {
    final size = 120 + (maxSize - 120) * value;
    final opacity = maxOpacity * (1 - value);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_callState == CallState.ringing && !widget.isOutgoing) {
      // Incoming call: Accept / Decline
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBarButton(
              icon: Icons.call_end_rounded,
              color: const Color(0xFFEF4444),
              filled: true,
              onTap: () => _endCall(),
            ),
            const SizedBox(width: 24),
            _buildBarButton(
              icon: Icons.call_rounded,
              color: const Color(0xFF22C55E),
              filled: true,
              onTap: _acceptCall,
            ),
          ],
        ),
      );
    }

    if (_callState == CallState.ended) return const SizedBox.shrink();

    // Outgoing or connected: control bar
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_callState == CallState.connected) ...[
            _buildBarButton(
              icon: Icons.videocam_off_rounded,
              color: Colors.white,
              active: false,
              onTap: () {},
            ),
            _buildBarButton(
              icon: _isSpeaker
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              color: Colors.white,
              active: _isSpeaker,
              onTap: _toggleSpeaker,
            ),
            _buildBarButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: Colors.white,
              active: _isMuted,
              onTap: _toggleMute,
            ),
          ],
          _buildBarButton(
            icon: Icons.call_end_rounded,
            color: const Color(0xFFEF4444),
            filled: true,
            onTap: () => _endCall(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarButton({
    required IconData icon,
    required Color color,
    bool filled = false,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: filled
              ? color
              : active
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : color.withValues(alpha: active ? 1.0 : 0.6),
          size: 26,
        ),
      ),
    );
  }
}
