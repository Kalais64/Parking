import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ParkingStatus {
  available,
  gettingFull,
  full,
}

class ParkingLocation {
  final String id;
  final String name;
  final String address;
  final LatLng coordinates;
  final ParkingStatus status;
  final int totalCapacity;
  final int availableSpots;
  final double pricePerHour;
  final String? pricePerDay;
  final String vehicleType; // 'motor', 'mobil', 'both'
  final String parkingType; // 'indoor', 'outdoor', 'both'
  final String securityLevel; // 'high', 'medium', 'low'
  final bool hasCctv;
  final bool isWellLit;
  final String? openingHours;
  final String? phoneNumber;
  final double? distance; // in meters
  final int? walkingTime; // in minutes
  final List<String>? photos;
  final double? rating;
  final int? reviewCount;
  final bool isFavorite;
  final DateTime? lastUpdated;

  ParkingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinates,
    required this.status,
    required this.totalCapacity,
    required this.availableSpots,
    required this.pricePerHour,
    this.pricePerDay,
    required this.vehicleType,
    required this.parkingType,
    required this.securityLevel,
    required this.hasCctv,
    required this.isWellLit,
    this.openingHours,
    this.phoneNumber,
    this.distance,
    this.walkingTime,
    this.photos,
    this.rating,
    this.reviewCount,
    this.isFavorite = false,
    this.lastUpdated,
  });

  // Get status color based on availability
  String get statusText {
    switch (status) {
      case ParkingStatus.available:
        return 'Banyak kosong';
      case ParkingStatus.gettingFull:
        return 'Mulai penuh';
      case ParkingStatus.full:
        return 'Penuh';
    }
  }

  // Get status color
  String get statusColor {
    switch (status) {
      case ParkingStatus.available:
        return 'green';
      case ParkingStatus.gettingFull:
        return 'yellow';
      case ParkingStatus.full:
        return 'red';
    }
  }

  // Check if parking is available for specific vehicle type
  bool isAvailableFor(String vehicle) {
    if (status == ParkingStatus.full) return false;
    if (vehicleType == 'both') return true;
    return vehicleType == vehicle;
  }

  // Get formatted price
  String get formattedPrice {
    if (pricePerDay != null) {
      return 'Rp ${pricePerHour.toInt()}/jam atau Rp $pricePerDay/hari';
    }
    return 'Rp ${pricePerHour.toInt()}/jam';
  }

  // Get formatted distance
  String get formattedDistance {
    if (distance == null) return '';
    if (distance! < 1000) {
      return '${distance!.toInt()} m';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)} km';
    }
  }

  // Get occupancy percentage
  double get occupancyPercentage {
    if (totalCapacity == 0) return 0;
    return ((totalCapacity - availableSpots) / totalCapacity) * 100;
  }

  // Copy with method for updates
  ParkingLocation copyWith({
    String? id,
    String? name,
    String? address,
    LatLng? coordinates,
    ParkingStatus? status,
    int? totalCapacity,
    int? availableSpots,
    double? pricePerHour,
    String? pricePerDay,
    String? vehicleType,
    String? parkingType,
    String? securityLevel,
    bool? hasCctv,
    bool? isWellLit,
    String? openingHours,
    String? phoneNumber,
    double? distance,
    int? walkingTime,
    List<String>? photos,
    double? rating,
    int? reviewCount,
    bool? isFavorite,
    DateTime? lastUpdated,
  }) {
    return ParkingLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      coordinates: coordinates ?? this.coordinates,
      status: status ?? this.status,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      availableSpots: availableSpots ?? this.availableSpots,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      vehicleType: vehicleType ?? this.vehicleType,
      parkingType: parkingType ?? this.parkingType,
      securityLevel: securityLevel ?? this.securityLevel,
      hasCctv: hasCctv ?? this.hasCctv,
      isWellLit: isWellLit ?? this.isWellLit,
      openingHours: openingHours ?? this.openingHours,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      distance: distance ?? this.distance,
      walkingTime: walkingTime ?? this.walkingTime,
      photos: photos ?? this.photos,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}