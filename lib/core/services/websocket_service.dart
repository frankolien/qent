import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WebSocket connection states
enum WsState { disconnected, connecting, connected }

/// A single parsed WS event
class WsEvent {
  final String type;
  final Map<String, dynamic> payload;
  WsEvent({required this.type, required this.payload});
}

/// Manages a single WebSocket connection to the backend.
/// Handles auto-reconnect, heartbeat, and event broadcasting.
class WebSocketService {
  WebSocketChannel? _channel;
  WsState _state = WsState.disconnected;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30; // seconds

  final _eventController = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _eventController.stream;
  WsState get state => _state;

  /// Connect to WebSocket with JWT token
  Future<void> connect() async {
    if (_state == WsState.connecting || _state == WsState.connected) {
      print('[WS] Already ${_state.name}, skipping connect');
      return;
    }
    _state = WsState.connecting;
    print('[WS] Connecting...');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      print('[WS] FAIL: No auth_token in SharedPreferences');
      _state = WsState.disconnected;
      return;
    }
    print('[WS] Token found: ${token.substring(0, 20)}...');

    const prodUrl = 'https://qent-backend.onrender.com/api';
    final baseUrl = kReleaseMode ? prodUrl : (dotenv.env['API_BASE_URL'] ?? prodUrl);
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api', '');
    final wsUrl = '$wsBase/ws?token=$token';
    print('[WS] URL: $wsBase/ws?token=...');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _state = WsState.connected;
      _reconnectAttempts = 0;
      print('[WS] OK: Connected!');

      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final type = json['type'] as String? ?? '';
              final payload = json['payload'] as Map<String, dynamic>? ?? json;
              print('[WS] <<< Received: $type');
              _eventController.add(WsEvent(type: type, payload: payload));
            } catch (e) {
              print('[WS] Parse error: $e | data: $data'); 
            }
          }
        },
        onError: (e) {
          print('[WS] Stream error: $e');
          _handleDisconnect();
        },
        onDone: () {
          print('[WS] Stream closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('[WS] FAIL: Connection error: $e');
      _handleDisconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
    });
  }

  void _handleDisconnect() {
    _state = WsState.disconnected;
    _heartbeatTimer?.cancel();
    _channel = null;

    // Exponential backoff reconnect
    final delay = (_reconnectAttempts < 5)
        ? (1 << _reconnectAttempts)
        : _maxReconnectDelay;
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () => connect());
  }

  /// Send a JSON message through the WebSocket
  void send(Map<String, dynamic> message) {
    if (_state == WsState.connected && _channel != null) {
      print('[WS] >>> Sending: ${message['type']}');
      _channel!.sink.add(jsonEncode(message));
    } else {
      print('[WS] WARN: Cannot send ${message['type']}, state=$_state, channel=${_channel != null}');
    }
  }

  /// Send a chat message
  void sendChatMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
  }) {
    send({
      'type': 'chat_message',
      'conversation_id': conversationId,
      'content': content,
      'message_type': messageType,
    });
  }

  /// Send typing indicator
  void sendTyping({required String conversationId, required bool isTyping}) {
    send({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  /// Tell the server which conversation (if any) is open in the foreground.
  /// The server uses this to suppress push notifications for messages the
  /// user is already looking at. Pass `null` to clear (e.g. on screen exit).
  void setActiveConversation(String? conversationId) {
    send({
      'type': 'view_conversation',
      if (conversationId != null) 'conversation_id': conversationId,
    });
  }

  /// Send a call offer (WebRTC SDP)
  void sendCallOffer({required String targetId, required Map<String, dynamic> sdp, required String conversationId}) {
    send({
      'type': 'call_offer',
      'target_id': targetId,
      'conversation_id': conversationId,
      'sdp': sdp,
    });
  }

  /// Send a call answer
  void sendCallAnswer({required String targetId, required Map<String, dynamic> sdp}) {
    send({
      'type': 'call_answer',
      'target_id': targetId,
      'sdp': sdp,
    });
  }

  /// Send ICE candidate
  void sendIceCandidate({required String targetId, required Map<String, dynamic> candidate}) {
    send({
      'type': 'ice_candidate',
      'target_id': targetId,
      'candidate': candidate,
    });
  }

  /// Reject an incoming call
  void sendCallReject({required String targetId}) {
    send({'type': 'call_reject', 'target_id': targetId});
  }

  /// Hang up
  void sendCallHangup({required String targetId}) {
    send({'type': 'call_hangup', 'target_id': targetId});
  }

  /// Disconnect and clean up
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _state = WsState.disconnected;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

/// Global singleton provider
final wsServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});
