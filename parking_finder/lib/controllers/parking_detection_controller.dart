import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
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
  Uint8List? _selectedImageBytes;
  
  // Stats
  int _totalSlots = 0;
  int _emptySlots = 0;
  int _filledSlots = 0;
  double _statusMargin = 15.0;
  int _gridRows = 2;
  int _gridCols = 4;
  double _occupancyRatio = 0.35;
  double _sigmaThreshold = 40.0;
  double _innerPadding = 0.10;
  double _edgeRatioThreshold = 0.10;
  int _edgeMagThreshold = 40;

  List<ParkingSlot> get slots => _slots;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _cameraController?.value.isInitialized ?? false;
  int get totalSlots => _totalSlots;
  int get emptySlots => _emptySlots;
  int get filledSlots => _filledSlots;
  File? get selectedImageFile => _selectedImageFile;
  bool get isImageMode => _isImageMode;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  int get gridRows => _gridRows;
  int get gridCols => _gridCols;
  double get occupancyRatio => _occupancyRatio;
  double get sigmaThreshold => _sigmaThreshold;
  double get innerPadding => _innerPadding;
  double get edgeRatioThreshold => _edgeRatioThreshold;
  int get edgeMagThreshold => _edgeMagThreshold;

  ParkingDetectionController() {
    _initializeSlots();
  }

  void setMapController(MapController mapController) {
    _mapController = mapController;
  }

  void _initializeSlots() {
    _generateSlotsFromGrid();
    _updateStats();
  }

  void setGrid(int rows, int cols) {
    _gridRows = rows.clamp(2, 10);
    _gridCols = cols.clamp(2, 10);
    _generateSlotsFromGrid();
    _updateStats();
    notifyListeners();
  }

  void setOccupancyRatio(double v) {
    _occupancyRatio = v.clamp(0.05, 0.95);
    notifyListeners();
  }

  void setSigmaThreshold(double v) {
    _sigmaThreshold = v.clamp(5.0, 120.0);
    notifyListeners();
  }

  void setInnerPadding(double v) {
    _innerPadding = v.clamp(0.0, 0.3);
    notifyListeners();
  }

  void setEdgeRatioThreshold(double v) {
    _edgeRatioThreshold = v.clamp(0.01, 0.5);
    notifyListeners();
  }

  void setEdgeMagThreshold(int v) {
    _edgeMagThreshold = v.clamp(5, 255);
    notifyListeners();
  }

  void _generateSlotsFromGrid() {
    final List<ParkingSlot> newSlots = [];
    final double cellW = 1.0 / _gridCols;
    final double cellH = 1.0 / _gridRows;
    const double padX = 0.02;
    const double padY = 0.02;
    int idCounter = 1;
    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols; c++) {
        final double left = c * cellW + padX;
        final double top = r * cellH + padY;
        final double width = cellW - 2 * padX;
        final double height = cellH - 2 * padY;
        newSlots.add(
          ParkingSlot(
            id: 'S$idCounter',
            rect: Rect.fromLTWH(left, top, width, height),
            threshold: 150,
          ),
        );
        idCounter++;
      }
    }
    _slots = newSlots;
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
      for (int i = 0; i < _slots.length; i++) {
        final slot = _slots[i];
        final rect = _innerRect(slot.rect, _innerPadding);
        final histResult = _calculateHistogramFromCamera(image, rect);
        final List<int> hist = histResult.$1;
        final int total = histResult.$2;
        final int otsu = _otsuThreshold(hist, total);
        final stats = _calculateStatsFromCamera(image, rect, otsu);
        final double avgBrightness = stats.$1;
        final double darkRatio = stats.$2;
        final double edgeDensity = _edgeDensityFromCamera(image, rect, _edgeMagThreshold);
        final bool candidateOccupied = darkRatio > _occupancyRatio && edgeDensity > _edgeRatioThreshold;
        _slots[i] = slot.copyWith(
          currentBrightness: avgBrightness,
          threshold: otsu.toDouble(),
          isOccupied: candidateOccupied,
        );
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

  (List<int>, int) _calculateHistogramFromCamera(CameraImage image, Rect normalizedRect) {
    final Plane plane = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = plane.bytes;
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);
    final List<int> hist = List<int>.filled(256, 0);
    int total = 0;
    const int step = 4;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final int index = y * plane.bytesPerRow + x;
        if (index < bytes.length) {
          final int v = bytes[index];
          hist[v]++;
          total++;
        }
      }
    }
    return (hist, total);
  }

  (double, double, double) _calculateStatsFromCamera(CameraImage image, Rect normalizedRect, int threshold) {
    final Plane plane = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = plane.bytes;
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);
    int sum = 0;
    int sumSq = 0;
    int dark = 0;
    int count = 0;
    const int step = 4;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final int index = y * plane.bytesPerRow + x;
        if (index < bytes.length) {
          final int v = bytes[index];
          sum += v;
          sumSq += v * v;
          if (v <= threshold) dark++;
          count++;
        }
      }
    }
    if (count == 0) return (0.0, 0.0, 0.0);
    final double avg = sum / count;
    final double variance = (sumSq / count) - (avg * avg);
    final double sigma = variance < 0 ? 0.0 : math.sqrt(variance);
    final double darkRatio = dark / count;
    return (avg, darkRatio, sigma);
  }

  void _updateStats() {
    _totalSlots = _slots.length;
    _filledSlots = _slots.where((s) => s.isOccupied).length;
    _emptySlots = _totalSlots - _filledSlots;

    final id = _mapController?.selectedParking?.id;
    if (id != null) {
      _mapController?.updateParkingRealtime(id, _emptySlots, _totalSlots);
    }
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
    _selectedImageBytes = null;
    
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
        _processStaticImageAdaptive(_decodedImage!);
      }
    } catch (e) {
      debugPrint('Error processing image file: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> pickAndProcessBytes(Uint8List bytes) async {
    _isImageMode = true;
    _selectedImageBytes = bytes;
    _selectedImageFile = null;

    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    _isProcessing = true;
    notifyListeners();

    try {
      _decodedImage = img.decodeImage(bytes);
      if (_decodedImage != null) {
        _processStaticImageAdaptive(_decodedImage!);
      }
    } catch (e) {
      debugPrint('Error processing image bytes: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void switchToCameraMode() {
    _isImageMode = false;
    _selectedImageFile = null;
    _decodedImage = null;
    _selectedImageBytes = null;
    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
        // Restart camera stream if it was stopped
        // Ideally we might need to re-initialize or just start stream
        // But for simplicity, let's re-init if needed or just let the UI call initializeCamera
        // Actually, initializeCamera handles re-init.
    }
    initializeCamera();
  }

  void _processStaticImageAdaptive(img.Image image, {double occupancyRatio = 0.35}) {
    for (int i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      final rect = _innerRect(slot.rect, _innerPadding);
      final histResult = _calculateHistogramFromImage(image, rect);
      final List<int> hist = histResult.$1;
      final int total = histResult.$2;
      final int otsu = _otsuThreshold(hist, total);
      final stats = _calculateStatsFromImage(image, rect, otsu);
      final double avgBrightness = stats.$1;
      final double darkRatio = stats.$2;
      final double edgeDensity = _edgeDensityFromImage(image, rect, _edgeMagThreshold);
      final bool candidateOccupied = darkRatio > _occupancyRatio && edgeDensity > _edgeRatioThreshold;
      _slots[i] = slot.copyWith(
        currentBrightness: avgBrightness,
        threshold: otsu.toDouble(),
        isOccupied: candidateOccupied,
      );
    }
    _updateStats();
  }

  (List<int>, int) _calculateHistogramFromImage(img.Image image, Rect normalizedRect) {
    final int width = image.width;
    final int height = image.height;
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);
    final List<int> hist = List<int>.filled(256, 0);
    int total = 0;
    const int step = 4;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final p = image.getPixel(x, y);
        final int v = ((p.r + p.g + p.b) ~/ 3);
        hist[v]++;
        total++;
      }
    }
    return (hist, total);
  }

  (double, double, double) _calculateStatsFromImage(img.Image image, Rect normalizedRect, int threshold) {
    final int width = image.width;
    final int height = image.height;
    final int startX = (normalizedRect.left * width).toInt().clamp(0, width - 1);
    final int startY = (normalizedRect.top * height).toInt().clamp(0, height - 1);
    final int endX = (normalizedRect.right * width).toInt().clamp(0, width - 1);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(0, height - 1);
    int sumBrightness = 0;
    int sumSq = 0;
    int darkCount = 0;
    int count = 0;
    const int step = 4;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final p = image.getPixel(x, y);
        final int v = ((p.r + p.g + p.b) ~/ 3);
        sumBrightness += v;
        sumSq += v * v;
        if (v <= threshold) darkCount++;
        count++;
      }
    }
    if (count == 0) return (0.0, 0.0, 0.0);
    final double avgBrightness = sumBrightness / count;
    final double variance = (sumSq / count) - (avgBrightness * avgBrightness);
    final double sigma = variance < 0 ? 0.0 : math.sqrt(variance);
    final double darkRatio = darkCount / count;
    return (avgBrightness, darkRatio, sigma);
  }

  double _edgeDensityFromImage(img.Image image, Rect normalizedRect, int magThreshold) {
    final int width = image.width;
    final int height = image.height;
    final int startX = (normalizedRect.left * width).toInt().clamp(1, width - 2);
    final int startY = (normalizedRect.top * height).toInt().clamp(1, height - 2);
    final int endX = (normalizedRect.right * width).toInt().clamp(1, width - 2);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(1, height - 2);
    int edges = 0;
    int count = 0;
    const int step = 2;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        int p00 = ((image.getPixel(x - 1, y - 1).r + image.getPixel(x - 1, y - 1).g + image.getPixel(x - 1, y - 1).b) ~/ 3);
        int p10 = ((image.getPixel(x, y - 1).r + image.getPixel(x, y - 1).g + image.getPixel(x, y - 1).b) ~/ 3);
        int p20 = ((image.getPixel(x + 1, y - 1).r + image.getPixel(x + 1, y - 1).g + image.getPixel(x + 1, y - 1).b) ~/ 3);
        int p01 = ((image.getPixel(x - 1, y).r + image.getPixel(x - 1, y).g + image.getPixel(x - 1, y).b) ~/ 3);
        int p21 = ((image.getPixel(x + 1, y).r + image.getPixel(x + 1, y).g + image.getPixel(x + 1, y).b) ~/ 3);
        int p02 = ((image.getPixel(x - 1, y + 1).r + image.getPixel(x - 1, y + 1).g + image.getPixel(x - 1, y + 1).b) ~/ 3);
        int p12 = ((image.getPixel(x, y + 1).r + image.getPixel(x, y + 1).g + image.getPixel(x, y + 1).b) ~/ 3);
        int p22 = ((image.getPixel(x + 1, y + 1).r + image.getPixel(x + 1, y + 1).g + image.getPixel(x + 1, y + 1).b) ~/ 3);
        int gx = -p00 + p20 - 2 * p01 + 2 * p21 - p02 + p22;
        int gy = -p00 - 2 * p10 - p20 + p02 + 2 * p12 + p22;
        double mag = math.sqrt((gx * gx + gy * gy).toDouble());
        if (mag >= magThreshold) edges++;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return edges / count;
  }

  double _edgeDensityFromCamera(CameraImage image, Rect normalizedRect, int magThreshold) {
    final Plane plane = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = plane.bytes;
    final int startX = (normalizedRect.left * width).toInt().clamp(1, width - 2);
    final int startY = (normalizedRect.top * height).toInt().clamp(1, height - 2);
    final int endX = (normalizedRect.right * width).toInt().clamp(1, width - 2);
    final int endY = (normalizedRect.bottom * height).toInt().clamp(1, height - 2);
    int edges = 0;
    int count = 0;
    const int step = 2;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        int p00 = bytes[(y - 1) * plane.bytesPerRow + (x - 1)];
        int p10 = bytes[(y - 1) * plane.bytesPerRow + x];
        int p20 = bytes[(y - 1) * plane.bytesPerRow + (x + 1)];
        int p01 = bytes[y * plane.bytesPerRow + (x - 1)];
        int p21 = bytes[y * plane.bytesPerRow + (x + 1)];
        int p02 = bytes[(y + 1) * plane.bytesPerRow + (x - 1)];
        int p12 = bytes[(y + 1) * plane.bytesPerRow + x];
        int p22 = bytes[(y + 1) * plane.bytesPerRow + (x + 1)];
        int gx = -p00 + p20 - 2 * p01 + 2 * p21 - p02 + p22;
        int gy = -p00 - 2 * p10 - p20 + p02 + 2 * p12 + p22;
        double mag = math.sqrt((gx * gx + gy * gy).toDouble());
        if (mag >= magThreshold) edges++;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return edges / count;
  }

  Rect _innerRect(Rect r, double pad) {
    final double px = (r.width * pad);
    final double py = (r.height * pad);
    final double left = (r.left + px).clamp(0.0, 1.0);
    final double top = (r.top + py).clamp(0.0, 1.0);
    final double right = (r.right - px).clamp(0.0, 1.0);
    final double bottom = (r.bottom - py).clamp(0.0, 1.0);
    final double w = (right - left).clamp(0.01, 1.0);
    final double h = (bottom - top).clamp(0.01, 1.0);
    return Rect.fromLTWH(left, top, w, h);
  }
  int _otsuThreshold(List<int> hist, int total) {
    if (total == 0) return 128;
    double sum = 0;
    for (int t = 0; t < 256; t++) {
      sum += t * hist[t];
    }
    double sumB = 0;
    int wB = 0;
    double varMax = 0;
    int threshold = 0;
    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      int wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      double mB = sumB / wB;
      double mF = (sum - sumB) / wF;
      double varBetween = wB * wF * (mB - mF) * (mB - mF);
      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }
    return threshold;
  }

  void autoCalibrateFromCurrentImage({double occupancyRatio = 0.35}) {
    if (_decodedImage != null) {
      _processStaticImageAdaptive(_decodedImage!, occupancyRatio: occupancyRatio);
      notifyListeners();
    }
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