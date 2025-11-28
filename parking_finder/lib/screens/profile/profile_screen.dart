import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors_new.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    
    if (user == null) {
      return _buildGuestProfile();
    }
    
    return _buildUserProfile(user);
  }

  Widget _buildGuestProfile() {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo and Title
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColorsNew.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 40,
                        color: AppColorsNew.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Akun Saya',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColorsNew.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk untuk mengakses fitur lengkap',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColorsNew.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorsNew.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColorsNew.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Daftar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColorsNew.accent,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Features Info
                _buildFeaturesInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(User user) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // User Header
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColorsNew.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: AppColorsNew.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'Pengguna',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColorsNew.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? user.phoneNumber ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColorsNew.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColorsNew.accent),
                      onPressed: () {
                        // TODO: Implement edit profile
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur edit profil akan segera tersedia')),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Menu Items
                _buildMenuItem(
                  icon: Icons.nfc,
                  title: 'Scan NFC',
                  subtitle: 'Scan kartu e-Money secara langsung',
                  onTap: () {
                    Navigator.pushNamed(context, '/nfc-scan-page');
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.camera_alt,
                  title: 'Scan to Pay',
                  subtitle: 'Bayar parkir dengan scan QR/barcode',
                  onTap: () {
                    Navigator.pushNamed(context, '/camera-scan-page');
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.credit_card,
                  title: 'Metode Pembayaran',
                  subtitle: 'Kelola kartu e-Money dan bank',
                  onTap: () {
                    Navigator.pushNamed(context, '/payment-methods');
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.history,
                  title: 'Riwayat Parkir',
                  subtitle: 'Lihat riwayat pembayaran parkir',
                  onTap: () {
                    // TODO: Implement parking history
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur riwayat parkir akan segera tersedia')),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.favorite,
                  title: 'Tempat Favorit',
                  subtitle: 'Kelola lokasi parkir favorit',
                  onTap: () {
                    Navigator.pushNamed(context, '/favorites');
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.notifications,
                  title: 'Notifikasi',
                  subtitle: 'Pengaturan notifikasi',
                  onTap: () {
                    // TODO: Implement notification settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur notifikasi akan segera tersedia')),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Bantuan',
                  subtitle: 'Pusat bantuan dan FAQ',
                  onTap: () {
                    // TODO: Implement help center
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur bantuan akan segera tersedia')),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Keluar'),
                          content: const Text('Apakah Anda yakin ingin keluar?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Keluar'),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        await Provider.of<AuthService>(context, listen: false).signOut();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Keluar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColorsNew.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColorsNew.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesInfo() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitur Aplikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              icon: Icons.map,
              title: 'Pencarian Parkir',
              description: 'Temukan lokasi parkir terdekat dengan mudah',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.credit_card,
              title: 'Pembayaran Digital',
              description: 'Bayar parkir dengan kartu e-Money atau bank',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.notifications,
              title: 'Notifikasi Real-time',
              description: 'Dapatkan info ketersediaan parkir',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.favorite,
              title: 'Lokasi Favorit',
              description: 'Simpan lokasi parkir favorit Anda',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColorsNew.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColorsNew.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}