import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum ScanMode {
  qr,
  barcode,
  ocr,
}

enum ScanType {
  qris,
  parkingTicket,
  vehicleNumber,
  unknown,
}

class ScanResult {
  final ScanType type;
  final String data;
  final String? rawData;
  final Map<String, dynamic>? metadata;

  ScanResult({
    required this.type,
    required this.data,
    this.rawData,
    this.metadata,
  });
}

class CameraScanService {
  static final CameraScanService _instance = CameraScanService._internal();
  factory CameraScanService() => _instance;
  CameraScanService._internal();

  MobileScannerController? _scannerController;
  // final TextRecognizer _textRecognizer = TextRecognizer();
  // final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);

  bool get isScanning => _scannerController?.value.isInitialized ?? false;
  MobileScannerController? get scannerController => _scannerController;

  Future<void> initializeScanner() async {
    try {
      _scannerController = MobileScannerController(
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
      );
    } catch (e) {
      throw Exception('Failed to initialize scanner: $e');
    }
  }

  Future<void> disposeScanner() async {
    await _scannerController?.dispose();
    _scannerController = null;
  }

  Stream<ScanResult> startScanning({required ScanMode mode}) async* {
    if (_scannerController == null) {
      await initializeScanner();
    }

    try {
      switch (mode) {
        case ScanMode.qr:
          yield* _scanQR();
          break;
        case ScanMode.barcode:
          yield* _scanBarcode();
          break;
        case ScanMode.ocr:
          yield* _scanOCR();
          break;
      }
    } catch (e) {
      throw Exception('Scanning error: $e');
    }
  }

  Stream<ScanResult> _scanQR() async* {
    if (_scannerController == null) return;

    await for (final barcode in _scannerController!.barcodes) {
      if (barcode.barcodes.isNotEmpty) {
        final qrData = barcode.barcodes.first.rawValue ?? '';
        
        if (qrData.isNotEmpty) {
          final scanType = _detectQRType(qrData);
          yield ScanResult(
            type: scanType,
            data: _extractQRData(qrData, scanType),
            rawData: qrData,
            metadata: _buildQRMetadata(qrData, scanType),
          );
          break;
        }
      }
    }
  }

  Stream<ScanResult> _scanBarcode() async* {
    if (_scannerController == null) return;

    await for (final barcode in _scannerController!.barcodes) {
      if (barcode.barcodes.isNotEmpty) {
        final barcodeData = barcode.barcodes.first.rawValue ?? '';
        
        if (barcodeData.isNotEmpty) {
          final scanType = _detectBarcodeType(barcodeData);
          yield ScanResult(
            type: scanType,
            data: barcodeData,
            rawData: barcodeData,
            metadata: _buildBarcodeMetadata(barcodeData, scanType),
          );
          break;
        }
      }
    }
  }

  Stream<ScanResult> _scanOCR() async* {
    if (_scannerController == null) return;

    // For OCR, we need to capture image and process it
    // This is a simplified implementation
    await for (final _ in _scannerController!.barcodes) {
      // In a real implementation, you would capture the camera frame
      // and process it with the text recognizer
      // For now, we'll simulate OCR detection
      
      final simulatedText = _simulateOCRDetection();
      if (simulatedText.isNotEmpty) {
        final scanType = _detectOCRType(simulatedText);
        yield ScanResult(
          type: scanType,
          data: simulatedText,
          rawData: simulatedText,
          metadata: _buildOCRMetadata(simulatedText, scanType),
        );
        break;
      }
    }
  }

  ScanType _detectQRType(String data) {
    if (data.contains('QRIS') || data.contains('qris') || data.contains('QRIS.ID')) {
      return ScanType.qris;
    } else if (data.contains('PARKING') || data.contains('TICKET') || data.contains('parkir')) {
      return ScanType.parkingTicket;
    } else if (data.contains('B') && data.length >= 8 && RegExp(r'^[A-Z0-9]+$').hasMatch(data)) {
      return ScanType.vehicleNumber;
    }
    return ScanType.unknown;
  }

  ScanType _detectBarcodeType(String data) {
    if (data.length >= 10 && RegExp(r'^[0-9]+$').hasMatch(data)) {
      return ScanType.parkingTicket;
    }
    return ScanType.unknown;
  }

