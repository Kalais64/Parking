import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/parking_location.dart';
import '../models/favorite.dart';
import '../models/notification.dart';
import '../models/booking.dart';

class DummyDataService {
  // Enhanced dummy parking locations with detailed data
  static List<ParkingLocation> getEnhancedParkingLocations() {
    return [
      ParkingLocation(
        id: 'parking_001',
        name: '29 Street',
        address: 'Club Town Garden, Jakarta Selatan',
        coordinates: const LatLng(-6.2088, 106.8456),
        status: ParkingStatus.available,
        totalCapacity: 120,
        availableSpots: 45,
        pricePerHour: 5000,
        pricePerDay: '50000',
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        openingHours: '24 jam',
        phoneNumber: '+62 21 12345678',
        photos: [
          'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=400',
          'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=400',
        ],
        rating: 4.5,
        reviewCount: 127,
        isFavorite: true,
        lastUpdated: DateTime.now(),
      ),
      ParkingLocation(
        id: 'parking_002',
        name: 'City Center Mall',
        address: 'Jl. Sudirman No. 45, Jakarta Pusat',
        coordinates: const LatLng(-6.2105, 106.8449),
        status: ParkingStatus.gettingFull,
        totalCapacity: 350,
        availableSpots: 85,
        pricePerHour: 8000,
        pricePerDay: '80000',
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        openingHours: '10:00 - 22:00',
        phoneNumber: '+62 21 87654321',
        photos: [
          'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=400',
          'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=400',
        ],
        rating: 4.3,
        reviewCount: 89,
        isFavorite: false,
        lastUpdated: DateTime.now(),
      ),
      ParkingLocation(
        id: 'parking_003',
        name: 'St Mary Park',
        address: 'Jl. Gatot Subroto Kav. 72, Jakarta',
        coordinates: const LatLng(-6.2075, 106.8475),
        status: ParkingStatus.full,
        totalCapacity: 80,
        availableSpots: 0,
        pricePerHour: 3000,
        pricePerDay: '25000',
        vehicleType: 'both',
        parkingType: 'outdoor',
        securityLevel: 'medium',
        hasCctv: false,
        isWellLit: true,
        openingHours: '06:00 - 22:00',
        phoneNumber: '+62 21 55556666',
        photos: [
          'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=400',
        ],
        rating: 3.8,
        reviewCount: 45,
        isFavorite: true,
        lastUpdated: DateTime.now(),
      ),
      ParkingLocation(
        id: 'parking_004',
        name: 'Business District',
        address: 'Jl. Thamrin No. 12, Jakarta Pusat',
        coordinates: const LatLng(-6.2092, 106.8442),
        status: ParkingStatus.available,
        totalCapacity: 200,
        availableSpots: 67,
        pricePerHour: 6000,
        pricePerDay: '60000',
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        openingHours: '24 jam',
        phoneNumber: '+62 21 77778888',
        photos: [
          'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=400',
          'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=400',
        ],
        rating: 4.6,
        reviewCount: 156,
        isFavorite: false,
        lastUpdated: DateTime.now(),
      ),
      ParkingLocation(
        id: 'parking_005',
        name: 'Grand Plaza',
        address: 'Jl. Rasuna Said Kav. C5, Jakarta',
        coordinates: const LatLng(-6.2085, 106.8465),
        status: ParkingStatus.gettingFull,
        totalCapacity: 250,
        availableSpots: 32,
        pricePerHour: 7500,
        pricePerDay: '75000',
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        openingHours: '10:00 - 22:00',
        phoneNumber: '+62 21 99990000',
        photos: [
          'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=400',
          'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=400',
        ],
        rating: 4.4,
        reviewCount: 203,
        isFavorite: true,
        lastUpdated: DateTime.now(),
      ),
    ];
  }

