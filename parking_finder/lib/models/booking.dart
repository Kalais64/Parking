enum BookingStatus {
  pending,
  confirmed,
  active,
  completed,
  cancelled,
  expired,
}

class Booking {
  final String id;
  final String userId;
  final String parkingLocationId;
  final String parkingSpotId;
  final DateTime bookingTime;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int durationHours;
  final double totalPrice;
  final BookingStatus status;
  final String? vehiclePlateNumber;
  final String? vehicleType;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Booking({
    required this.id,
    required this.userId,
    required this.parkingLocationId,
    required this.parkingSpotId,
    required this.bookingTime,
    this.checkInTime,
    this.checkOutTime,
    required this.durationHours,
    required this.totalPrice,
    required this.status,
    this.vehiclePlateNumber,
    this.vehicleType,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  // Get status text in Indonesian
  String get statusText {
    switch (status) {
      case BookingStatus.pending:
        return 'Menunggu Konfirmasi';
      case BookingStatus.confirmed:
        return 'Terkonfirmasi';
      case BookingStatus.active:
        return 'Aktif';
      case BookingStatus.completed:
        return 'Selesai';
      case BookingStatus.cancelled:
        return 'Dibatalkan';
      case BookingStatus.expired:
        return 'Kadaluarsa';
    }
  }

  // Get status color
  String get statusColor {
    switch (status) {
      case BookingStatus.pending:
        return 'orange';
      case BookingStatus.confirmed:
        return 'blue';
      case BookingStatus.active:
        return 'green';
      case BookingStatus.completed:
        return 'grey';
      case BookingStatus.cancelled:
      case BookingStatus.expired:
        return 'red';
    }
  }

  // Check if booking is still valid
  bool get isValid {
    return status == BookingStatus.pending || 
           status == BookingStatus.confirmed || 
           status == BookingStatus.active;
  }

  // Get remaining time in minutes
  int? get remainingMinutes {
    if (!isValid || checkInTime == null) return null;
    
    final now = DateTime.now();
    final endTime = checkInTime!.add(Duration(hours: durationHours));
    
    if (now.isAfter(endTime)) return 0;
    
    return endTime.difference(now).inMinutes;
  }

  // Get formatted booking time
  String get formattedBookingTime {
    return '${bookingTime.day}/${bookingTime.month}/${bookingTime.year} ${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}';
  }

  // Get formatted duration
  String get formattedDuration {
    if (durationHours < 1) {
      return '${(durationHours * 60).toInt()} menit';
    } else if (durationHours == 1) {
      return '1 jam';
    } else {
      return '$durationHours jam';
    }
  }

  // Copy with method
  Booking copyWith({
    String? id,
    String? userId,
    String? parkingLocationId,
    String? parkingSpotId,
    DateTime? bookingTime,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    int? durationHours,
    double? totalPrice,
    BookingStatus? status,
    String? vehiclePlateNumber,
    String? vehicleType,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parkingLocationId: parkingLocationId ?? this.parkingLocationId,
      parkingSpotId: parkingSpotId ?? this.parkingSpotId,
      bookingTime: bookingTime ?? this.bookingTime,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      durationHours: durationHours ?? this.durationHours,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}