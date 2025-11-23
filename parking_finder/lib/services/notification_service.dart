import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<AppNotification> _notifications = [];
  final FToast _toast = FToast();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  int get unreadCount => unreadNotifications.length;

  void initialize(BuildContext context) {
    _toast.init(context);
  }

  // Show toast notification
  void showToast({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.medium,
    Duration duration = const Duration(seconds: 3),
  }) {
    _toast.showToast(
      child: _buildToastWidget(title, message, type, priority),
      toastDuration: duration,
      gravity: ToastGravity.TOP,
    );
  }

  // Show snackbar notification
  void showSnackbar({
    required BuildContext context,
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.medium,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final color = priority == NotificationPriority.high 
        ? Colors.red 
        : priority == NotificationPriority.medium 
            ? Colors.orange 
            : Colors.grey;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(type),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: color,
        duration: duration,
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show dialog notification
  void showAlertDialog({
    required BuildContext context,
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.medium,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    final color = _getColorForPriority(priority);

    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                _getIconForType(type),
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: actions ?? [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Add notification to list
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    
    // Keep only last 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
  }

  // Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  // Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
  }

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
  }

  // Clear read notifications
  void clearReadNotifications() {
    _notifications.removeWhere((n) => n.isRead);
  }

  // Show booking confirmation
  void showBookingConfirmation({
    required BuildContext context,
    required String bookingId,
    required String parkingName,
    required DateTime bookingTime,
    required int duration,
  }) {
    showAlertDialog(
      context: context,
      title: 'Booking Berhasil!',
      message: 'Booking tempat parkir di $parkingName telah dikonfirmasi.\n\n'
          'Kode Booking: $bookingId\n'
          'Waktu: ${bookingTime.day}/${bookingTime.month}/${bookingTime.year} ${bookingTime.hour}:${bookingTime.minute.toString().padLeft(2, '0')}\n'
          'Durasi: $duration jam',
      type: NotificationType.bookingConfirmation,
      priority: NotificationPriority.high,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Lihat Detail'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  // Show parking availability alert
  void showParkingAvailabilityAlert({
    required BuildContext context,
    required String parkingName,
    required int availableSpots,
  }) {
    showSnackbar(
      context: context,
      title: 'Tempat Parkir Tersedia',
      message: '$parkingName kini memiliki $availableSpots tempat kosong',
      type: NotificationType.parkingAvailable,
      priority: NotificationPriority.medium,
      actionLabel: 'Lihat',
      onAction: () {
        // Navigate to parking details
      },
    );
  }

  // Show booking reminder
  void showBookingReminder({
    required BuildContext context,
    required String parkingName,
    required DateTime bookingTime,
  }) {
    final now = DateTime.now();
    final timeUntilBooking = bookingTime.difference(now);
    final minutesUntil = timeUntilBooking.inMinutes;

    showToast(
      title: 'Pengingat Booking',
      message: 'Booking Anda di $parkingName akan dimulai dalam $minutesUntil menit',
      type: NotificationType.bookingReminder,
      priority: NotificationPriority.high,
      duration: const Duration(seconds: 5),
    );
  }

  // Private helper methods
  Widget _buildToastWidget(String title, String message, NotificationType type, NotificationPriority priority) {
    final color = _getColorForPriority(priority);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForType(type),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForType(NotificationType type) {
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

  Color _getColorForPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.medium:
        return Colors.orange;
      case NotificationPriority.high:
        return Colors.red;
    }
  }
}