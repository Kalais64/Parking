import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_location.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';
import '../services/dummy_data_service.dart';
import '../services/map_service.dart';
import '../constants/app_constants.dart';

class MapController extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  // Map state
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  
  // Parking locations
  List<ParkingLocation> _parkingLocations = [];
  ParkingLocation? _selectedParking;
  
  // UI state
  bool _isLoading = false;
  String? _error;
  bool _showTraffic = false;
  bool _showSatellite = false;
  double _currentZoom = AppConstants.defaultZoom;
  
  // Tracking state
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final List<LatLng> _trackingPath = [];
  Timer? _trackingTimer;
  
  // Route state
  List<LatLng> _currentRoute = [];
  Set<Polyline> _polylines = {};
  Marker? _destinationMarker;
  
  // Getters
  GoogleMapController? get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  Set<Marker> get markers => _markers;
  Set<Circle> get circles => _circles;
  Set<Polyline> get polylines => _polylines;
  List<ParkingLocation> get parkingLocations => _parkingLocations;
  ParkingLocation? get selectedParking => _selectedParking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showTraffic => _showTraffic;
  bool get showSatellite => _showSatellite;
  double get currentZoom => _currentZoom;
  bool get isTracking => _isTracking;
  List<LatLng> get trackingPath => _trackingPath;
  List<LatLng> get currentRoute => _currentRoute;
  Marker? get destinationMarker => _destinationMarker;
  
  // Web map specific getters
  List<LatLng> get navigationRoute => _currentRoute;

  bool _initialized = false;

  MapController() {
    _ensureInitialized();
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _loadInitialData();
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _ensureInitialized();
  }

  // Load initial data
  Future<void> _loadInitialData() async {
    _setLoading(true);
    
    try {
      // Get current location
      UserLocation? location = await _locationService.getCurrentLocation();
      if (location != null) {
        _currentPosition = location.latLng;
        _moveCameraToPosition(_currentPosition!);
        
        // Load nearby parking locations
        await _loadNearbyParkingLocations();
        
        // Add user location marker
        _addUserLocationMarker();
      } else {
        // Use default location (Jakarta)
        _currentPosition = const LatLng(
          AppConstants.defaultLatitude,
          AppConstants.defaultLongitude,
        );
        _moveCameraToPosition(_currentPosition!);
      }
      
      _setError(null);
    } catch (e) {
      _setError('Gagal memuat data lokasi: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load nearby parking locations (mock data for now)
  Future<void> _loadNearbyParkingLocations() async {
    // This would typically come from an API
    // For now, we'll use enhanced dummy data
    if (_currentPosition == null) return;

    _parkingLocations = DummyDataService.getEnhancedParkingLocations();
    _updateMarkers();
    notifyListeners();
  }

  void applyPriceFilter(int minPrice, int maxPrice) {
    if (_parkingLocations.isEmpty) {
      _parkingLocations = DummyDataService.getEnhancedParkingLocations();
    }
    _parkingLocations = _parkingLocations
        .where((p) => p.pricePerHour >= minPrice && p.pricePerHour <= maxPrice)
        .toList();
    _updateMarkers();
    notifyListeners();
  }

  // Add user location marker
  void _addUserLocationMarker() {
    if (_currentPosition == null) return;

    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: _currentPosition!,
      infoWindow: const InfoWindow(title: 'Lokasi Saya'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    _markers.add(userMarker);
    notifyListeners();
  }

  // Update markers for parking locations
  void _updateMarkers() {
    _markers.clear();
    
    // Add user location marker
    _addUserLocationMarker();

    // Add parking location markers
    for (final parking in _parkingLocations) {
      final marker = _createParkingMarker(parking);
      _markers.add(marker);
    }

    // Add search radius circle
    if (_currentPosition != null) {
      final searchCircle = Circle(
        circleId: const CircleId('search_radius'),
        center: _currentPosition!,
        radius: AppConstants.searchRadius,
        fillColor: Colors.blue.withValues(alpha: 0.1),
        strokeColor: Colors.blue.withValues(alpha: 0.5),
        strokeWidth: 2,
      );
      _circles = {searchCircle};
    }

    notifyListeners();
  }

  // Update real-time availability for a parking location
  void updateParkingRealtime(String id, int available, int total) {
    final index = _parkingLocations.indexWhere((p) => p.id == id);
    if (index != -1) {
      final old = _parkingLocations[index];
      
      // Determine new status
      ParkingStatus newStatus;
      if (available == 0) {
        newStatus = ParkingStatus.full;
      } else if (available < total * 0.2) {
        newStatus = ParkingStatus.gettingFull;
      } else {
        newStatus = ParkingStatus.available;
      }

      _parkingLocations[index] = old.copyWith(
        availableSpots: available,
        totalCapacity: total,
        status: newStatus,
        lastUpdated: DateTime.now(),
      );
      
      // If the selected parking is the one being updated, update it too
      if (_selectedParking?.id == id) {
        _selectedParking = _parkingLocations[index];
      }

      _updateMarkers();
      notifyListeners();
    }
  }

  // Create parking marker
  Marker _createParkingMarker(ParkingLocation parking) {
    final hue = _getMarkerHue(parking.status);
    
    return Marker(
      markerId: MarkerId(parking.id),
      position: parking.coordinates,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: parking.name,
        snippet: '${parking.formattedDistance} • ${parking.statusText}',
      ),
      onTap: () => selectParking(parking),
    );
  }

  // Get marker hue based on parking status
  double _getMarkerHue(ParkingStatus status) {
    switch (status) {
      case ParkingStatus.available:
        return BitmapDescriptor.hueGreen;
      case ParkingStatus.gettingFull:
        return BitmapDescriptor.hueYellow;
      case ParkingStatus.full:
        return BitmapDescriptor.hueRed;
    }
  }

  // Move camera to position
  Future<void> _moveCameraToPosition(LatLng position) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: _currentZoom,
          ),
        ),
      );
    }
  }

  // Select parking location
  void selectParking(ParkingLocation parking) {
    _selectedParking = parking;
    _moveCameraToPosition(parking.coordinates);
    notifyListeners();
  }

  // Clear selected parking
  void clearSelectedParking() {
    _selectedParking = null;
    notifyListeners();
  }

  // Toggle traffic layer
  void toggleTraffic() {
    _showTraffic = !_showTraffic;
    notifyListeners();
  }

  // Find nearby parking (wrapper method)
  void findNearbyParking() {
    final nearestParking = findNearestParking(3);
    if (nearestParking.isNotEmpty) {
      // Move to first nearest parking
      if (_mapController != null && nearestParking.first.coordinates != null) {
        _moveCameraToPosition(nearestParking.first.coordinates);
      }
      _showNotification('Menemukan ${nearestParking.length} tempat parkir terdekat', 
        '${nearestParking.first.name} - ${nearestParking.first.formattedDistance}');
    }
  }

  // Clear navigation (wrapper method)
  void clearNavigation() {
    clearNavigationRoute();
    clearSelectedParking();
    _showNotification('Navigasi dibersihkan', 'Rute dan pilihan lokasi telah dihapus');
  }

  // Start navigation to parking (wrapper method)
  Future<void> startNavigationToParking(ParkingLocation parking) async {
    await navigateToParkingWithDirections(parking);
  }

  // Toggle map type
  void toggleMapType() {
    _showSatellite = !_showSatellite;
    notifyListeners();
  }

  // Move to current location
  Future<void> moveToCurrentLocation() async {
    _setLoading(true);
    try {
      UserLocation? location = await _locationService.getCurrentLocation();
      if (location != null) {
        _currentPosition = location.latLng;
        await _moveCameraToPosition(_currentPosition!);
        _addUserLocationMarker();
        await _loadNearbyParkingLocations();
      }
    } catch (e) {
      _setError('Gagal mendapatkan lokasi: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh parking data
  Future<void> refreshParkingData() async {
    await _loadNearbyParkingLocations();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // On camera move
  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
  }

  // ==================== TRACKING FUNCTIONALITY ====================

  // Start location tracking
  Future<void> startTracking() async {
    if (_isTracking) return;
    
    try {
      final hasPermission = await _locationService.checkLocationPermission();
      if (!hasPermission) {
        _setError('Izin lokasi diperlukan untuk melacak perjalanan');
        return;
      }
      
      _isTracking = true;
      _trackingPath.clear();
      
      // Add current position to tracking path
      if (_currentPosition != null) {
        _trackingPath.add(_currentPosition!);
      }
      
      // Start position stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        final latLng = LatLng(position.latitude, position.longitude);
        _trackingPath.add(latLng);
        _currentPosition = latLng;
        _updateTrackingMarker();
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      _setError('Gagal memulai pelacakan: $e');
      _isTracking = false;
    }
  }

  // Stop location tracking
  void stopTracking() {
    if (!_isTracking) return;
    
    _isTracking = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    // Remove tracking polyline
    _polylines.removeWhere((polyline) => polyline.polylineId.value == 'tracking_path');
    
    notifyListeners();
  }

  // Update tracking marker and polyline
  void _updateTrackingMarker() {
    if (_trackingPath.length < 2) return;
    
    // Create polyline for tracking path
    final trackingPolyline = Polyline(
      polylineId: const PolylineId('tracking_path'),
      points: _trackingPath,
      color: Colors.blue,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
    
    _polylines = {trackingPolyline};
  }

  // Clear tracking path
  void clearTrackingPath() {
    _trackingPath.clear();
    _polylines.removeWhere((polyline) => polyline.polylineId.value == 'tracking_path');
    notifyListeners();
  }

  // ==================== NAVIGATION FUNCTIONALITY ====================

  // Navigate to parking location with directions
  Future<void> navigateToParkingWithDirections(ParkingLocation parking) async {
    if (_currentPosition == null) {
      _setError('Lokasi saat ini tidak tersedia');
      return;
    }
    
    try {
      _setLoading(true);
      
      // Get directions from current location to parking
      final route = await MapService.getDirections(
        _currentPosition!,
        parking.coordinates,
      );
      
      _currentRoute = route;
      _selectedParking = parking;
      
      // Create destination marker
      _destinationMarker = Marker(
        markerId: MarkerId('destination_${parking.id}'),
        position: parking.coordinates,
        infoWindow: InfoWindow(
          title: parking.name,
          snippet: 'Tujuan navigasi',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      
      // Create route polyline
      if (route.length >= 2) {
        final routePolyline = Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: route,
          color: Colors.blue,
          width: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: [PatternItem.dash(30), PatternItem.gap(10)],
        );
        
        _polylines.add(routePolyline);
      }
      
      // Move camera to show both current location and destination
      await _fitBounds([
        _currentPosition!,
        parking.coordinates,
      ]);
      
      _setError(null);
    } catch (e) {
      _setError('Gagal membuat rute navigasi: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Clear navigation route
  void clearNavigationRoute() {
    _currentRoute.clear();
    _polylines.removeWhere((polyline) => polyline.polylineId.value == 'navigation_route');
    
    if (_destinationMarker != null) {
      _markers.remove(_destinationMarker!);
      _destinationMarker = null;
    }
    
    notifyListeners();
  }

  // Fit camera to show all locations
  Future<void> _fitBounds(List<LatLng> locations) async {
    if (locations.isEmpty || _mapController == null) return;
    
    final bounds = MapService.getBoundsFromLocations(locations);
    final northeast = bounds['northeast']!;
    final southwest = bounds['southwest']!;
    
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          northeast: northeast,
          southwest: southwest,
        ),
        50.0, // Padding in pixels
      ),
    );
  }

  // Find nearest parking locations
  List<ParkingLocation> findNearestParking([int limit = 5]) {
    if (_currentPosition == null || _parkingLocations.isEmpty) return [];
    
    final sortedLocations = MapService.sortByDistance(_parkingLocations, _currentPosition!);
    return sortedLocations.take(limit).toList();
  }

  // Filter parking locations by distance
  List<ParkingLocation> filterParkingByDistance(double maxDistanceKm) {
    if (_currentPosition == null || _parkingLocations.isEmpty) return [];
    
    return MapService.filterByDistance(_parkingLocations, _currentPosition!, maxDistanceKm);
  }

  // Get current location address
  Future<String?> getCurrentLocationAddress() async {
    if (_currentPosition == null) return null;
    
    try {
      return await MapService.reverseGeocode(_currentPosition!);
    } catch (e) {
      return null;
    }
  }

  // Search parking by address
  Future<List<ParkingLocation>> searchParkingByAddress(String address) async {
    try {
      final coordinates = await MapService.geocodeAddress(address);
      if (coordinates == null) return [];
      
      // Sort parking locations by distance from searched location
      return MapService.sortByDistance(_parkingLocations, coordinates);
    } catch (e) {
      return [];
    }
  }

  // ==================== ENHANCED PARKING TRACKING ====================

  // Track parking availability changes
  void startParkingAvailabilityTracking() {
    // Timer to periodically check parking availability
    _trackingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkParkingAvailabilityUpdates();
    });
  }

  // Check for parking availability updates
  void _checkParkingAvailabilityUpdates() {
    // This would typically call an API to get real-time updates
    // For now, we'll simulate random changes in availability
    for (final parking in _parkingLocations) {
      // Simulate small changes in availability (±5 spots)
      final change = (DateTime.now().second % 11) - 5; // -5 to +5
      final newAvailable = (parking.availableSpots + change).clamp(0, parking.totalCapacity);
      
      // Update availability if changed significantly
      if ((newAvailable - parking.availableSpots).abs() > 2) {
        // This would typically be done through a proper update method
        // For now, we'll just notify about significant changes
        if (newAvailable < parking.availableSpots && parking.status == ParkingStatus.available) {
          // Parking is getting full
          _showNotification('${parking.name} mulai penuh', 
            'Tersisa $newAvailable dari ${parking.totalCapacity} tempat');
        } else if (newAvailable > parking.availableSpots && 
                   (parking.status == ParkingStatus.full || parking.status == ParkingStatus.gettingFull)) {
          // Parking has more availability
          _showNotification('${parking.name} memiliki tempat kosong', 
            'Tersedia $newAvailable dari ${parking.totalCapacity} tempat');
        }
      }
    }
  }

  // Show notification (placeholder for actual notification system)
  void _showNotification(String title, String message) {
    // This would integrate with the notification service
    debugPrint('NOTIFICATION: $title - $message');
  }

  // Dispose resources
  @override
  void dispose() {
    _mapController?.dispose();
    _positionStreamSubscription?.cancel();
    _trackingTimer?.cancel();
    super.dispose();
  }
}