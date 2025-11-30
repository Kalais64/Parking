import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_database/firebase_database.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../models/parking_slot.dart';
import 'map_controller.dart';

class ParkingDetectionController extends ChangeNotifier {
  CameraController? _cameraController;
  MapController? _mapController;
  List<ParkingSlot> _slots = [];
  bool _isProcessing = false;
  int _processInterval = 10; // Process every 10th frame
  int _frameCount = 0;
  StreamSubscription<DatabaseEvent>? _dbSubscription;
  Map<String, int> _lastStatus = {};
  
  // Image Mode State
  File? _selectedImageFile;
  img.Image? _decodedImage;
  bool _isImageMode = false;
  
  // Stats
  int _totalSlots = 0;
  int _emptySlots = 0;
  int _filledSlots = 0;
  double _statusMargin = 8.0;

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
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.first;

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController?.initialize();

      _cameraController?.startImageStream(_processCameraImage);

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void startRealtimeSubscription() {
    try {
      _dbSubscription?.cancel();
      final ref = FirebaseDatabase.instance.ref('/parking_status');
      _dbSubscription = ref.onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final Map<String, int> newStatus = {};
          data.forEach((key, value) {
            try {
              final intVal = value is int ? value : int.tryParse('$value') ?? 0;
              newStatus[key.toString()] = intVal;
            } catch (_) {}
          });

          for (final entry in newStatus.entries) {
            final slotId = entry.key;
            final occupied = entry.value == 1;
            final index = _slots.indexWhere((s) => s.id == slotId);
            if (index != -1) {
              final prevOccupied = _slots[index].isOccupied;
              if (prevOccupied && !occupied) {
                NotificationService().showToast(
                  title: 'Slot tersedia',
                  message: 'Slot $slotId baru saja kosong',
                  type: NotificationType.parkingAvailable,
                  priority: NotificationPriority.high,
                );
              }
              _slots[index] = _slots[index].copyWith(
                isOccupied: occupied,
              );
            }
          }

          _lastStatus = newStatus;
          _updateStats();
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Realtime DB error: $error');
      });
    } catch (e) {
      debugPrint('Error starting realtime subscription: $e');
    }
  }

  void stopRealtimeSubscription() {
    _dbSubscription?.cancel();
    _dbSubscription = null;
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
        
        final bool candidateOccupied =
            avgBrightness < (slot.threshold - _statusMargin)
                ? true
                : avgBrightness > (slot.threshold + _statusMargin)
                    ? false
                    : slot.isOccupied;
        
        // Update slot if status changed or brightness changed significantly
        if (slot.isOccupied != candidateOccupied || (slot.currentBrightness - avgBrightness).abs() > 5) {
          _slots[i] = slot.copyWith(
            currentBrightness: avgBrightness,
            isOccupied: candidateOccupied,
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

    final id = _mapController?.selectedParking?.id ?? '1';
    _mapController?.updateParkingRealtime(id, _emptySlots, _totalSlots);
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
        
        final bool candidateOccupied =
            avgBrightness < (slot.threshold - _statusMargin)
                ? true
                : avgBrightness > (slot.threshold + _statusMargin)
                    ? false
                    : slot.isOccupied;
        
        _slots[i] = slot.copyWith(
            currentBrightness: avgBrightness,
            isOccupied: candidateOccupied,
        );
      }
      _updateStats();
  }

  Future<int> countEmptySlotsFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return 0;
    return countEmptySlotsFromImage(decoded);
  }

  int countEmptySlotsFromImage(img.Image image) {
    int empty = 0;
    for (final slot in _slots) {
      final avgBrightness = _calculateSlotBrightnessFromImage(image, slot.rect);
      final candidateOccupied =
          avgBrightness < (slot.threshold - _statusMargin)
              ? true
              : avgBrightness > (slot.threshold + _statusMargin)
                  ? false
                  : slot.isOccupied;
      if (!candidateOccupied) empty++;
    }
    return empty;
  }

  void updateSlotRect(String slotId, Rect newRect) {
    final index = _slots.indexWhere((s) => s.id == slotId);
    if (index == -1) return;
    final clamped = Rect.fromLTWH(
      newRect.left.clamp(0.0, 1.0),
      newRect.top.clamp(0.0, 1.0),
      newRect.width.clamp(0.01, 1.0),
      newRect.height.clamp(0.01, 1.0),
    );
    _slots[index] = _slots[index].copyWith(rect: clamped);
    notifyListeners();
  }

  void updateSlotRectByDelta(String slotId, {double dx = 0, double dy = 0, double dWidth = 0, double dHeight = 0}) {
    final index = _slots.indexWhere((s) => s.id == slotId);
    if (index == -1) return;
    final r = _slots[index].rect;
    final left = (r.left + dx).clamp(0.0, 1.0);
    final top = (r.top + dy).clamp(0.0, 1.0);
    final width = (r.width + dWidth).clamp(0.01, 1.0 - left);
    final height = (r.height + dHeight).clamp(0.01, 1.0 - top);
    final nr = Rect.fromLTWH(left, top, width, height);
    _slots[index] = _slots[index].copyWith(rect: nr);
    notifyListeners();
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
    _dbSubscription?.cancel();
    super.dispose();
  }
}