import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qent/core/services/api_client.dart';
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
  /// Set to true once [_endCall] runs, so any late WS frames after the
  /// peer connection has been torn down stop allocating buffers /
  /// touching disposed objects.
  bool _ended = false;
  /// In-flight TURN credential fetch — awaited by both the prewarm path
  /// (callee, on incoming) and the accept path so accepting before the
  /// prewarm completes doesn't fall back to STUN-only.
  Future<void>? _iceFetchInFlight;
  /// Cancellable handle for the 30s ringing timeout. Cancelled when the
  /// call connects, is rejected, or hangs up.
  Timer? _ringTimeout;
  /// Last few diagnostic events so the on-screen debug overlay can
  /// surface where a call is stalling on TestFlight (no flutter logs
  /// available there).
  final List<String> _diag = [];
  void _logDiag(String s) {
    debugPrint('[VoiceCall] $s');
    if (!mounted) return;
    setState(() {
      _diag.add(s);
      if (_diag.length > 8) _diag.removeAt(0);
    });
  }

  // STUN handles the easy NATs (~70-80% of cases). On symmetric NATs —
  // every Nigerian carrier (MTN, Glo, Airtel) uses these — STUN alone
  // fails and the peers can't see each other directly. TURN relays media
  // through a public server and is the universal fix.
  //
  // The actual ICE servers are fetched from `/api/turn-credentials` at
  // call open time so the Metered API key stays out of the IPA. The
  // backend mints short-lived (TTL ~hours) credentials via Metered's API.
  // STUN-only fallback is used if the fetch fails so same-LAN calls
  // still work.
  Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  /// Fetch fresh ICE servers from the backend. Best-effort — if the
  /// endpoint fails we keep the STUN-only fallback already in [_config]
  /// and same-LAN calls still work.
  ///
  /// Memoised via [_iceFetchInFlight] so the prewarm started in
  /// [_handleIncomingCall] can be awaited again in [_acceptCall]
  /// without firing a second HTTP request.
  Future<void> _fetchIceServers() {
    return _iceFetchInFlight ??= _doFetchIceServers();
  }

  Future<void> _doFetchIceServers() async {
    try {
      final api = ApiClient();
      final resp = await api.get('/turn-credentials');
      if (resp.isSuccess && resp.body is List) {
        final list = (resp.body as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          _config = {'iceServers': list};
          // Count how many are TURN vs STUN so logs make the
          // cellular-call diagnosis easy.
          final turnCount = list
              .where((s) => (s['urls'] as String?)?.startsWith('turn') ?? false)
              .length;
          debugPrint(
              '[VoiceCall] fetched ${list.length} ICE servers ($turnCount TURN)');
          return;
        }
      }
      debugPrint(
          '[VoiceCall] /turn-credentials returned non-list — using STUN fallback');
    } catch (e) {
      debugPrint('[VoiceCall] /turn-credentials failed: $e — STUN fallback');
    }
  }

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
      // Fetch TURN credentials in parallel with mic permission — both
      // need to complete before we createPeerConnection. Doing them
      // concurrently keeps the time-to-ring snappy on slow Render
      // cold-start days.
      debugPrint('[VoiceCall] caller: requesting mic + TURN creds...');
      final results = await Future.wait([
        navigator.mediaDevices.getUserMedia({'audio': true, 'video': false}),
        _fetchIceServers(),
      ]);
      _localStream = results[0] as MediaStream;
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
          _logDiag('local ICE: $typ');
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onIceGatheringState = (s) =>
          _logDiag('ICE gather: ${s.name.replaceFirst('RTCIceGatheringState', '')}');
      _pc!.onIceConnectionState = (s) {
        _logDiag('ICE conn: ${s.name.replaceFirst('RTCIceConnectionState', '')}');
        if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _endCall();
        }
      };

      _pc!.onConnectionState = (state) {
        _logDiag('PC: ${state.name.replaceFirst('RTCPeerConnectionState', '')}');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _callState = CallState.connected);
            _ringTimeout?.cancel();
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

      // Without an explicit onTrack handler the remote stream isn't
      // attached anywhere, and on iOS the AVAudioSession isn't
      // necessarily activated to play it. Adding the remote audio
      // tracks and forcing the speaker route through Helper sets up
      // the AVAudioSession in PlayAndRecord mode so the earpiece /
      // loudspeaker can actually play received audio. Without this
      // the call connects ICE-wise but the user hears silence.
      _pc!.onTrack = (event) {
        _logDiag('remote track: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          for (final t in event.streams.first.getAudioTracks()) {
            t.enabled = true;
          }
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

      _ringTimeout = Timer(const Duration(seconds: 30), () {
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
    // Pre-warm TURN credentials while the phone is still ringing so the
    // accept tap doesn't have to wait for the round-trip. The fetch is
    // memoised so [_acceptCall] awaiting it again is a no-op if it
    // already finished.
    unawaited(_fetchIceServers());
  }

  Future<void> _acceptCall() async {
    if (widget.incomingOffer == null) return;
    debugPrint('[VoiceCall] callee: accept tapped');
    setState(() => _callState = CallState.connecting);

    try {
      // Fetch mic + (still in-flight or fresh) TURN creds in parallel.
      // If the prewarm already completed, _fetchIceServers returns the
      // memoised future immediately. If the user accepted before the
      // prewarm finished, we wait — STUN-only is unusable on cellular.
      debugPrint('[VoiceCall] callee: requesting mic + TURN creds...');
      final results = await Future.wait([
        navigator.mediaDevices.getUserMedia({'audio': true, 'video': false}),
        _fetchIceServers(),
      ]);
      _localStream = results[0] as MediaStream;
      debugPrint('[VoiceCall] callee: got mic, creating peer connection');

      _pc = await createPeerConnection(_config);
      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          final c = candidate.candidate ?? '';
          final typ = RegExp(r'typ (\w+)').firstMatch(c)?.group(1) ?? '?';
          _logDiag('local ICE (cee): $typ');
          ref.read(wsServiceProvider).sendIceCandidate(
            targetId: widget.targetId,
            candidate: candidate.toMap(),
          );
        }
      };

      _pc!.onIceGatheringState = (s) =>
          _logDiag('ICE gather (cee): ${s.name.replaceFirst('RTCIceGatheringState', '')}');
      _pc!.onIceConnectionState = (s) {
        _logDiag('ICE conn (cee): ${s.name.replaceFirst('RTCIceConnectionState', '')}');
        // If ICE never establishes (TURN unreachable, etc.) the call
        // sits forever on "Connecting…" without this. Mirror the
        // caller-side failure handling.
        if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _endCall();
        }
      };

      _pc!.onConnectionState = (state) {
        _logDiag('PC (cee): ${state.name.replaceFirst('RTCPeerConnectionState', '')}');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _callState = CallState.connected);
            _startTimer();
          }
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _endCall();
        }
      };

      // Mirror the caller-side onTrack handler so received audio is
      // attached + iOS AudioSession is activated for playback.
      _pc!.onTrack = (event) {
        _logDiag('remote track (cee): ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          for (final t in event.streams.first.getAudioTracks()) {
            t.enabled = true;
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
    if (_ended) return;
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
    final next = !_isSpeaker;
    // Helper.setSpeakerphoneOn is the documented flutter_webrtc API for
    // routing call audio to the loudspeaker on iOS / Android. The
    // previous code called `track.enableSpeakerphone` on each local
    // audio track, which is a deprecated MediaStreamTrack method that
    // didn't actually flip the audio route on most builds — speaker
    // toggle visually changed but audio kept playing through the
    // earpiece.
    Helper.setSpeakerphoneOn(next);
    setState(() => _isSpeaker = next);
    HapticFeedback.lightImpact();
  }

  void _endCall({bool remote = false}) {
    if (_ended) return;
    _ended = true;
    debugPrint(
        '[VoiceCall] END remote=$remote state=$_callState role=${widget.isOutgoing ? "caller" : "callee"}');
    _ringTimeout?.cancel();
    _callTimer?.cancel();
    _localStream?.dispose();
    _pc?.close();
    _pc = null;
    _pendingCandidates.clear();

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
    _ringTimeout?.cancel();
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
                // Tiny diagnostic pill so we can verify TURN/ICE state
                // on TestFlight (where there's no flutter logs). Green
                // pill = TURN servers fetched (cross-network calls
                // should work). Amber pill = STUN-only fallback (key
                // missing on backend or Metered call failed).
                _IceStatusPill(config: _config),
                if (_diag.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final line in _diag)
                            Text(
                              line,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
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

/// Tiny status pill at the top of the call screen showing whether
/// TURN servers were fetched. Visible to the user so we can verify
/// cross-network call readiness on TestFlight without relying on
/// `flutter logs` (which isn't available off a debug build).
///
/// Green pill ("TURN: N") = relay servers fetched from Metered.
/// Cross-cellular calls should connect.
///
/// Amber pill ("STUN only") = the backend's `/turn-credentials`
/// returned no TURN entries — either `METERED_API_KEY` is unset on
/// Render or the upstream call to Metered failed. Calls between
/// devices on different NATs (different cellular networks) will
/// fail to connect.
class _IceStatusPill extends StatelessWidget {
  final Map<String, dynamic> config;
  const _IceStatusPill({required this.config});

  @override
  Widget build(BuildContext context) {
    final servers = (config['iceServers'] as List?) ?? const [];
    final turnCount = servers.where((s) {
      final urls = (s as Map)['urls'];
      if (urls is String) return urls.startsWith('turn');
      if (urls is List) return urls.any((u) => u is String && u.startsWith('turn'));
      return false;
    }).length;
    final hasTurn = turnCount > 0;
    final label = hasTurn ? 'TURN: $turnCount' : 'STUN only';
    final bg = hasTurn
        ? const Color(0xFF1B5E20).withValues(alpha: 0.85)
        : const Color(0xFFB26A00).withValues(alpha: 0.85);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
