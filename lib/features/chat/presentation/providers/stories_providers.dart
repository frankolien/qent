import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';

class StoryData {
  final String id;
  final String hostId;
  final String? carId;
  final String imageUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String hostName;
  final String hostPhoto;

  StoryData({
    required this.id,
    required this.hostId,
    this.carId,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.hostName,
    required this.hostPhoto,
  });

  factory StoryData.fromJson(Map<String, dynamic> json) {
    return StoryData(
      id: (json['id'] ?? '').toString(),
      hostId: (json['host_id'] ?? '').toString(),
      carId: json['car_id']?.toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ?? DateTime.now(),
      hostName: (json['host_name'] ?? '').toString(),
      hostPhoto: (json['host_photo'] ?? '').toString(),
    );
  }
}

/// Grouped stories by host
class HostStoryGroup {
  final String hostId;
  final String hostName;
  final String hostPhoto;
  final List<StoryData> stories;

  HostStoryGroup({
    required this.hostId,
    required this.hostName,
    required this.hostPhoto,
    required this.stories,
  });
}

final storiesProvider = FutureProvider<List<HostStoryGroup>>((ref) async {
  final api = ApiClient();
  final response = await api.get('/stories');

  if (!response.isSuccess) {
    debugPrint('[Qent Stories] Error: ${response.errorMessage}');
    return [];
  }

  final list = response.body as List<dynamic>;
  final stories = list
      .map((item) => StoryData.fromJson(item as Map<String, dynamic>))
      .toList();

  // Group by host
  final Map<String, HostStoryGroup> grouped = {};
  for (final story in stories) {
    if (grouped.containsKey(story.hostId)) {
      grouped[story.hostId]!.stories.add(story);
    } else {
      grouped[story.hostId] = HostStoryGroup(
        hostId: story.hostId,
        hostName: story.hostName,
        hostPhoto: story.hostPhoto,
        stories: [story],
      );
    }
  }

  return grouped.values.toList();
});
