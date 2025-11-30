import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/map_controller.dart';
import '../../constants/app_colors_new.dart';
import '../../models/parking_location.dart';
import '../../models/favorite.dart';
import '../../services/dummy_data_service.dart';
import 'package:intl/intl.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Favorite> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _favorites = DummyDataService.getDummyFavorites('user_001');
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favorit Saya',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColorsNew.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_favorites.length} tempat parkir favorit',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColorsNew.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                      ),
                    )
                  : _favorites.isEmpty
                      ? _buildEmptyState()
                      : _buildFavoritesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColorsNew.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border,
              size: 60,
              color: AppColorsNew.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada favorit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColorsNew.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan tempat parkir favorit Anda\nuntuk akses lebih cepat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColorsNew.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to map
              Navigator.pushNamed(context, '/');
            },
            icon: const Icon(Icons.map),
            label: const Text('Cari Parkir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorsNew.accent,
              foregroundColor: AppColorsNew.buttonText,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return _buildFavoriteCard(favorite);
      },
    );
  }

  Widget _buildFavoriteCard(Favorite favorite) {
    final parking = favorite.parkingLocation;
    final availabilityColor = _getAvailabilityColor(parking.availableSpots, parking.totalCapacity);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showParkingDetails(parking),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parking.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColorsNew.buttonText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            parking.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColorsNew.buttonText.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColorsNew.buttonText.withValues(alpha: 0.2),
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
                          const SizedBox(width: 4),
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

                const SizedBox(height: 16),

                // Stats
                Row(
                  children: [
                    // Availability
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColorsNew.buttonText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${parking.availableSpots}/${parking.totalCapacity}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: availabilityColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColorsNew.buttonText.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColorsNew.buttonText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Rp ${parking.pricePerHour.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColorsNew.buttonText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Per jam',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColorsNew.buttonText.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Rating
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColorsNew.buttonText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: AppColorsNew.buttonText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  parking.rating?.toStringAsFixed(1) ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColorsNew.buttonText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${parking.reviewCount ?? 0} ulasan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColorsNew.buttonText.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Added date
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColorsNew.buttonText.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ditambahkan ${DateFormat('dd MMM yyyy').format(favorite.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColorsNew.buttonText.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Color _getAvailabilityColor(int available, int total) {
    final percentage = available / total;
    if (percentage > 0.5) return Colors.green;
    if (percentage > 0.2) return Colors.orange;
    return Colors.red;
  }

  void _showParkingDetails(ParkingLocation parking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColorsNew.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildParkingDetailsSheet(parking),
    );
  }

  Widget _buildParkingDetailsSheet(ParkingLocation parking) {
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
                  color: _getStatusColor(parking.status),
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
                  onPressed: () => _navigateToParking(parking),
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
                child: OutlinedButton.icon(
                  onPressed: () => _removeFromFavorites(parking),
                  icon: const Icon(Icons.favorite),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  void _navigateToParking(ParkingLocation parking) {
    Navigator.pop(context);
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.navigateToParkingWithDirections(parking);
    Navigator.pushNamed(context, '/');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigasi ke ${parking.name}'),
        backgroundColor: AppColorsNew.accent,
      ),
    );
  }

  void _removeFromFavorites(ParkingLocation parking) {
    Navigator.pop(context);
    setState(() {
      _favorites.removeWhere((f) => f.parkingLocation.id == parking.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${parking.name} dihapus dari favorit'),
        backgroundColor: AppColorsNew.accent,
      ),
    );
  }
}