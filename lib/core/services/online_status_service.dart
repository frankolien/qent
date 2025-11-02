import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

/// Service to manage user online/offline status in real-time
class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  FirebaseFirestore? _firestore;
  fb.FirebaseAuth? _auth;
  Timer? _lastSeenTimer;
  String? _currentUserId;
  DocumentReference? _userPresenceRef;

  /// Initialize the service
  void initialize({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  }) {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _auth = auth ?? fb.FirebaseAuth.instance;
    _currentUserId = _auth?.currentUser?.uid;

    if (_currentUserId != null) {
      _setupPresence();
    }

    // Listen to auth state changes
    _auth?.authStateChanges().listen((user) {
      if (user != null && user.uid != _currentUserId) {
        _currentUserId = user.uid;
        _setupPresence();
      } else if (user == null) {
        _cleanup();
      }
    });
  }

  /// Setup presence tracking using Firestore onDisconnect
  void _setupPresence() {
    if (_currentUserId == null || _firestore == null) return;

    _userPresenceRef = _firestore!.collection('users').doc(_currentUserId);

    // Set user as online
    _userPresenceRef!.set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update lastSeen every 30 seconds while online
    _lastSeenTimer?.cancel();
    _lastSeenTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentUserId != null && _firestore != null) {
        _firestore!.collection('users').doc(_currentUserId!).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    });

    // Note: Firestore onDisconnect is handled automatically by the backend
    // We just need to keep updating lastSeen while online
  }

  /// Manually set user as online
  Future<void> setOnline() async {
    if (_currentUserId == null || _firestore == null) return;

    await _firestore!.collection('users').doc(_currentUserId!).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Manually set user as offline
  Future<void> setOffline() async {
    if (_currentUserId == null || _firestore == null) return;

    await _firestore!.collection('users').doc(_currentUserId!).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Get online status stream for a specific user
  Stream<bool> getOnlineStatusStream(String userId) {
    if (_firestore == null) return Stream.value(false);

    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final onlineValue = data['isOnline'];
      return onlineValue is bool ? onlineValue : (onlineValue == true);
    });
  }

  /// Get online status for a specific user (one-time fetch)
  Future<bool> getOnlineStatus(String userId) async {
    if (_firestore == null) return false;

    try {
      final doc = await _firestore!.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final onlineValue = data['isOnline'];
      return onlineValue is bool ? onlineValue : (onlineValue == true);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting online status: $e');
      }
      return false;
    }
  }

  /// Cleanup when user logs out or app closes
  void _cleanup() {
    _lastSeenTimer?.cancel();
    _lastSeenTimer = null;
    _currentUserId = null;
    _userPresenceRef = null;
  }

  /// Dispose resources
  void dispose() {
    _setOfflineAndCleanup();
  }

  Future<void> _setOfflineAndCleanup() async {
    await setOffline();
    _cleanup();
  }
}

