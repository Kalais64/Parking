import 'package:flutter/material.dart';
import '../../widgets/nfc_quick_scan_widget.dart';
import '../../services/nfc_payment_service.dart';
import '../../models/payment_card.dart';
import '../../constants/app_colors_new.dart';

class NFCHomePage extends StatefulWidget {
  const NFCHomePage({Key? key}) : super(key: key);

  @override
  _NFCHomePageState createState() => _NFCHomePageState();
}

class _NFCHomePageState extends State<NFCHomePage> {
  bool _nfcAvailable = false;
  bool _isLoading = true;
  List<PaymentCard> _savedCards = [];

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  Future<void> _initializeNFC() async {
    try {
      bool available = await NFCPaymentService.isNFCAvailable();
      List<PaymentCard> cards = await NFCPaymentService.getSavedCards();
      
      setState(() {
        _nfcAvailable = available;
        _savedCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCards() async {
    try {
      List<PaymentCard> cards = await NFCPaymentService.getSavedCards();
      setState(() {
        _savedCards = cards;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat kartu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onCardDetected(PaymentCard card) {
    _refreshCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      appBar: AppBar(
        title: const Text('NFC Scan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeNFC,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                ),
              )
            : RefreshIndicator(
                onRefresh: _initializeNFC,
                color: AppColorsNew.accent,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // NFC Status Card
                      _buildNFCStatusCard(),
                      
                      const SizedBox(height: 24),
                      
                      // Quick Scan Section
                      _buildQuickScanSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Saved Cards Section
                      _buildSavedCardsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Recent Activity Section
                      _buildRecentActivitySection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNFCStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _nfcAvailable
                ? [
                    AppColorsNew.accent.withValues(alpha: 0.1),
                    AppColorsNew.accentLight.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _nfcAvailable
                    ? AppColorsNew.accent.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _nfcAvailable ? Icons.nfc : Icons.nfc_outlined,
                size: 30,
                color: _nfcAvailable ? AppColorsNew.accent : Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nfcAvailable ? 'NFC Aktif' : 'NFC Tidak Tersedia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _nfcAvailable
                          ? AppColorsNew.textPrimary
                          : Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nfcAvailable
                        ? 'Siap untuk scan kartu e-Money'
                        : 'Gunakan input manual untuk menambahkan kartu',
                    style: TextStyle(
                      fontSize: 14,
                      color: _nfcAvailable
                          ? AppColorsNew.textSecondary
                          : Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickScanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan Cepat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColorsNew.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_nfcAvailable) ...[
          NFCScanCard(
            title: 'Scan Kartu Baru',
            subtitle: 'Tempelkan kartu e-Money ke bagian belakang HP',
            cardColor: AppColorsNew.accent,
            onCardDetected: _onCardDetected,
          ),
        ] else ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.withValues(alpha: 0.05),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NFC Tidak Tersedia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Perangkat ini tidak mendukung NFC. Gunakan fitur input manual untuk menambahkan kartu.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add-payment-card');
                    },
                    icon: const Icon(Icons.add_card),
                    label: const Text('Tambah Kartu Manual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorsNew.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kartu Tersimpan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColorsNew.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/payment-methods');
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_savedCards.isEmpty) ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum Ada Kartu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan kartu NFC atau tambahkan kartu manual untuk memulai',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add-payment-card');
                    },
                    icon: const Icon(Icons.add_card),
                    label: const Text('Tambah Kartu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorsNew.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _savedCards.take(3).length,
              itemBuilder: (context, index) {
                final card = _savedCards[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildCardItem(card),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardItem(PaymentCard card) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColorsNew.accent.withValues(alpha: 0.8),
              AppColorsNew.accent.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.cardType,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (card.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              '**** ${card.lastFourDigits}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            if (card.expiryDate != null) ...[
              Text(
                'Exp: ${card.expiryDate}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktivitas Terbaru',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColorsNew.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColorsNew.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.history,
                        color: AppColorsNew.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belum ada aktivitas scan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColorsNew.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan kartu NFC Anda untuk melihat riwayat',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColorsNew.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/nfc-scan-page');
                    },
                    icon: const Icon(Icons.nfc),
                    label: const Text('Scan Kartu Sekarang'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang NFC Scan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Fitur NFC Scan memungkinkan Anda:'),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.nfc,
                title: 'Scan Kartu e-Money',
                description: 'Tempelkan kartu e-Money ke HP untuk scan otomatis',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                icon: Icons.credit_card,
                title: 'Tambah Kartu Cepat',
                description: 'Kartu yang discan otomatis tersimpan di metode pembayaran',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                icon: Icons.payment,
                title: 'Bayar Parkir',
                description: 'Gunakan kartu yang tersimpan untuk pembayaran parkir',
              ),
              const SizedBox(height: 16),
              const Text('Kartu yang didukung:'),
              const SizedBox(height: 8),
              const Text('• Mandiri e-Money'),
              const Text('• BCA Flazz'),
              const Text('• BNI TapCash'),
              const Text('• Kartu debit/kredit dengan chip NFC'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColorsNew.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColorsNew.accent,
            size: 16,
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
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}