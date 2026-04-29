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
        return const Color(0xFF1A1A1A);
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

  /// Parse backend (Rust) JSON shape — snake_case fields, ISO-8601 timestamps.
  factory NotificationModel.fromBackendJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      type: _typeFromString((json['notification_type'] ?? 'bookingSuccess').toString()),
      timestamp: _parseTimestamp(json['created_at']),
      isRead: json['is_read'] == true,
      imageUrl: json['image_url']?.toString(),
      data: json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null,
    );
  }

  /// Parse an ISO-8601 timestamp from the backend.
  ///
  /// Rust's `chrono::NaiveDateTime` serializes without a timezone suffix even
  /// though the values are UTC. Dart's `DateTime.parse` treats no-offset
  /// strings as LOCAL, which leaves Lagos users 1 hour behind. Force UTC
  /// when no offset is present, then convert to local.
  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.now();
    final s = raw.toString();
    final hasOffset = s.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    final normalized = hasOffset ? s : '${s}Z';
    return (DateTime.tryParse(normalized) ?? DateTime.now()).toLocal();
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'bookingSuccess':
      case 'booking_success':
        return NotificationType.bookingSuccess;
      case 'payment':
        return NotificationType.payment;
      case 'pickupDropoff':
      case 'pickup_dropoff':
        return NotificationType.pickupDropoff;
      case 'lateReturn':
      case 'late_return':
        return NotificationType.lateReturn;
      case 'cancellation':
        return NotificationType.cancellation;
      case 'discount':
        return NotificationType.discount;
      default:
        return NotificationType.bookingSuccess;
    }
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

