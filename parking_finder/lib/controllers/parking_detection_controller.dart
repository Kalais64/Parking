import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/parking_slot.dart';
import 'map_controller.dart';

class ParkingDetectionController extends ChangeNotifier {
  CameraController? _cameraController;
  MapController? _mapController;
  List<ParkingSlot> _slots = [];
  bool _isProcessing = false;
  int _processInterval = 10; // Process every 10th frame
  int _frameCount = 0;
  
  // Image Mode State
  File? _selectedImageFile;
  img.Image? _decodedImage;
  bool _isImageMode = false;
  
  // Stats
  int _totalSlots = 0;
  int _emptySlots = 0;
  int _filledSlots = 0;

  List<ParkingSlot> get slots => _slots;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _cameraController?.value.isInitialized ?? false;
  int get totalSlots => _totalSlots;
  int get emptySlots => _emptySlots;
  int get filledSlots => _filledSlots;
  File? get selectedImageFile => _selectedImageFile;
  bool get isImageMode => _isImageMode;

  ParkingDetectionController() {
    _initializeSlots();
  }

  void setMapController(MapController mapController) {
    _mapController = mapController;
  }

  void _initializeSlots() {
    // Define dummy slots (normalized coordinates 0.0-1.0)
    // Assuming a grid layout for demo
    _slots = [
      ParkingSlot(id: 'S1', rect: const Rect.fromLTWH(0.1, 0.2, 0.2, 0.2), threshold: 80),
      ParkingSlot(id: 'S2', rect: const Rect.fromLTWH(0.4, 0.2, 0.2, 0.2), threshold: 80),
      ParkingSlot(id: 'S3', rect: const Rect.fromLTWH(0.7, 0.2, 0.2, 0.2), threshold: 80),
      ParkingSlot(id: 'S4', rect: const Rect.fromLTWH(0.1, 0.6, 0.2, 0.2), threshold: 80),
      ParkingSlot(id: 'S5', rect: const Rect.fromLTWH(0.4, 0.6, 0.2, 0.2), threshold: 80),
      ParkingSlot(id: 'S6', rect: const Rect.fromLTWH(0.7, 0.6, 0.2, 0.2), threshold: 80),
    ];
    _updateStats();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use the first camera (usually back camera)
    final camera = cameras.first;
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    
    // Start image stream for processing
    _cameraController!.startImageStream(_processCameraImage);
    
    notifyListeners();
  }

  void _processCameraImage(CameraImage image) {
    // Skip frames for performance
    _frameCount++;
    if (_frameCount % _processInterval != 0) return;
    if (_isProcessing) return;

    _isProcessing = true;
    
    try {
      // Process each slot
      for (int i = 0; i < _slots.length; i++) {
        final slot = _slots[i];
        final double avgBrightness = _calculateSlotBrightness(image, slot.rect);
        
        final bool isOccupied = avgBrightness < slot.threshold;
        
        // Update slot if status changed or brightness changed significantly
        if (slot.isOccupied != isOccupied || (slot.currentBrightness - avgBrightness).abs() > 5) {
          _slots[i] = slot.copyWith(
            currentBrightness: avgBrightness,
            isOccupied: isOccupied,
          );
        }
      }
      
      _updateStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateSlotBrightness(CameraImage image, Rect normalizedRect) {
    // Plane 0 is Y (Luminance)
    final Plane plane = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = plane.bytes;

    // Convert normalized rect to pixel coordinates
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);

    int totalBrightness = 0;
    int pixelCount = 0;
    
    // Sampling step to reduce calculation time (process every 4th pixel)
    const int step = 4;

    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        // YUV420 index calculation for Y plane
        final int index = y * plane.bytesPerRow + x;
        if (index < bytes.length) {
          totalBrightness += bytes[index];
          pixelCount++;
        }
      }
    }

    if (pixelCount == 0) return 0.0;
    return totalBrightness / pixelCount;
  }

  void _updateStats() {
    _totalSlots = _slots.length;
    _filledSlots = _slots.where((s) => s.isOccupied).length;
    _emptySlots = _totalSlots - _filledSlots;

    // Update MapController if available
    // Assuming '1' is the ID of the parking location we are simulating
    _mapController?.updateParkingRealtime('1', _emptySlots, _totalSlots);
  }

  void updateThreshold(String slotId, double newThreshold) {
    final index = _slots.indexWhere((s) => s.id == slotId);
    if (index != -1) {
      _slots[index] = _slots[index].copyWith(threshold: newThreshold);
      notifyListeners();
    }
  }

  void updateAllThresholds(double newThreshold) {
    for (int i = 0; i < _slots.length; i++) {
      _slots[i] = _slots[i].copyWith(threshold: newThreshold);
    }
    notifyListeners();
  }

  // --- Image Mode Logic ---

  Future<void> pickAndProcessImage(String path) async {
    _isImageMode = true;
    _selectedImageFile = File(path);
    
    // Stop camera if running
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    
    _isProcessing = true;
    notifyListeners();

    try {
      final bytes = await _selectedImageFile!.readAsBytes();
      _decodedImage = img.decodeImage(bytes);
      
      if (_decodedImage != null) {
        _processStaticImage(_decodedImage!);
      }
    } catch (e) {
      debugPrint('Error processing image file: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void switchToCameraMode() {
    _isImageMode = false;
    _selectedImageFile = null;
    _decodedImage = null;
    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
        // Restart camera stream if it was stopped
        // Ideally we might need to re-initialize or just start stream
        // But for simplicity, let's re-init if needed or just let the UI call initializeCamera
        // Actually, initializeCamera handles re-init.
    }
    initializeCamera();
  }

  void _processStaticImage(img.Image image) {
      for (int i = 0; i < _slots.length; i++) {
        final slot = _slots[i];
        final double avgBrightness = _calculateSlotBrightnessFromImage(image, slot.rect);
        
        final bool isOccupied = avgBrightness < slot.threshold;
        
        _slots[i] = slot.copyWith(
            currentBrightness: avgBrightness,
            isOccupied: isOccupied,
        );
      }
      _updateStats();
  }

  double _calculateSlotBrightnessFromImage(img.Image image, Rect normalizedRect) {
    final int width = image.width;
    final int height = image.height;
    
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);

    int totalBrightness = 0;
    int pixelCount = 0;
    const int step = 4;

    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        totalBrightness += ((r + g + b) ~/ 3);
        pixelCount++;
      }
    }

    if (pixelCount == 0) return 0.0;
    return totalBrightness / pixelCount;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}