import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

/// Cache for user data to avoid repeated Firestore queries
class UserCache {
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Map<String, dynamic>? get(String userId) {
    final timestamp = _cacheTimestamps[userId];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(userId);
      _cacheTimestamps.remove(userId);
      return null;
    }
    
    return _cache[userId];
  }

  void set(String userId, Map<String, dynamic> data) {
    _cache[userId] = data;
    _cacheTimestamps[userId] = DateTime.now();
  }

  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  void remove(String userId) {
    _cache.remove(userId);
    _cacheTimestamps.remove(userId);
  }
}

final userCacheProvider = Provider<UserCache>((ref) => UserCache());

/// Stream provider for user data with caching
final userDataStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(userCacheProvider);
  
  // Check cache first
  final cachedData = cache.get(userId);
  if (cachedData != null) {
    // Return cached data immediately, then update from stream
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        cache.set(userId, data);
        return data;
      }
      return null;
    });
  }
  
  // If not cached, fetch from Firestore and cache
  return firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data() ?? {};
      cache.set(userId, data);
      return data;
    }
    return null;
  });
});

/// One-time fetch provider for user data with caching
final userDataProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final firestore = ref.read(firestoreProvider);
  final cache = ref.read(userCacheProvider);
  
  // Check cache first
  final cachedData = cache.get(userId);
  if (cachedData != null) {
    return cachedData;
  }
  
  // Fetch from Firestore
  try {
    final doc = await firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      cache.set(userId, data);
      return data;
    }
  } catch (e) {
    // Return null on error, but don't cache errors
  }
  
  return null;
});

