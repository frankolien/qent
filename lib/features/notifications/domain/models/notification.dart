import 'package:flutter/material.dart';

enum NotificationType {
  bookingSuccess,
  payment,
  pickupDropoff,
  lateReturn,
  cancellation,
  discount,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.data,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.bookingSuccess:
        return Icons.check_circle;
      case NotificationType.payment:
        return Icons.receipt;
      case NotificationType.pickupDropoff:
        return Icons.schedule;
      case NotificationType.lateReturn:
        return Icons.warning;
      case NotificationType.cancellation:
        return Icons.cancel;
      case NotificationType.discount:
        return Icons.local_offer;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.bookingSuccess:
        return Colors.green;
      case NotificationType.payment:
        return Colors.blue;
      case NotificationType.pickupDropoff:
        return Colors.orange;
      case NotificationType.lateReturn:
        return Colors.red;
      case NotificationType.cancellation:
        return Colors.red;
      case NotificationType.discount:
        return Colors.purple;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      final hours = timestamp.hour;
      final minutes = timestamp.minute;
      final amPm = hours >= 12 ? 'pm' : 'am';
      final hour12 = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
      return '${hour12.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $amPm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
    );
  }
}

