import 'package:flutter/material.dart';

enum NotificationType {
  bookingConfirmation,
  bookingReminder,
  parkingFull,
  parkingAvailable,
  promotion,
  system,
}

enum NotificationPriority {
  low,
  medium,
  high,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;
  final IconData? icon;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.isRead = false,
    this.data,
    this.icon,
  });

  // Get icon based on notification type
  IconData get iconData {
    if (icon != null) return icon!;
    
    switch (type) {
      case NotificationType.bookingConfirmation:
        return Icons.confirmation_number;
      case NotificationType.bookingReminder:
        return Icons.access_time;
      case NotificationType.parkingFull:
        return Icons.local_parking;
      case NotificationType.parkingAvailable:
        return Icons.directions_car;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  // Get color based on priority
  Color get color {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.medium:
        return Colors.orange;
      case NotificationPriority.high:
        return Colors.red;
    }
  }

  // Copy with method
  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
    IconData? icon,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      icon: icon ?? this.icon,
    );
  }
}