import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../widgets/map_view_web.dart';
import '../../widgets/map_view_osm.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../constants/app_colors_new.dart';
import '../../services/voice_integration_manager.dart';
import '../../services/audio_navigation_service.dart';
import '../../widgets/voice_search_widget.dart';
import '../../widgets/voice_search_dialog.dart';
import '../../widgets/navigation_control_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late VoiceIntegrationManager _voiceManager;
  late AudioNavigationService _audioNavigationService;

  final List<Widget> _screens = [
    kIsWeb ? const MapViewWeb() : const MapViewOSM(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Cari Parkir',
    'Favorit',
    'Profil',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVoiceSystem();
  }

  void _initializeVoiceSystem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceManager = Provider.of<VoiceIntegrationManager>(context, listen: false);
      _audioNavigationService = Provider.of<AudioNavigationService>(context, listen: false);
      _voiceManager.initialize(context);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showVoiceSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => VoiceSearchDialog(
        onCommandRecognized: (command) {
          // Handle voice command result
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perintah suara: ${command.recognizedText}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColorsNew.background,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: _showVoiceSearchDialog,
              tooltip: 'Cari dengan suara',
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Implement search functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur pencarian akan segera tersedia')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                // TODO: Implement filter functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur filter akan segera tersedia')),
                );
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _screens[_selectedIndex],
          // Navigation control widget (only visible when navigating)
          if (_selectedIndex == 0) const NavigationControlWidget(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColorsNew.accent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Peta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Voice search button
                FloatingActionButton(
                  onPressed: _showVoiceSearchDialog,
                  backgroundColor: AppColorsNew.accent.withValues(alpha: 0.9),
                  child: const Icon(Icons.mic),
                ),
                const SizedBox(height: 16),
                // Scan to pay button
                FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pushNamed(context, '/camera-scan-page');
                  },
                  backgroundColor: AppColorsNew.accent,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan to Pay'),
                ),
              ],
            )
          : _selectedIndex == 2
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/nfc-scan-page');
                  },
                  backgroundColor: AppColorsNew.accent,
                  child: const Icon(Icons.nfc),
                )
              : null,
    );
  }
}