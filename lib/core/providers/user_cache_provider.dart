import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';

/// Cache for user data to avoid repeated API queries
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

/// Stream provider for user data - fetches from API with caching
final userDataStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) async* {
  final cache = ref.watch(userCacheProvider);
  final cachedData = cache.get(userId);
  if (cachedData != null) {
    yield cachedData;
    return;
  }

  // Fetch from API
  try {
    final api = ApiClient();
    final response = await api.get('/users/$userId', auth: false);
    if (response.isSuccess) {
      final data = response.body as Map<String, dynamic>;
      final userData = {
        'profileImageUrl': data['profile_photo_url'] ?? '',
        'fullName': data['full_name'] ?? '',
        'role': data['role'] ?? '',
      };
      cache.set(userId, userData);
      yield userData;
    } else {
      yield null;
    }
  } catch (e) {
    debugPrint('[Qent UserCache] Error fetching user $userId: $e');
    yield null;
  }
});

/// One-time fetch provider for user data
final userDataProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final cache = ref.read(userCacheProvider);
  final cachedData = cache.get(userId);
  if (cachedData != null) {
    return cachedData;
  }

  try {
    final api = ApiClient();
    final response = await api.get('/users/$userId', auth: false);
    if (response.isSuccess) {
      final data = response.body as Map<String, dynamic>;
      final userData = {
        'profileImageUrl': data['profile_photo_url'] ?? '',
        'fullName': data['full_name'] ?? '',
        'role': data['role'] ?? '',
      };
      cache.set(userId, userData);
      return userData;
    }
  } catch (e) {
    debugPrint('[Qent UserCache] Error fetching user $userId: $e');
  }
  return null;
});
