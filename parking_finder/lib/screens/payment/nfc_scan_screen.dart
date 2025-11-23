import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors_new.dart';
import '../../services/nfc_payment_service.dart';

class NFCScanScreen extends StatefulWidget {
  const NFCScanScreen({super.key});

  @override
  State<NFCScanScreen> createState() => _NFCScanScreenState();
}

class _NFCScanScreenState extends State<NFCScanScreen> {
  bool _isScanning = false;
  String _status = 'Tempelkan kartu ke bagian belakang HP';
  String _cardType = '';
  String _cardUID = '';
  bool _scanComplete = false;

  @override
  void initState() {
    super.initState();
    _startNFCScan();
  }

  @override
  void dispose() {
    // Ensure NFC session is properly closed
    SystemChannels.platform.invokeMethod('SystemChrome.setEnabledSystemUIOverlays', []);
    super.dispose();
  }

  Future<void> _startNFCScan() async {
    setState(() {
      _isScanning = true;
      _status = 'Mendeteksi kartu...';
    });

    try {
      final nfcData = await NFCPaymentService.scanNFCCard();
      
      if (nfcData != null) {
        setState(() {
          _cardType = nfcData['cardType'] ?? 'Unknown';
          _cardUID = nfcData['uid'] ?? '';
          _status = 'Kartu terdeteksi: $_cardType';
          _scanComplete = true;
        });

        // Create payment card from NFC data
        final paymentCard = await NFCPaymentService.createCardFromNFC(nfcData);
        
        // Show confirmation dialog
        _showCardConfirmation(paymentCard);
      } else {
        setState(() {
          _status = 'Tidak ada kartu yang terdeteksi';
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
        _isScanning = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membaca kartu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCardConfirmation(dynamic paymentCard) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.credit_card,
                color: AppColorsNew.accent,
              ),
              const SizedBox(width: 8),
              const Text('Kartu Terdeteksi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipe Kartu: $_cardType',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'UID: ${_cardUID.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColorsNew.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nomor Kartu: **** **** **** ${paymentCard.lastFourDigits}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColorsNew.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: AppColorsNew.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data kartu akan dienkripsi dan disimpan secara aman',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColorsNew.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () => _saveCard(paymentCard),
              icon: const Icon(Icons.save),
              label: const Text('Simpan Kartu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColorsNew.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveCard(dynamic paymentCard) async {
    try {
      await NFCPaymentService.savePaymentCard(paymentCard);
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context, true); // Return to previous screen with success
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kartu berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan kartu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      appBar: AppBar(
        title: const Text('Scan NFC'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_scanComplete)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NFC Icon Animation
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColorsNew.accent.withOpacity(0.3),
                      AppColorsNew.accent.withOpacity(0.1),
                    ],
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  width: _isScanning ? 150 : 120,
                  height: _isScanning ? 150 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scanComplete 
                        ? Colors.green.withOpacity(0.2)
                        : AppColorsNew.accent.withOpacity(0.2),
                    border: Border.all(
                      color: _scanComplete 
                          ? Colors.green
                          : AppColorsNew.accent,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _scanComplete ? Icons.check_circle : Icons.nfc,
                    size: _isScanning ? 80 : 60,
                    color: _scanComplete 
                        ? Colors.green
                        : AppColorsNew.accent,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Status Text
              Text(
                _status,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColorsNew.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (_cardType.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _cardType,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColorsNew.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Action Buttons
              if (_scanComplete)
                Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Kembali'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorsNew.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _startNFCScan,
                      child: const Text('Scan Ulang'),
                    ),
                  ],
                )
              else if (!_isScanning)
                Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: OutlinedButton.icon(
                        onPressed: _startNFCScan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColorsNew.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColorsNew.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Gunakan Input Manual'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}