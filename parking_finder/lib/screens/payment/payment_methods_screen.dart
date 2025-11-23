import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors_new.dart';
import '../../models/payment_card.dart';
import '../../services/nfc_payment_service.dart';
import 'add_payment_card_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentCard> _paymentCards = [];
  bool _isLoading = true;
  bool _nfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
    _loadPaymentCards();
  }

  Future<void> _checkNFCAvailability() async {
    bool available = await NFCPaymentService.isNFCAvailable();
    setState(() {
      _nfcAvailable = available;
    });
  }

  Future<void> _loadPaymentCards() async {
    try {
      final cards = await NFCPaymentService.getSavedCards();
      setState(() {
        _paymentCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat metode pembayaran: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      appBar: AppBar(
        title: const Text('Metode Pembayaran'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: Column(
          children: [
            // NFC Status Banner
            if (!_nfcAvailable)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.nfc,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'NFC tidak tersedia di perangkat ini. Anda tetap bisa menambahkan kartu secara manual.',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Add Payment Method Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAddCard(),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Tambah Kartu Baru'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Payment Methods List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                      ),
                    )
                  : _paymentCards.isEmpty
                      ? _buildEmptyState()
                      : _buildPaymentCardsList(),
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
          Icon(
            Icons.credit_card_off,
            size: 80,
            color: AppColorsNew.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada metode pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColorsNew.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan kartu untuk pembayaran parkir yang lebih mudah',
            style: TextStyle(
              fontSize: 14,
              color: AppColorsNew.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddCard(),
            icon: const Icon(Icons.add_card),
            label: const Text('Tambah Kartu Pertama'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCardsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentCards.length,
      itemBuilder: (context, index) {
        final card = _paymentCards[index];
        return _buildPaymentCardItem(card);
      },
    );
  }

  Widget _buildPaymentCardItem(PaymentCard card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColorsNew.cardBackground.withOpacity(0.9),
              AppColorsNew.surface.withOpacity(0.9),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card Type and NFC Status
                  Row(
                    children: [
                      Icon(
                        _getCardIcon(card.cardType),
                        color: AppColorsNew.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        card.cardType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (card.isNfcEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColorsNew.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.nfc,
                                size: 16,
                                color: AppColorsNew.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'NFC',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColorsNew.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Default Card Badge
                  if (card.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColorsNew.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'UTAMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Card Number (Masked)
              Text(
                '**** **** **** ${card.lastFourDigits}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              if (card.cardHolderName != null) ...[
                const SizedBox(height: 8),
                Text(
                  card.cardHolderName!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorsNew.textSecondary,
                  ),
                ),
              ],
              if (card.expiryDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Exp: ${card.expiryDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColorsNew.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  if (!card.isDefault)
                    TextButton.icon(
                      onPressed: () => _setDefaultCard(card.id),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Jadikan Utama'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColorsNew.accent,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _deleteCard(card.id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
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

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'mandiri e-money':
      case 'bca flazz':
      case 'bni tapcash':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  void _navigateToAddCard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPaymentCardScreen(
          nfcAvailable: _nfcAvailable,
        ),
      ),
    ).then((_) => _loadPaymentCards());
  }

  Future<void> _setDefaultCard(String cardId) async {
    try {
      await NFCPaymentService.setDefaultCard(cardId);
      await _loadPaymentCards();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kartu utama berhasil diubah'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah kartu utama: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCard(String cardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kartu'),
        content: const Text('Apakah Anda yakin ingin menghapus kartu ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await NFCPaymentService.deletePaymentCard(cardId);
        await _loadPaymentCards();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kartu berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus kartu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}