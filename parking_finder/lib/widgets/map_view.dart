import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/map_controller.dart';
import '../constants/app_colors.dart';
import '../models/parking_location.dart';
import '../controllers/parking_detection_controller.dart';
import '../screens/simulation/parking_simulation_screen.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapController _controller;
  bool _isAddMode = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<MapController>(
        builder: (context, controller, child) {
          return Stack(
            children: [
              HeroMode(
                enabled: false,
                child: GoogleMap(
                  onMapCreated: controller.onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-6.2088, 106.8456), // Jakarta
                    zoom: 15.0,
                  ),
                  markers: controller.markers,
                  circles: controller.circles,
                  polylines: controller.polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: controller.showTraffic,
                  mapType: controller.showSatellite ? MapType.satellite : MapType.normal,
                  onCameraMove: controller.onCameraMove,
                  onTap: (pos) {
                    if (_isAddMode) {
                      setState(() { _isAddMode = false; });
                      _showAddLocationAt(pos, controller);
                    }
                  },
                  padding: const EdgeInsets.only(top: 100, bottom: 150),
                ),
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
                    FloatingActionButton(
                      heroTag: 'add_location',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () {
                        setState(() { _isAddMode = true; });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tap peta untuk pilih titik lokasi baru')),
                        );
                      },
                      child: const Icon(Icons.add_location_alt, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    // Tracking button
                    FloatingActionButton(
                      heroTag: 'tracking',
                      mini: true,
                      backgroundColor: controller.isTracking ? Colors.red : Colors.white,
                      onPressed: () {
                        if (controller.isTracking) {
                          controller.stopTracking();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pelacakan dihentikan')),
                          );
                        } else {
                          controller.startTracking();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pelacakan dimulai')),
                          );
                        }
                      },
                      child: Icon(
                        controller.isTracking ? Icons.stop : Icons.route,
                        color: controller.isTracking ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Current location button
                    FloatingActionButton(
                      heroTag: 'current_location',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: controller.moveToCurrentLocation,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    // Map type toggle
                    FloatingActionButton(
                      heroTag: 'map_type',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: controller.toggleMapType,
                      child: Icon(
                        controller.showSatellite ? Icons.map : Icons.satellite,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Traffic toggle
                    FloatingActionButton(
                      heroTag: 'traffic',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: controller.toggleTraffic,
                      child: Icon(
                        controller.showTraffic ? Icons.traffic : Icons.traffic_outlined,
                        color: AppColors.primary,
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

              // Legend
              Positioned(
                bottom: 180,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Status Parkir',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildLegendItem(Colors.green, 'Banyak kosong'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.yellow, 'Mulai penuh'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.red, 'Penuh'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick Actions Panel
              Positioned(
                bottom: 280,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Aksi Cepat',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final nearestParking = controller.findNearestParking(1);
                                  if (nearestParking.isNotEmpty) {
                                    controller.selectParking(nearestParking.first);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Menampilkan parkir terdekat: ${nearestParking.first.name}')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Tidak ada parkir terdekat')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.near_me, size: 16),
                                label: const Text('Terdekat'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  backgroundColor: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final availableParking = controller.parkingLocations
                                      .where((p) => p.status == ParkingStatus.available)
                                      .toList();
                                  if (availableParking.isNotEmpty) {
                                    controller.selectParking(availableParking.first);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Menampilkan parkir tersedia: ${availableParking.first.name}')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Tidak ada parkir yang tersedia')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Tersedia'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  controller.startParkingAvailabilityTracking();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Pelacakan ketersediaan dimulai')),
                                  );
                                },
                                icon: const Icon(Icons.notifications, size: 16),
                                label: const Text('Notifikasi'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  controller.clearNavigation();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Navigasi dibersihkan')),
                                  );
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Bersihkan'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
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
                  child: _buildSelectedParkingCard(controller, controller.selectedParking!),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddLocationAt(LatLng pos, MapController map) async {
    final det = context.read<ParkingDetectionController>();
    _nameController.text = '';
    _addressController.text = '';
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tambah Lokasi Parkir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lokasi'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                final name = _nameController.text.trim();
                final address = _addressController.text.trim();
                final total = det.totalSlots;
                final empty = det.emptySlots;
                final status = empty == 0
                    ? ParkingStatus.full
                    : (empty < (total * 0.2))
                        ? ParkingStatus.gettingFull
                        : ParkingStatus.available;
                final loc = ParkingLocation(
                  id: id,
                  name: name.isEmpty ? 'Lokasi Baru' : name,
                  address: address.isEmpty ? 'Belum ada alamat' : address,
                  coordinates: pos,
                  status: status,
                  totalCapacity: total,
                  availableSpots: empty,
                  pricePerHour: 5000,
                  vehicleType: 'both',
                  parkingType: 'both',
                  securityLevel: 'medium',
                  hasCctv: true,
                  isWellLit: true,
                  lastUpdated: DateTime.now(),
                );
                map.addOrUpdateParkingLocation(loc);
                map.selectParking(loc);
                Navigator.of(ctx).pop();
              },
              child: const Text('Simpan'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                final name = _nameController.text.trim();
                final address = _addressController.text.trim();
                final loc = ParkingLocation(
                  id: id,
                  name: name.isEmpty ? 'Lokasi Baru' : name,
                  address: address.isEmpty ? 'Belum ada alamat' : address,
                  coordinates: pos,
                  status: ParkingStatus.available,
                  totalCapacity: 0,
                  availableSpots: 0,
                  pricePerHour: 5000,
                  vehicleType: 'both',
                  parkingType: 'both',
                  securityLevel: 'medium',
                  hasCctv: true,
                  isWellLit: true,
                  lastUpdated: DateTime.now(),
                );
                map.addOrUpdateParkingLocation(loc);
                map.selectParking(loc);
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ParkingSimulationScreen()),
                );
              },
              child: const Text('Scan via Kamera'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSelectedParkingCard(MapController controller, ParkingLocation parking) {
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
                    onPressed: () => _navigateToParkingWithDirections(controller, parking),
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final det = context.read<ParkingDetectionController>();
                      final total = det.totalSlots;
                      final empty = det.emptySlots;
                      final status = empty == 0
                          ? ParkingStatus.full
                          : (empty < (total * 0.2))
                              ? ParkingStatus.gettingFull
                              : ParkingStatus.available;
                      final updated = parking.copyWith(
                        totalCapacity: total,
                        availableSpots: empty,
                        status: status,
                        lastUpdated: DateTime.now(),
                      );
                      controller.addOrUpdateParkingLocation(updated);
                      controller.selectParking(updated);
                    },
                    icon: const Icon(Icons.update),
                    label: const Text('Update Data'),
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
            if (controller.currentRoute.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => controller.clearNavigationRoute(),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Hapus Rute'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

  void _navigateToParkingWithDirections(MapController controller, ParkingLocation parking) {
    // Use the enhanced navigation with directions
    controller.navigateToParkingWithDirections(parking);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Membuat rute ke ${parking.name}...')),
    );
  }

  void _showParkingDetails(ParkingLocation parking) {
    // This would navigate to detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menampilkan detail ${parking.name}')),
    );
  }
}