  ScanType _detectOCRType(String text) {
    // Check for vehicle number patterns (Indonesian format)
    if (RegExp(r'[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}').hasMatch(text)) {
      return ScanType.vehicleNumber;
    }
    // Check for parking numbers
    if (RegExp(r'parkir|parking', caseSensitive: false).hasMatch(text)) {
      return ScanType.parkingTicket;
    }
    return ScanType.unknown;
  }

  String _extractQRData(String data, ScanType type) {
    switch (type) {
      case ScanType.qris:
        // Extract payment info from QRIS
        return data.contains('amount') ? data.split('amount=')[1].split('&')[0] : data;
      case ScanType.parkingTicket:
        return data.replaceAll(RegExp(r'[^0-9]'), '');
      case ScanType.vehicleNumber:
        return data.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      default:
        return data;
    }
  }

  Map<String, dynamic> _buildQRMetadata(String data, ScanType type) {
    final metadata = <String, dynamic>{
      'scanMode': 'QR',
      'timestamp': DateTime.now().toIso8601String(),
    };

    switch (type) {
      case ScanType.qris:
        metadata['paymentMethod'] = 'QRIS';
        metadata['merchant'] = _extractMerchantFromQR(data);
        metadata['amount'] = _extractAmountFromQR(data);
        break;
      case ScanType.parkingTicket:
        metadata['ticketType'] = 'Parking';
        metadata['ticketId'] = data.replaceAll(RegExp(r'[^0-9]'), '');
        break;
      case ScanType.vehicleNumber:
        metadata['vehicleType'] = 'Unknown';
        metadata['plateNumber'] = data;
        break;
      default:
        metadata['rawData'] = data;
    }

    return metadata;
  }

  Map<String, dynamic> _buildBarcodeMetadata(String data, ScanType type) {
    return {
      'scanMode': 'Barcode',
      'timestamp': DateTime.now().toIso8601String(),
      'ticketId': data,
      'ticketType': type == ScanType.parkingTicket ? 'Parking' : 'Unknown',
    };
  }

  Map<String, dynamic> _buildOCRMetadata(String text, ScanType type) {
    return {
      'scanMode': 'OCR',
      'timestamp': DateTime.now().toIso8601String(),
      'text': text,
      'type': type.toString().split('.').last,
    };
  }

  String _extractMerchantFromQR(String data) {
    if (data.contains('merchant=')) {
      return data.split('merchant=')[1].split('&')[0];
    }
    return 'Unknown Merchant';
  }

  String _extractAmountFromQR(String data) {
    if (data.contains('amount=')) {
      return data.split('amount=')[1].split('&')[0];
    }
    return '0';
  }

  String _simulateOCRDetection() {
    // Simulate OCR detection for demo purposes
    final random = DateTime.now().millisecond;
    if (random % 3 == 0) {
      return 'B1234XYZ'; // Vehicle number
    } else if (random % 3 == 1) {
      return 'PARKING123456'; // Parking ticket
    } else {
      return 'QRIS1234567890'; // QRIS code
    }
  }

  Future<void> toggleFlash() async {
    if (_scannerController != null) {
      await _scannerController!.toggleTorch();
    }
  }

  bool get isFlashOn => _scannerController?.value.torchState == TorchState.on ?? false;

  // Payment processing methods
  Future<Map<String, dynamic>> processPayment(ScanResult result, double amount) async {
    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      
      return {
        'success': true,
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'scanResult': result,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'scanResult': result,
      };
    }
  }

  Future<Map<String, dynamic>> validateParkingTicket(String ticketId) async {
    try {
      // Simulate ticket validation
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulate different ticket statuses
      final random = DateTime.now().second;
      if (random % 5 == 0) {
        return {
          'valid': false,
          'error': 'Ticket not found or expired',
          'ticketId': ticketId,
        };
      }
      
      return {
        'valid': true,
        'ticketId': ticketId,
        'vehicleNumber': 'B1234XYZ',
        'entryTime': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'duration': '2 hours',
        'amount': 5000.0,
        'location': 'Parking Area A',
      };
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
        'ticketId': ticketId,
      };
    }
  }
}