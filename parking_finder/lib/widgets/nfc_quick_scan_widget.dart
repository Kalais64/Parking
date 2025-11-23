import 'package:flutter/material.dart';
import '../services/nfc_payment_service.dart';
import '../models/payment_card.dart';
import '../screens/nfc/nfc_scan_page.dart';

class NFCQuickScanWidget extends StatelessWidget {
  final String? buttonText;
  final Color? buttonColor;
  final IconData? icon;
  final bool isExtended;
  final Function(PaymentCard)? onCardDetected;
  final Function()? onScanStarted;
  final Function()? onScanCompleted;

  const NFCQuickScanWidget({
    Key? key,
    this.buttonText,
    this.buttonColor,
    this.icon,
    this.isExtended = false,
    this.onCardDetected,
    this.onScanStarted,
    this.onScanCompleted,
  }) : super(key: key);

  Future<void> _startNFCSession(BuildContext context) async {
    try {
      // Check NFC availability
      bool nfcAvailable = await NFCPaymentService.isNFCAvailable();
      
      if (!nfcAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC tidak tersedia di perangkat ini'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      onScanStarted?.call();

      // Navigate to NFC scan page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NFCScanPage(),
        ),
      );

      onScanCompleted?.call();

      if (result != null && result is PaymentCard) {
        onCardDetected?.call(result);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kartu ${result.cardType} berhasil terdeteksi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _startNFCSession(context),
          icon: Icon(icon ?? Icons.nfc),
          label: Text(buttonText ?? 'Scan Kartu NFC'),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _startNFCSession(context),
      icon: Icon(icon ?? Icons.nfc),
      label: Text(buttonText ?? 'Scan NFC'),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class NFCScanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Function(PaymentCard)? onCardDetected;
  final Color? cardColor;

  const NFCScanCard({
    Key? key,
    this.title = 'Scan Kartu NFC',
    this.subtitle = 'Tempelkan kartu e-Money ke HP',
    this.onCardDetected,
    this.cardColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => NFCQuickScanWidget(
          onCardDetected: onCardDetected,
        )._startNFCSession(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (cardColor ?? Colors.blue).withValues(alpha: 0.1),
                (cardColor ?? Colors.blue).withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.nfc,
                size: 48,
                color: cardColor ?? Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cardColor ?? Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => NFCQuickScanWidget(
                  onCardDetected: onCardDetected,
                )._startNFCSession(context),
                icon: const Icon(Icons.nfc),
                label: const Text('Scan Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardColor ?? Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}