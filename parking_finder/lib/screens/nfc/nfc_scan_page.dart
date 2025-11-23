import 'package:flutter/material.dart';
import '../../services/nfc_payment_service.dart';
import '../../models/payment_card.dart';
import '../../constants/app_colors_new.dart';

class NFCScanPage extends StatefulWidget {
  final bool isForPayment;
  final double? paymentAmount;
  final String? parkingLocation;

  const NFCScanPage({
    Key? key,
    this.isForPayment = false,
    this.paymentAmount,
    this.parkingLocation,
  }) : super(key: key);

  @override
  _NFCScanPageState createState() => _NFCScanPageState();
}

class _NFCScanPageState extends State<NFCScanPage> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _nfcAvailable = false;
  String _scanStatus = 'Menyiapkan scan...';
  String _cardInfo = '';
  PaymentCard? _detectedCard;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _checkNFCAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      bool available = await NFCPaymentService.isNFCAvailable();
      setState(() {
        _nfcAvailable = available;
        if (available) {
          _scanStatus = 'Siap untuk scan kartu';
        } else {
          _scanStatus = 'NFC tidak tersedia di perangkat ini';
        }
      });
    } catch (e) {
      setState(() {
        _scanStatus = 'Error: ${e.toString()}';
        _nfcAvailable = false;
      });
    }
  }

  Future<void> _startNFCScan() async {
    if (!_nfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFC tidak tersedia di perangkat ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanStatus = 'Mendeteksi kartu...';
      _cardInfo = '';
      _detectedCard = null;
    });

    try {
      // Simulate NFC scan (in real app, this would scan actual NFC)
      await Future.delayed(const Duration(seconds: 3));
      
      // Simulate detected card data
      Map<String, dynamic> cardData = {
        'cardType': 'Mandiri e-Money',
        'uid': '8800111122223333',
        'balance': 150000,
      };

      PaymentCard detectedCard = await NFCPaymentService.createCardFromNFC(cardData);
      
      setState(() {
        _detectedCard = detectedCard;
        _cardInfo = 'Kartu ${detectedCard.cardType} terdeteksi';
        _scanStatus = 'Kartu berhasil terdeteksi';
        _isScanning = false;
      });

      // Auto-save card if not in payment mode
      if (!widget.isForPayment && _detectedCard != null) {
        await NFCPaymentService.savePaymentCard(_detectedCard!);
        setState(() {
          _scanStatus = 'Kartu berhasil disimpan';
        });
      }

    } catch (e) {
      setState(() {
        _scanStatus = 'Gagal membaca kartu: ${e.toString()}';
        _isScanning = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_detectedCard == null) return;

    setState(() {
      _isScanning = true;
      _scanStatus = 'Memproses pembayaran...';
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _scanStatus = 'Pembayaran berhasil!';
        _isScanning = false;
      });

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'card': _detectedCard,
          'amount': widget.paymentAmount,
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = 'Pembayaran gagal: ${e.toString()}';
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsNew.background,
      appBar: AppBar(
        title: Text(widget.isForPayment ? 'Tap to Pay' : 'Scan Kartu NFC'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (widget.isForPayment) ...[
                    Text(
                      'Tempelkan kartu ke bagian belakang HP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColorsNew.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.parkingLocation ?? 'Lokasi Parkir',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColorsNew.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${widget.paymentAmount?.toStringAsFixed(0) ?? '0'}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColorsNew.accent,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Scan Kartu e-Money',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColorsNew.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tempelkan kartu e-Money atau bank ke bagian belakang HP',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColorsNew.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // NFC Animation Section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // NFC Icon with Animation
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isScanning ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _nfcAvailable 
                                  ? AppColorsNew.accent.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(
                                color: _nfcAvailable 
                                    ? AppColorsNew.accent
                                    : Colors.grey,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.nfc,
                              size: 60,
                              color: _nfcAvailable 
                                  ? AppColorsNew.accent
                                  : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Status Text
                    Text(
                      _scanStatus,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColorsNew.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Card Info
                    if (_cardInfo.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _cardInfo,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColorsNew.textPrimary,
                              ),
                            ),
                            if (_detectedCard != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '**** **** **** ${_detectedCard!.lastFourDigits}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColorsNew.textPrimary,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons
                    if (!_isScanning) ...[
                      if (_detectedCard == null) ...[
                        SizedBox(
                          width: 200,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _startNFCScan,
                            icon: const Icon(Icons.nfc),
                            label: const Text('Scan Kartu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColorsNew.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ] else ...[
                        if (widget.isForPayment) ...[
                          SizedBox(
                            width: 200,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _processPayment,
                              icon: const Icon(Icons.payment),
                              label: const Text('Bayar Sekarang'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: 200,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context, _detectedCard);
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Gunakan Kartu'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColorsNew.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _detectedCard = null;
                                _cardInfo = '';
                                _scanStatus = 'Siap untuk scan kartu';
                              });
                            },
                            child: const Text('Scan Ulang'),
                          ),
                      ],
                    ] else ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.accent),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Help Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (!_nfcAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'NFC tidak tersedia. Gunakan fitur input manual untuk menambahkan kartu.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Pastikan NFC diaktifkan di pengaturan HP Anda',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColorsNew.textSecondary.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info NFC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cara menggunakan scan NFC:'),
            const SizedBox(height: 8),
            const Text('1. Pastikan NFC aktif di pengaturan HP'),
            const Text('2. Tempelkan kartu ke bagian belakang HP'),
            const Text('3. Tunggu sampai kartu terdeteksi'),
            const SizedBox(height: 16),
            const Text('Kartu yang didukung:'),
            const Text('• Mandiri e-Money'),
            const Text('• BCA Flazz'),
            const Text('• BNI TapCash'),
            const Text('• Kartu debit/kredit dengan chip NFC'),
          ],
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
}