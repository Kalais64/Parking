import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors_new.dart';
import 'nfc_scan_screen.dart';
import 'manual_card_input_screen.dart';

class AddPaymentCardScreen extends StatefulWidget {
  final bool nfcAvailable;

  const AddPaymentCardScreen({
    super.key,
    required this.nfcAvailable,
  });

  @override
  State<AddPaymentCardScreen> createState() => _AddPaymentCardScreenState();
}

class _AddPaymentCardScreenState extends State<AddPaymentCardScreen> {
  bool _isScanningNFC = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      appBar: AppBar(
        title: const Text('Tambah Kartu Baru'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Metode Penambahan Kartu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColorsNew.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anda dapat menambahkan kartu melalui scan NFC atau input manual',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColorsNew.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // NFC Scan Option
            if (widget.nfcAvailable)
              _buildNFCOption(),

            // Manual Input Option
            _buildManualInputOption(),

            // Information Card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNFCOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: _isScanningNFC ? null : _startNFCScan,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColorsNew.accent.withOpacity(0.1),
                  AppColorsNew.accentLight.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.nfc,
                  size: 48,
                  color: AppColorsNew.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan via NFC',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColorsNew.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tempelkan kartu e-Money atau bank ke bagian belakang HP',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorsNew.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isScanningNFC) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mendeteksi kartu...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColorsNew.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualInputOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: _startManualInput,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColorsNew.surface.withOpacity(0.9),
                  AppColorsNew.cardBackground.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 48,
                  color: AppColorsNew.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Input Manual',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColorsNew.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan nomor kartu dan informasi lainnya secara manual',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorsNew.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColorsNew.surface.withOpacity(0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    size: 20,
                    color: AppColorsNew.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keamanan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColorsNew.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Data kartu Anda dienkripsi dengan aman\n'
                '• Hanya 4 digit terakhir yang disimpan\n'
                '• Kartu dapat digunakan untuk pembayaran parkir via NFC',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColorsNew.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNFCScan() async {
    setState(() {
      _isScanningNFC = true;
    });

    try {
      // Navigate to NFC scan screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NFCScanScreen(),
        ),
      );

      if (result == true) {
        // Card was successfully added
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal scan NFC: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanningNFC = false;
      });
    }
  }

  void _startManualInput() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualCardInputScreen(),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }
}