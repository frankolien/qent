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

  // STUN handles the easy NATs (~70-80% of cases). On symmetric NATs —
  // every Nigerian carrier (MTN, Glo, Airtel) uses these — STUN alone fails
  // and the peers can't see each other directly. TURN relays media through
  // a public server and is the universal fix.
  //
  // openrelay.metered.ca is a free public TURN server. Rate-limited and
  // depends on someone else's goodwill, so it's a stopgap; long-term we
  // should self-host coturn on Oracle Cloud free tier.
  final _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        // TLS on 443 — survives corporate firewalls and aggressive carrier
        // filtering that block non-HTTPS UDP.
        'urls': 'turns:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ]
  };

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    debugPrint(
        '[VoiceCall] OPEN role=${widget.isOutgoing ? "caller" : "callee"} '
        'target=${widget.targetId} convo=${widget.conversationId}');
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
      // Only log call-relevant events so we don't spam the console with
      // every chat WS frame.
      const callTypes = {
        'call_answer', 'ice_candidate', 'call_hangup', 'call_reject'
      };
      if (callTypes.contains(event.type)) {
        debugPrint('[VoiceCall] WS in <-- ${event.type}');
      }
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
      debugPrint('[VoiceCall] caller: requesting mic...');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      debugPrint('[VoiceCall] caller: got mic, creating peer connection');

      _pc = await createPeerConnection(_config);
      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          // Log candidate type so we can tell if TURN relay is being
          // attempted at all on cellular. The candidate string contains
          // 'typ host', 'typ srflx' (STUN), or 'typ relay' (TURN).
          final c = candidate.candidate ?? '';
          final typ = RegExp(r'typ (\w+)').firstMatch(c)?.group(1) ?? '?';
          debugPrint('[VoiceCall] local ICE: $typ');
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onIceGatheringState = (s) =>
          debugPrint('[VoiceCall] ICE gathering: $s');
      _pc!.onIceConnectionState = (s) =>
          debugPrint('[VoiceCall] ICE connection: $s');

      _pc!.onConnectionState = (state) {
        debugPrint('[VoiceCall] PC connection: $state');
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
      debugPrint('[VoiceCall] caller: local SDP set, sending offer');

      setState(() => _callState = CallState.ringing);

      ref.read(wsServiceProvider).sendCallOffer(
        targetId: widget.targetId,
        sdp: offer.toMap(),
        conversationId: widget.conversationId,
      );
      debugPrint('[VoiceCall] WS out --> call_offer to ${widget.targetId}');

      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _callState == CallState.ringing) {
          debugPrint('[VoiceCall] 30s ring timeout, hanging up');
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
    debugPrint('[VoiceCall] callee: accept tapped');
    setState(() => _callState = CallState.connecting);

    try {
      debugPrint('[VoiceCall] callee: requesting mic...');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      debugPrint('[VoiceCall] callee: got mic, creating peer connection');

      _pc = await createPeerConnection(_config);
      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          final c = candidate.candidate ?? '';
          final typ = RegExp(r'typ (\w+)').firstMatch(c)?.group(1) ?? '?';
          debugPrint('[VoiceCall] local ICE (callee): $typ');
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onIceGatheringState = (s) =>
          debugPrint('[VoiceCall] ICE gathering (callee): $s');
      _pc!.onIceConnectionState = (s) =>
          debugPrint('[VoiceCall] ICE connection (callee): $s');

      _pc!.onConnectionState = (state) {
        debugPrint('[VoiceCall] PC connection (callee): $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _callState = CallState.connected);
            _startTimer();
          }
        }
      };

      final sdpMap = widget.incomingOffer!['sdp'] as Map<String, dynamic>;
      debugPrint('[VoiceCall] callee: applying remote offer');
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();

      debugPrint('[VoiceCall] callee: creating answer');
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);

      ref.read(wsServiceProvider).sendCallAnswer(
        targetId: widget.targetId,
        sdp: answer.toMap(),
      );
      debugPrint('[VoiceCall] WS out --> call_answer to ${widget.targetId}');
    } catch (e) {
      debugPrint('[VoiceCall] _acceptCall failed: $e');
      if (mounted) _endCall();
    }
  }

  void _onCallAnswer(Map<String, dynamic> payload) async {
    final sdpMap = payload['sdp'] as Map<String, dynamic>?;
    if (sdpMap == null || _pc == null) {
      debugPrint('[VoiceCall] caller: ignoring call_answer '
          '(sdp=${sdpMap != null}, pc=${_pc != null})');
      return;
    }
    debugPrint('[VoiceCall] caller: applying remote answer');
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
    final candStr = (candidateMap['candidate'] as String?) ?? '';
    final typ = RegExp(r'typ (\w+)').firstMatch(candStr)?.group(1) ?? '?';
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    // Buffer candidates that arrive before the peer connection is ready or
    // before remote description is set — adding them too early throws.
    if (_pc == null || !_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      debugPrint(
          '[VoiceCall] remote ICE buffered ($typ, total=${_pendingCandidates.length})');
      return;
    }
    debugPrint('[VoiceCall] remote ICE applied: $typ');
    await _pc!.addCandidate(candidate);
  }

  /// Drain any ICE candidates buffered before the remote description was set.
  Future<void> _flushPendingCandidates() async {
    if (_pc == null) return;
    if (_pendingCandidates.isEmpty) return;
    debugPrint(
        '[VoiceCall] flushing ${_pendingCandidates.length} buffered remote ICE');
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
    debugPrint(
        '[VoiceCall] END remote=$remote state=$_callState role=${widget.isOutgoing ? "caller" : "callee"}');
    _callTimer?.cancel();
    _localStream?.dispose();
    _pc?.close();
    _pc = null;

    if (!remote) {
      final ws = ref.read(wsServiceProvider);
      if (_callState == CallState.ringing && !widget.isOutgoing) {
        ws.sendCallReject(targetId: widget.targetId);
        debugPrint('[VoiceCall] WS out --> call_reject');
      } else {
        ws.sendCallHangup(targetId: widget.targetId);
        debugPrint('[VoiceCall] WS out --> call_hangup');
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
