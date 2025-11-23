import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import '../controllers/map_controller.dart' as app_controller;
import '../constants/app_colors_new.dart';
import '../models/parking_location.dart';

class MapViewOSM extends StatefulWidget {
  const MapViewOSM({super.key});

  @override
  State<MapViewOSM> createState() => _MapViewOSMState();
}

class _MapViewOSMState extends State<MapViewOSM> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<app_controller.MapController>(
      builder: (context, controller, child) {
        return Scaffold(
            backgroundColor: AppColorsNew.background,
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColorsNew.primaryGradient,
              ),
              child: Stack(
                children: [
                  // OSM Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: latlong.LatLng(-6.2088, 106.8456), // Jakarta
                      initialZoom: 15.0,
                      minZoom: 10.0,
                      maxZoom: 20.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.parkingfinder.app',
                      ),
                      // Parking markers
                      MarkerLayer(
                        markers: _buildMarkers(controller),
                      ),
                      // Current location marker
                      if (controller.currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latlong.LatLng(
                                controller.currentPosition!.latitude,
                                controller.currentPosition!.longitude,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColorsNew.accent.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: AppColorsNew.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Header dengan gradient overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColorsNew.background.withValues(alpha: 0.9),
                            AppColorsNew.background.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Park Smarter',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: AppColorsNew.textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'With Our Car Parking App',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: AppColorsNew.textSecondary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColorsNew.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: AppColorsNew.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Distance indicator
                  Positioned(
                    top: 140,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColorsNew.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColorsNew.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColorsNew.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '500m',
                            style: TextStyle(
                              color: AppColorsNew.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating parking card with availability display
                  Positioned(
                    bottom: 120,
                    left: 24,
                    right: 24,
                    child: _buildFloatingParkingCardWithAvailability(controller),
                  ),

                  // Map controls
                  Positioned(
                    bottom: 40,
                    right: 24,
                    child: Column(
                      children: [
                        _buildControlButton(
                          Icons.my_location,
                          onPressed: controller.moveToCurrentLocation,
                        ),
                        const SizedBox(height: 12),
                        _buildControlButton(
                          Icons.layers,
                          onPressed: () {
                            // Toggle map style
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildControlButton(
                          Icons.refresh,
                          onPressed: controller.refreshParkingData,
                        ),
                      ],
                    ),
                  ),

                  // Loading overlay
                  if (controller.isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
    );
  }

  Widget _buildControlButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColorsNew.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColorsNew.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            color: AppColorsNew.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParkingCardWithAvailability(app_controller.MapController controller) {
    if (controller.parkingLocations.isEmpty) return const SizedBox.shrink();
    
    final parking = controller.parkingLocations.first;
    final availabilityText = '${parking.availableSpots}/${parking.totalCapacity}';
    
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          // Main card
          Container(
            margin: const EdgeInsets.only(right: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColorsNew.accentGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColorsNew.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with location icon
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColorsNew.buttonText.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_parking,
                        color: AppColorsNew.buttonText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parking.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColorsNew.buttonText,
                            ),
                          ),
                          Text(
                            parking.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColorsNew.buttonText.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Availability display
                Row(
                  children: [
                    // Availability indicator
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColorsNew.buttonText.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car,
                              size: 16,
                              color: AppColorsNew.buttonText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              availabilityText,
                              style: TextStyle(
                                color: AppColorsNew.buttonText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'tersedia',
                              style: TextStyle(
                                color: AppColorsNew.buttonText.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(parking.status).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(parking.status),
                            size: 16,
                            color: AppColorsNew.buttonText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            parking.statusText,
                            style: TextStyle(
                              color: AppColorsNew.buttonText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                                // Distance and price
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColorsNew.buttonText.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      parking.formattedDistance,
                      style: TextStyle(
                        color: AppColorsNew.buttonText.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Rp ${parking.pricePerHour.toInt()}/jam',
                      style: TextStyle(
                        color: AppColorsNew.buttonText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Floating action button
          Positioned(
            right: 0,
            top: 30,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColorsNew.buttonText,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColorsNew.cardShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showParkingDetails(controller.selectedParking ?? parking, controller),
                  borderRadius: BorderRadius.circular(28),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: AppColorsNew.accent,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(app_controller.MapController controller) {
    return controller.parkingLocations.map((parking) {
      final color = _getMarkerColor(parking.status);
      
      return Marker(
        point: latlong.LatLng(
          parking.coordinates.latitude,
          parking.coordinates.longitude,
        ),
        child: GestureDetector(
          onTap: () => controller.selectParking(parking),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColorsNew.buttonText,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getMarkerColor(ParkingStatus status) {
    switch (status) {
      case ParkingStatus.available:
        return AppColorsNew.available;
      case ParkingStatus.gettingFull:
        return AppColorsNew.gettingFull;
      case ParkingStatus.full:
        return AppColorsNew.full;
    }
  }

  IconData _getStatusIcon(ParkingStatus status) {
    switch (status) {
      case ParkingStatus.available:
        return Icons.check_circle;
      case ParkingStatus.gettingFull:
        return Icons.warning;
      case ParkingStatus.full:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(ParkingStatus status) {
    switch (status) {
      case ParkingStatus.available:
        return AppColorsNew.available;
      case ParkingStatus.gettingFull:
        return AppColorsNew.gettingFull;
      case ParkingStatus.full:
        return AppColorsNew.full;
    }
  }

  void _showParkingDetails(ParkingLocation parking, app_controller.MapController controller) {
    // Show bottom sheet with parking details
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColorsNew.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildParkingDetailsSheet(parking, controller),
    );
  }

  Widget _buildParkingDetailsSheet(ParkingLocation parking, app_controller.MapController controller) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                parking.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColorsNew.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getMarkerColor(parking.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  parking.statusText,
                  style: TextStyle(
                    color: AppColorsNew.buttonText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            parking.address,
            style: TextStyle(
              color: AppColorsNew.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToParking(parking, controller),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorsNew.accent,
                    foregroundColor: AppColorsNew.buttonText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Detail'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToParking(ParkingLocation parking, app_controller.MapController controller) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigasi ke ${parking.name}'),
        backgroundColor: AppColorsNew.accent,
      ),
    );
  }
}
