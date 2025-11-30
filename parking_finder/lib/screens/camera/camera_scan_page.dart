import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/camera_scan_service.dart';
import '../../constants/app_colors_new.dart';
import 'payment_confirmation_dialog.dart';

class CameraScanPage extends StatefulWidget {
  final bool isForPayment;
  final double? paymentAmount;
  final String? parkingLocation;

  const CameraScanPage({
    Key? key,
    this.isForPayment = false,
    this.paymentAmount,
    this.parkingLocation,
  }) : super(key: key);

  @override
  _CameraScanPageState createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> with SingleTickerProviderStateMixin {
  final CameraScanService _scanService = CameraScanService();
  ScanMode _currentMode = ScanMode.qr;
  bool _isScanning = false;
  bool _hasPermission = false;
  bool _isFlashOn = false;
  String _scanStatus = 'Arahkan kamera ke QR/barcode untuk memindai';
  ScanResult? _lastResult;
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanService.disposeScanner();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    if (kIsWeb) {
      // For web, we can't access camera hardware, so show demo mode
      setState(() {
        _hasPermission = false; // Set to false to show demo interface
        _scanStatus = 'Mode Demo: Kamera tidak tersedia di web. Gunakan tombol demo di bawah.';
      });
      return;
    }
    
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
      if (_hasPermission) {
        _scanStatus = 'Kamera siap. Arahkan ke QR/barcode.';
      } else {
        _scanStatus = 'Izin kamera diperlukan untuk scan.';
      }
    });
  }

  Future<void> _startScanning() async {
    if (kIsWeb) {
      // For web, simulate scanning with demo data
      setState(() {
        _isScanning = true;
        _scanStatus = 'Mode Demo: Mensimulasikan scan...';
      });

      // Simulate scanning delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Create demo scan result based on mode
        final demoResult = _createDemoScanResult();
        setState(() {
          _lastResult = demoResult;
          _scanStatus = _getScanResultMessage(demoResult);
          _isScanning = false;
        });
        
        // Auto-process if in payment mode
        if (widget.isForPayment && demoResult.type != ScanType.unknown) {
          await _processPayment(demoResult);
        }
      }
      return;
    }

    if (!_hasPermission) {
      await _checkCameraPermission();
      return;
    }

    setState(() {
      _isScanning = true;
      _scanStatus = 'Memindai...';
    });

    try {
      await for (final result in _scanService.startScanning(mode: _currentMode)) {
        if (mounted) {
          setState(() {
            _lastResult = result;
            _scanStatus = _getScanResultMessage(result);
            _isScanning = false;
          });
          
          // Auto-process if in payment mode
          if (widget.isForPayment && result.type != ScanType.unknown) {
            await _processPayment(result);
          }
          
          break; // Stop after first successful scan
        }
      }
    } catch (e) {
      setState(() {
        _scanStatus = 'Error: ${e.toString()}';
        _isScanning = false;
      });
    }
  }

  Future<void> _processPayment(ScanResult result) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        scanResult: result,
        amount: widget.paymentAmount ?? 0,
        onConfirm: () async {
          Navigator.pop(context); // Close confirmation dialog
          
          setState(() {
            _scanStatus = 'Memproses pembayaran...';
          });

          try {
            final paymentResult = await _scanService.processPayment(
              result, 
              widget.paymentAmount ?? 0,
            );

            if (paymentResult['success'] == true) {
              if (mounted) {
                Navigator.pop(context, {
                  'success': true,
                  'transactionId': paymentResult['transactionId'],
                  'amount': paymentResult['amount'],
                  'scanResult': result,
                });
              }
            } else {
              setState(() {
                _scanStatus = 'Pembayaran gagal: ${paymentResult['error']}';
              });
            }
          } catch (e) {
            setState(() {
              _scanStatus = 'Error pembayaran: ${e.toString()}';
            });
          }
        },
        onCancel: () {
          Navigator.pop(context); // Close confirmation dialog
        },
      ),
    );
  }

  String _getScanResultMessage(ScanResult result) {
    switch (result.type) {
      case ScanType.qris:
        return 'QRIS terdeteksi: ${result.metadata?['merchant'] ?? 'Merchant'}';
      case ScanType.parkingTicket:
        return 'Tiket parkir terdeteksi: ${result.data}';
      case ScanType.vehicleNumber:
        return 'Nomor kendaraan terdeteksi: ${result.data}';
      default:
        return 'Kode terdeteksi: ${result.data}';
    }
  }

  Future<void> _toggleFlash() async {
    await _scanService.toggleFlash();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _switchScanMode() {
    setState(() {
      switch (_currentMode) {
        case ScanMode.qr:
          _currentMode = ScanMode.barcode;
          _scanStatus = 'Mode: Barcode. Arahkan ke barcode tiket.';
          break;
        case ScanMode.barcode:
          _currentMode = ScanMode.ocr;
          _scanStatus = 'Mode: OCR. Arahkan ke teks/nomor.';
          break;
        case ScanMode.ocr:
          _currentMode = ScanMode.qr;
          _scanStatus = 'Mode: QR. Arahkan ke QR code.';
          break;
      }
    });
  }

  void _showScanDetails() {
    if (_lastResult == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColorsNew.background.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          gradient: AppColorsNew.primaryGradient,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detail Scan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColorsNew.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: AppColorsNew.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Tipe Scan', _lastResult!.type.toString().split('.').last),
            _buildDetailRow('Data', _lastResult!.data),
            if (_lastResult!.metadata != null) ...[
              const SizedBox(height: 8),
              Text(
                'Metadata:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColorsNew.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ..._lastResult!.metadata!.entries.map(
                (entry) => _buildDetailRow(entry.key, entry.value.toString()),
              ),
            ],
            const SizedBox(height: 24),
            if (widget.isForPayment && _lastResult!.type != ScanType.unknown) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _processPayment(_lastResult!),
                  icon: const Icon(Icons.payment),
                  label: Text('Bayar Rp ${widget.paymentAmount?.toStringAsFixed(0) ?? '0'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorsNew.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, _lastResult);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Gunakan Data Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorsNew.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: AppColorsNew.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColorsNew.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isForPayment ? 'Scan to Pay' : 'Camera Scan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Info Scan'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mode Scan yang tersedia:'),
                      const SizedBox(height: 8),
                      _buildModeInfo('QR Code', 'Untuk QRIS dan pembayaran digital'),
                      _buildModeInfo('Barcode', 'Untuk tiket parkir dan struk'),
                      _buildModeInfo('OCR', 'Untuk nomor kendaraan dan teks'),
                      const SizedBox(height: 16),
                      const Text('Tips:'),
                      const Text('• Pastikan kode terlihat jelas'),
                      const Text('• Jaga jarak 10-30 cm dari kode'),
                      const Text('• Hindari bayangan dan pantulan cahaya'),
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showMyBarcode,
            tooltip: 'Tampilkan QR Saya',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera View or Demo Background
          if (kIsWeb || !_hasPermission)
            // Web demo background or permission denied background
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      kIsWeb ? Icons.camera_alt : Icons.camera,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      kIsWeb 
                        ? 'Mode Demo Web'
                        : 'Izin Kamera Diperlukan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kIsWeb
                        ? 'Kamera tidak tersedia di browser web. Gunakan tombol demo di bawah untuk mensimulasikan scan.'
                        : 'Aplikasi membutuhkan akses kamera untuk scan QR/barcode',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startScanning,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Demo Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorsNew.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            // Real camera view for mobile platforms
            MobileScanner(
              controller: _scanService.scannerController,
              onDetect: (barcode) {
                if (_isScanning && barcode.barcodes.isNotEmpty) {
                  final data = barcode.barcodes.first.rawValue;
                  if (data != null && data.isNotEmpty) {
                    // Handle detection
                  }
                }
              },
            ),
          
          // Scanning Frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColorsNew.accent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  _buildCornerIndicator(true, true),
                  _buildCornerIndicator(true, false),
                  _buildCornerIndicator(false, true),
                  _buildCornerIndicator(false, false),
                  
                  // Scanning line animation
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 125 + (_scanAnimation.value * 100),
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColorsNew.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColorsNew.accent.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          
          // Mode Switch Button
          Positioned(
            top: 100,
            right: 24,
            child: FloatingActionButton(
              onPressed: _switchScanMode,
              backgroundColor: AppColorsNew.accent.withValues(alpha: 0.8),
              child: Icon(
                _getModeIcon(),
                color: Colors.white,
              ),
              tooltip: 'Ganti Mode Scan',
            ),
          ),
          
          // Bottom Status Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: Column(
                  children: [
                    Text(
                      _scanStatus,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_lastResult != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _showScanDetails,
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Lihat Detail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColorsNew.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: 200,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _startScanning,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(_isScanning ? 'Memindai...' : 'Mulai Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColorsNew.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMyBarcode() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final data = 'parkiryuk|uid=$uid|ts=${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Saya'),
        content: SizedBox(
          width: 240,
          height: 240,
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 220,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
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

  Widget _buildCornerIndicator(bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: AppColorsNew.accent, width: 3) : BorderSide.none,
            bottom: isTop ? BorderSide.none : BorderSide(color: AppColorsNew.accent, width: 3),
            left: isLeft ? BorderSide(color: AppColorsNew.accent, width: 3) : BorderSide.none,
            right: isLeft ? BorderSide.none : BorderSide(color: AppColorsNew.accent, width: 3),
          ),
        ),
      ),
    );
  }

  ScanResult _createDemoScanResult() {
    // Create demo scan results based on current mode
    switch (_currentMode) {
      case ScanMode.qr:
        return ScanResult(
          type: ScanType.qris,
          data: 'QRIS1234567890',
          metadata: {
            'merchant': 'Parkir Mall Demo',
            'amount': widget.paymentAmount?.toString() ?? '5000',
            'type': 'payment',
          },
        );
      case ScanMode.barcode:
        return ScanResult(
          type: ScanType.parkingTicket,
          data: 'TICKET123456',
          metadata: {
            'ticketType': 'parking',
            'location': 'Mall Demo Lantai 2',
            'entryTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            'fee': widget.paymentAmount?.toString() ?? '3000',
          },
        );
      case ScanMode.ocr:
        return ScanResult(
          type: ScanType.vehicleNumber,
          data: 'B1234XYZ',
          metadata: {
            'vehicleType': 'mobil',
            'confidence': '0.95',
            'text': 'Nomor Kendaraan: B1234XYZ',
          },
        );
    }
  }

  IconData _getModeIcon() {
    switch (_currentMode) {
      case ScanMode.qr:
        return Icons.qr_code;
      case ScanMode.barcode:
        return Icons.view_agenda;
      case ScanMode.ocr:
        return Icons.text_fields;
    }
  }

  Widget _buildModeInfo(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: AppColorsNew.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $description',
              style: TextStyle(
                fontSize: 14,
                color: AppColorsNew.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}