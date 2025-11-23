import 'package:flutter/material.dart';
import '../../services/camera_scan_service.dart';
import '../../constants/app_colors_new.dart';

class PaymentConfirmationDialog extends StatelessWidget {
  final ScanResult scanResult;
  final double amount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PaymentConfirmationDialog({
    Key? key,
    required this.scanResult,
    required this.amount,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Konfirmasi Pembayaran',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColorsNew.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancel,
                  color: AppColorsNew.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Scan Result Info
            _buildInfoCard(),
            const SizedBox(height: 16),
            
            // Payment Details
            _buildPaymentDetails(),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColorsNew.textPrimary,
                      side: BorderSide(color: AppColorsNew.textPrimary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.payment),
                    label: Text('Bayar Rp ${amount.toStringAsFixed(0)}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorsNew.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getScanTypeIcon(),
                color: AppColorsNew.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getScanTypeLabel(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColorsNew.textPrimary,
                      ),
                    ),
                    Text(
                      scanResult.data,
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
          if (scanResult.metadata != null) ...[
            const SizedBox(height: 12),
            ...scanResult.metadata!.entries.take(3).map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        '${entry.key}:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColorsNew.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColorsNew.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColorsNew.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Jumlah Tagihan', 'Rp ${amount.toStringAsFixed(0)}'),
          _buildDetailRow('Metode', 'Scan to Pay'),
          _buildDetailRow('Waktu', _formatTime(DateTime.now())),
          _buildDetailRow('Lokasi', 'Parking Area A'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColorsNew.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: AppColorsNew.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getScanTypeIcon() {
    switch (scanResult.type) {
      case ScanType.qris:
        return Icons.qr_code;
      case ScanType.parkingTicket:
        return Icons.confirmation_number;
      case ScanType.vehicleNumber:
        return Icons.directions_car;
      default:
        return Icons.camera_alt;
    }
  }

  String _getScanTypeLabel() {
    switch (scanResult.type) {
      case ScanType.qris:
        return 'Pembayaran QRIS';
      case ScanType.parkingTicket:
        return 'Tiket Parkir';
      case ScanType.vehicleNumber:
        return 'Nomor Kendaraan';
      default:
        return 'Kode Terdeteksi';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}