  // Get dummy favorites
  static List<Favorite> getDummyFavorites(String userId) {
    final parkingLocations = getEnhancedParkingLocations();
    final favoriteParking = parkingLocations.where((p) => p.isFavorite).toList();
    
    return favoriteParking.map((parking) => Favorite(
      id: 'fav_${parking.id}',
      userId: userId,
      parkingLocation: parking,
      createdAt: DateTime.now().subtract(Duration(days: favoriteParking.indexOf(parking) * 2)),
      notes: 'Tempat favorit untuk parkir ${parking.vehicleType == 'both' ? 'semua kendaraan' : parking.vehicleType}',
    )).toList();
  }

  // Get dummy notifications
  static List<AppNotification> getDummyNotifications() {
    return [
      AppNotification(
        id: 'notif_001',
        title: 'Booking Dikonfirmasi',
        message: 'Booking tempat parkir di 29 Street telah dikonfirmasi. Kode booking: PK001',
        type: NotificationType.bookingConfirmation,
        priority: NotificationPriority.high,
        timestamp: DateTime.now().subtract(Duration(minutes: 30)),
        isRead: false,
      ),
      AppNotification(
        id: 'notif_002',
        title: 'Pengingat Booking',
        message: 'Booking Anda di City Center Mall akan dimulai dalam 15 menit',
        type: NotificationType.bookingReminder,
        priority: NotificationPriority.medium,
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif_003',
        title: 'Tempat Parkir Tersedia',
        message: 'St Mary Park kini memiliki 5 tempat kosong',
        type: NotificationType.parkingAvailable,
        priority: NotificationPriority.low,
        timestamp: DateTime.now().subtract(Duration(hours: 5)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif_004',
        title: 'Promo Spesial',
        message: 'Dapatkan diskon 20% untuk booking di Business District hari ini!',
        type: NotificationType.promotion,
        priority: NotificationPriority.medium,
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        isRead: false,
      ),
    ];
  }

  // Get dummy bookings
  static List<Booking> getDummyBookings(String userId) {
    final now = DateTime.now();
    
    return [
      Booking(
        id: 'booking_001',
        userId: userId,
        parkingLocationId: 'parking_001',
        parkingSpotId: 'spot_A12',
        bookingTime: now.add(Duration(hours: 2)),
        durationHours: 3,
        totalPrice: 15000,
        status: BookingStatus.confirmed,
        vehiclePlateNumber: 'B 1234 ABC',
        vehicleType: 'mobil',
        notes: 'Harap datang tepat waktu',
        createdAt: now.subtract(Duration(days: 1)),
      ),
      Booking(
        id: 'booking_002',
        userId: userId,
        parkingLocationId: 'parking_002',
        parkingSpotId: 'spot_B05',
        bookingTime: now.subtract(Duration(hours: 1)),
        checkInTime: now.subtract(Duration(minutes: 30)),
        durationHours: 2,
        totalPrice: 16000,
        status: BookingStatus.active,
        vehiclePlateNumber: 'B 5678 DEF',
        vehicleType: 'mobil',
        notes: '',
        createdAt: now.subtract(Duration(days: 2)),
      ),
      Booking(
        id: 'booking_003',
        userId: userId,
        parkingLocationId: 'parking_004',
        parkingSpotId: 'spot_C18',
        bookingTime: now.subtract(Duration(days: 3)),
        checkInTime: now.subtract(Duration(days: 3)).add(Duration(hours: 1)),
        checkOutTime: now.subtract(Duration(days: 3)).add(Duration(hours: 4)),
        durationHours: 3,
        totalPrice: 18000,
        status: BookingStatus.completed,
        vehiclePlateNumber: 'B 9012 GHI',
        vehicleType: 'mobil',
        notes: 'Parkir untuk meeting kantor',
        createdAt: now.subtract(Duration(days: 4)),
      ),
    ];
  }

  // Get parking availability text
  static String getAvailabilityText(int available, int total) {
    return '$available/$total tersedia';
  }

  // Get availability color based on percentage
  static String getAvailabilityColor(int available, int total) {
    final percentage = available / total;
    if (percentage > 0.5) return 'green';
    if (percentage > 0.2) return 'orange';
    return 'red';
  }
}