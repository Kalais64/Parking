import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart' hide MapController;
import 'package:latlong2/latlong.dart' as latlong;
import '../constants/app_colors.dart';
import '../models/parking_location.dart';
import '../controllers/map_controller.dart' as app_controller;

class MapViewWeb extends StatefulWidget {
  const MapViewWeb({super.key});

  @override
  State<MapViewWeb> createState() => _MapViewWebState();
}

class _MapViewWebState extends State<MapViewWeb> {

  @override
  Widget build(BuildContext context) {
    return Consumer<app_controller.MapController>(
      builder: (context, app_controller.MapController controller, child) {
        return Stack(
          children: [
            // Web version - using flutter_map with OpenStreetMap tiles
            FlutterMap(
              options: MapOptions(
                initialCenter: controller.currentPosition != null
                    ? latlong.LatLng(
                        controller.currentPosition!.latitude,
                        controller.currentPosition!.longitude,
                      )
                    : latlong.LatLng(-6.200000, 106.816666), // Jakarta coordinates
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.parkingfinder.app',
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
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                // Parking location markers
                MarkerLayer(
                  markers: controller.parkingLocations.map((parking) {
                    return Marker(
                      point: latlong.LatLng(parking.coordinates.latitude, parking.coordinates.longitude),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => controller.selectParking(parking),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getStatusColor(parking.status).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_parking,
                                  color: _getStatusColor(parking.status),
                                  size: 24,
                                ),
                                Text(
                                  '${parking.availableSpots}/${parking.totalCapacity}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(parking.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Tracking path
                if (controller.trackingPath.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: controller.trackingPath
                            .map((latLng) => latlong.LatLng(latLng.latitude, latLng.longitude))
                            .toList(),
                        strokeWidth: 4.0,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                // Navigation route
                if (controller.navigationRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: controller.navigationRoute
                            .map((latLng) => latlong.LatLng(latLng.latitude, latLng.longitude))
                            .toList(),
                        strokeWidth: 6.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
              ],
            ),

            // Loading indicator
            if (controller.isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),

            // Error message
            if (controller.error != null)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red.shade700),
                          onPressed: () => controller.clearSelectedParking(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Map controls
            Positioned(
              top: 50,
              right: 16,
              child: Column(
                children: [
                  // Tracking button
                  FloatingActionButton(
                    heroTag: 'tracking',
                    mini: true,
                    backgroundColor: controller.isTracking ? AppColors.primary : Colors.white,
                    onPressed: () {
                      if (controller.isTracking) {
                        controller.stopTracking();
                      } else {
                        controller.startTracking();
                      }
                    },
                    child: Icon(
                      controller.isTracking ? Icons.stop : Icons.my_location,
                      color: controller.isTracking ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Traffic button
                  FloatingActionButton(
                    heroTag: 'traffic',
                    mini: true,
                    backgroundColor: controller.showTraffic ? AppColors.primary : Colors.white,
                    onPressed: controller.toggleTraffic,
                    child: Icon(
                      Icons.traffic,
                      color: controller.showTraffic ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Refresh button
                  FloatingActionButton(
                    heroTag: 'refresh',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: controller.refreshParkingData,
                    child: const Icon(Icons.refresh, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            // Quick actions panel
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: controller.findNearbyParking,
                          icon: const Icon(Icons.search),
                          label: const Text('Cari Terdekat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.clearNavigation,
                          icon: const Icon(Icons.clear),
                          label: const Text('Bersihkan'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Selected parking info
            if (controller.selectedParking != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildSelectedParkingCard(controller.selectedParking!, controller),
              ),
          ],
        );
      },
    );
  }

  Widget _buildParkingList(app_controller.MapController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            'Lokasi Parkir Terdekat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: controller.parkingLocations.length,
              itemBuilder: (context, index) {
                final parking = controller.parkingLocations[index];
                return _buildParkingCard(parking, controller);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCard(ParkingLocation parking, app_controller.MapController controller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => controller.selectParking(parking),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(parking.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              
              // Parking info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parking.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parking.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${parking.walkingTime} menit'),
                        const SizedBox(width: 16),
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(parking.formattedDistance),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    parking.formattedPrice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(parking.status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      parking.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedParkingCard(ParkingLocation parking, app_controller.MapController controller) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    parking.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => controller.clearSelectedParking(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              parking.address,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${parking.walkingTime} menit'),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(parking.formattedDistance),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(parking.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    parking.statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(parking.formattedPrice),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToParking(parking, controller),
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showParkingDetails(parking),
                    child: const Text('Detail'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ParkingStatus status) {
    switch (status) {
      case ParkingStatus.available:
        return Colors.green;
      case ParkingStatus.gettingFull:
        return Colors.yellow.shade700;
      case ParkingStatus.full:
        return Colors.red;
    }
  }

  void _navigateToParking(ParkingLocation parking, app_controller.MapController controller) {
    // Start navigation using the map controller
    controller.startNavigationToParking(parking);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigasi ke ${parking.name}')),
    );
  }

  void _showParkingDetails(ParkingLocation parking) {
    // This would navigate to detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menampilkan detail ${parking.name}')),
    );
  }
}