import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) => fb.FirebaseAuth.instance);

/// Provider for online status stream of a specific user
final onlineStatusStreamProvider = StreamProvider.family<bool, String>(
  (ref, userId) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
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
  },
);

// Typing status stream provider
final typingStatusStreamProvider = StreamProvider.family<Map<String, bool>, String>(
  (ref, chatId) {
    final dataSource = ref.watch(firestoreChatDataSourceProvider);
    return dataSource.getTypingStatusStream(chatId);
  },
);

/// Provider to get online status for current user
final currentUserOnlineStatusProvider = StreamProvider<bool>(
  (ref) {
    final auth = ref.watch(firebaseAuthProvider);
    final userId = auth.currentUser?.uid;
    
    if (userId == null) {
      return Stream.value(false);
    }
    
    final onlineStatusStream = ref.watch(onlineStatusStreamProvider(userId));
    return onlineStatusStream.when(
      data: (status) => Stream.value(status),
      loading: () => Stream.value(false),
      error: (_, __) => Stream.value(false),
    );
  },
);

