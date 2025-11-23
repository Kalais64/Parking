import 'parking_location.dart';

class Favorite {
  final String id;
  final String userId;
  final ParkingLocation parkingLocation;
  final DateTime createdAt;
  final String? notes;

  Favorite({
    required this.id,
    required this.userId,
    required this.parkingLocation,
    required this.createdAt,
    this.notes,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'parkingLocation': parkingLocation.id,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  // Create from JSON
  factory Favorite.fromJson(Map<String, dynamic> json, ParkingLocation parkingLocation) {
    return Favorite(
      id: json['id'],
      userId: json['userId'],
      parkingLocation: parkingLocation,
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'],
    );
  }
}