import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/parking_location.dart';
import '../services/notification_service.dart';

class BookingService extends ChangeNotifier {
  final List<Booking> _bookings = [];
  final NotificationService _notificationService = NotificationService();
  
  List<Booking> get bookings => List.unmodifiable(_bookings);
  List<Booking> get activeBookings => 
      _bookings.where((b) => b.status == BookingStatus.active || 
                            b.status == BookingStatus.confirmed ||
                            b.status == BookingStatus.pending).toList();
  
  List<Booking> get completedBookings => 
      _bookings.where((b) => b.status == BookingStatus.completed).toList();

  // Create a new booking
  Future<Booking> createBooking({
    required String userId,
    required ParkingLocation parkingLocation,
    required String parkingSpotId,
    required DateTime bookingTime,
    required int durationHours,
    String? vehiclePlateNumber,
    String? vehicleType,
    String? notes,
  }) async {
    // Validate booking time
    if (bookingTime.isBefore(DateTime.now())) {
      throw Exception('Waktu booking tidak valid');
    }

    // Check if parking location has available spots
    if (parkingLocation.availableSpots <= 0) {
      throw Exception('Tempat parkir penuh');
    }

    // Calculate total price
    final totalPrice = parkingLocation.pricePerHour * durationHours;

    // Create booking
    final booking = Booking(
      id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      parkingLocationId: parkingLocation.id,
      parkingSpotId: parkingSpotId,
      bookingTime: bookingTime,
      durationHours: durationHours,
      totalPrice: totalPrice,
      status: BookingStatus.pending,
      vehiclePlateNumber: vehiclePlateNumber,
      vehicleType: vehicleType,
      notes: notes,
      createdAt: DateTime.now(),
    );

    _bookings.add(booking);
    notifyListeners();

    // Schedule booking reminder
    _scheduleBookingReminder(booking, parkingLocation.name);

    return booking;
  }

  // Confirm a booking
  Future<void> confirmBooking(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking tidak ditemukan');
    }

    final booking = _bookings[index];
    if (booking.status != BookingStatus.pending) {
      throw Exception('Booking tidak dapat dikonfirmasi');
    }

    _bookings[index] = booking.copyWith(status: BookingStatus.confirmed);
    notifyListeners();

    // Show confirmation notification
    _notificationService.showBookingConfirmation(
      context: _getContext(),
      bookingId: bookingId,
      parkingName: 'Tempat Parkir ${booking.id}',
      bookingTime: booking.bookingTime,
      duration: booking.durationHours,
    );
  }

  // Check in for a booking
  Future<void> checkIn(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking tidak ditemukan');
    }

    final booking = _bookings[index];
    if (booking.status != BookingStatus.confirmed) {
      throw Exception('Booking belum dikonfirmasi');
    }

    _bookings[index] = booking.copyWith(
      status: BookingStatus.active,
      checkInTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Check out for a booking
  Future<void> checkOut(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking tidak ditemukan');
    }

    final booking = _bookings[index];
    if (booking.status != BookingStatus.active) {
      throw Exception('Booking tidak aktif');
    }

    _bookings[index] = booking.copyWith(
      status: BookingStatus.completed,
      checkOutTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Cancel a booking
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking tidak ditemukan');
    }

    final booking = _bookings[index];
    if (booking.status == BookingStatus.completed || 
        booking.status == BookingStatus.cancelled) {
      throw Exception('Booking tidak dapat dibatalkan');
    }

    _bookings[index] = booking.copyWith(
      status: BookingStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Extend booking duration
  Future<void> extendBooking(String bookingId, int additionalHours) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking tidak ditemukan');
    }

    final booking = _bookings[index];
    if (booking.status != BookingStatus.active) {
      throw Exception('Hanya booking aktif yang dapat diperpanjang');
    }

    _bookings[index] = booking.copyWith(
      durationHours: booking.durationHours + additionalHours,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Get booking by ID
  Booking? getBooking(String bookingId) {
    try {
      return _bookings.firstWhere((b) => b.id == bookingId);
    } catch (e) {
      return null;
    }
  }

  // Get active booking for a parking location
  Booking? getActiveBookingForLocation(String parkingLocationId) {
    try {
      return activeBookings.firstWhere((b) => b.parkingLocationId == parkingLocationId);
    } catch (e) {
      return null;
    }
  }

  // Check if user has active booking
  bool hasActiveBooking(String userId) {
    return activeBookings.any((b) => b.userId == userId);
  }

  // Get upcoming bookings (bookings starting in the next 24 hours)
  List<Booking> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    
    return _bookings.where((b) => 
      b.userId == userId &&
      b.status == BookingStatus.confirmed &&
      b.bookingTime.isAfter(now) &&
      b.bookingTime.isBefore(tomorrow)
    ).toList();
  }

  // Private methods
  BuildContext _getContext() {
    // This is a simplified approach - in a real app, you'd want to pass the context properly
    return _bookings.isNotEmpty ? _bookings.first as dynamic : null;
  }

  void _scheduleBookingReminder(Booking booking, String parkingName) {
    final reminderTime = booking.bookingTime.subtract(const Duration(minutes: 15));
    final delay = reminderTime.difference(DateTime.now());

    if (delay.inMilliseconds > 0) {
      Timer(delay, () {
        if (booking.status == BookingStatus.confirmed) {
          _notificationService.showBookingReminder(
            context: _getContext(),
            parkingName: parkingName,
            bookingTime: booking.bookingTime,
          );
        }
      });
    }
  }

  // Check and update expired bookings
  void _checkExpiredBookings() {
    final now = DateTime.now();
    
    for (int i = 0; i < _bookings.length; i++) {
      final booking = _bookings[i];
      
      if (booking.status == BookingStatus.active && booking.checkInTime != null) {
        final endTime = booking.checkInTime!.add(Duration(hours: booking.durationHours));
        
        if (now.isAfter(endTime)) {
          _bookings[i] = booking.copyWith(
            status: BookingStatus.completed,
            checkOutTime: endTime,
            updatedAt: now,
          );
        }
      }
      
      if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed) {
        if (booking.bookingTime.isBefore(now.subtract(const Duration(hours: 1)))) {
          _bookings[i] = booking.copyWith(
            status: BookingStatus.expired,
            updatedAt: now,
          );
        }
      }
    }
    
    notifyListeners();
  }

  // Start periodic cleanup
  void startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _checkExpiredBookings();
    });
  }
}