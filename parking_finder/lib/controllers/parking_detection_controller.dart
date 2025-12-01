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
  int? _sensorOrientation;
  bool _isFrontCamera = false;
  bool _dbSyncEnabled = false;
  bool _autoLiveCalibrationEnabled = false;
  DateTime? _lastCalibrateAt;
  int _calibrateIntervalMs = 2500;
  double _baselineMedianBrightness = 0.0;
  double _driftThreshold = 8.0;
  double _emaAlpha = 0.35;
  Timer? _stillTimer;
  int _stillIntervalMs = 900;
  
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
  double _chromaThreshold = 30.0;
  double _colorRatioThreshold = 0.20;

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
  double get chromaThreshold => _chromaThreshold;
  double get colorRatioThreshold => _colorRatioThreshold;
  double? get previewAspectRatio {
    final s = _cameraController?.value.previewSize;
    if (s != null) {
      return s.width / s.height;
    }
    if (_decodedImage != null) {
      return _decodedImage!.width / _decodedImage!.height;
    }
    return null;
  }

  bool get autoLiveCalibrationEnabled => _autoLiveCalibrationEnabled;

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

  void setChromaThreshold(double v) {
    _chromaThreshold = v.clamp(15.0, 120.0);
    notifyListeners();
  }

  void setColorRatioThreshold(double v) {
    _colorRatioThreshold = v.clamp(0.05, 0.80);
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
      _sensorOrientation = camera.sensorOrientation;
      _isFrontCamera = camera.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );

      await _cameraController?.initialize();

      if (kIsWeb) {
        _startStillCaptureLoop();
      } else {
        _cameraController?.startImageStream(_processCameraImage);
      }

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

          if (_dbSyncEnabled) {
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

  Future<void> releaseCamera() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }
      _stillTimer?.cancel();
      _stillTimer = null;
    } catch (e) {
      debugPrint('Error releasing camera: $e');
    }
  }

  void resetDetectionState({bool resetGrid = false}) {
    _isImageMode = false;
    _selectedImageFile = null;
    _selectedImageBytes = null;
    _decodedImage = null;
    if (resetGrid) {
      _generateSlotsFromGrid();
    }
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      _slots[i] = s.copyWith(
        isOccupied: false,
        currentBrightness: 0.0,
        darkRatio: 0.0,
        edgeDensity: 0.0,
        sigma: 0.0,
      );
    }
    _updateStats();
    notifyListeners();
  }

  void _processCameraImage(CameraImage image) {
    // Skip frames for performance
    _frameCount++;
    if (_frameCount % _processInterval != 0) return;
    if (_isProcessing) return;
    if (image.planes.isEmpty || image.planes[0].bytes.isEmpty) {
      if (kIsWeb) {
        _startStillCaptureLoop();
      }
      return;
    }

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
        final double sigma = stats.$3;
        final double edgeDensity = _edgeDensityFromCamera(image, rect, _edgeMagThreshold);
        final chromaStats = _calculateChromaStatsFromCamera(image, rect);
        final double avgChroma = chromaStats.$1;
        final double colorRatio = chromaStats.$2;
        final bool darknessOccupied = avgBrightness < (otsu - _statusMargin) || darkRatio > _occupancyRatio;
        final bool colorOccupied = avgChroma > _chromaThreshold || colorRatio > _colorRatioThreshold;
        final bool textureOccupied = edgeDensity > _edgeRatioThreshold || sigma > _sigmaThreshold;
        final bool candidateOccupied = (darknessOccupied || colorOccupied) && textureOccupied;
        _slots[i] = slot.copyWith(
          currentBrightness: avgBrightness,
          threshold: otsu.toDouble(),
          isOccupied: candidateOccupied,
          darkRatio: darkRatio,
          edgeDensity: edgeDensity,
          sigma: sigma,
          chroma: avgChroma,
          colorRatio: colorRatio,
        );
      }
      
      _updateStats();
      if (_autoLiveCalibrationEnabled) {
        final List<double> b = _slots.map((s) => s.currentBrightness).toList();
        final double medB = _percentile(b, 0.50);
        final DateTime now = DateTime.now();
        final bool timeOk = _lastCalibrateAt == null || now.difference(_lastCalibrateAt!).inMilliseconds >= _calibrateIntervalMs;
        final bool driftOk = _baselineMedianBrightness == 0.0 || (medB - _baselineMedianBrightness).abs() >= _driftThreshold;
        if (timeOk || driftOk) {
          _autoCalibrateSmooth();
          _lastCalibrateAt = now;
          _baselineMedianBrightness = medB;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _startStillCaptureLoop() {
    if (_stillTimer != null) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _stillTimer = Timer.periodic(Duration(milliseconds: _stillIntervalMs), (t) async {
      if (_isProcessing) return;
      try {
        final XFile xf = await _cameraController!.takePicture();
        final Uint8List bytes = await xf.readAsBytes();
        final img.Image? decoded = img.decodeImage(bytes);
        if (decoded != null) {
          _isProcessing = true;
          _processStaticImageAdaptive(decoded);
          _isProcessing = false;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Still capture failed: $e');
      }
    });
  }

  double _calculateSlotBrightness(CameraImage image, Rect normalizedRect) {
    final Plane plane = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = plane.bytes;
    final Rect r = _transformRectForCamera(normalizedRect);
    final int startX = (r.left * width).toInt().clamp(0, width - 1);
    final int startY = (r.top * height).toInt().clamp(0, height - 1);
    final int endX = (r.right * width).toInt().clamp(0, width - 1);
    final int endY = (r.bottom * height).toInt().clamp(0, height - 1);
    int totalBrightness = 0;
    int pixelCount = 0;
    final int step = math.max(2, (math.min(width, height) / 200).floor());
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
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
    final Rect r = _transformRectForCamera(normalizedRect);
    final int startX = (r.left * width).toInt().clamp(0, width - 1);
    final int startY = (r.top * height).toInt().clamp(0, height - 1);
    final int endX = (r.right * width).toInt().clamp(0, width - 1);
    final int endY = (r.bottom * height).toInt().clamp(0, height - 1);
    final List<int> hist = List<int>.filled(256, 0);
    int total = 0;
    final int step = math.max(2, (math.min(width, height) / 200).floor());
    final int bppGuess = plane.bytesPerPixel ?? (plane.bytesPerRow ~/ math.max(1, width));
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final int base = y * plane.bytesPerRow + x * bppGuess;
        if (base < bytes.length) {
          int v;
          if (bppGuess >= 3 && base + 2 < bytes.length) {
            final int b = bytes[base];
            final int g = bytes[base + 1];
            final int r = bytes[base + 2];
            v = ((r + g + b) ~/ 3);
          } else {
            v = bytes[base];
          }
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
    final Rect r = _transformRectForCamera(normalizedRect);
    final int startX = (r.left * width).toInt().clamp(0, width - 1);
    final int startY = (r.top * height).toInt().clamp(0, height - 1);
    final int endX = (r.right * width).toInt().clamp(0, width - 1);
    final int endY = (r.bottom * height).toInt().clamp(0, height - 1);
    int sum = 0;
    int sumSq = 0;
    int dark = 0;
    int count = 0;
    final int step = math.max(2, (math.min(width, height) / 200).floor());
    final int bppGuess = plane.bytesPerPixel ?? (plane.bytesPerRow ~/ math.max(1, width));
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final int base = y * plane.bytesPerRow + x * bppGuess;
        if (base < bytes.length) {
          int v;
          if (bppGuess >= 3 && base + 2 < bytes.length) {
            final int b = bytes[base];
            final int g = bytes[base + 1];
            final int r = bytes[base + 2];
            v = ((r + g + b) ~/ 3);
          } else {
            v = bytes[base];
          }
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

  (double, double) _calculateChromaStatsFromCamera(CameraImage image, Rect normalizedRect) {
    final Plane p0 = image.planes[0];
    final int width = image.width;
    final int height = image.height;
    final Rect sr = _edgeSampleRect(normalizedRect);
    final Rect r = _transformRectForCamera(sr);
    final int startX = (r.left * width).toInt().clamp(0, width - 1);
    final int startY = (r.top * height).toInt().clamp(0, height - 1);
    final int endX = (r.right * width).toInt().clamp(0, width - 1);
    final int endY = (r.bottom * height).toInt().clamp(0, height - 1);
    int count = 0;
    int colored = 0;
    double sumChroma = 0.0;
    final int step = math.max(1, (math.min(width, height) / 300).floor());
    final int bpr = p0.bytesPerRow;
    final int bpp = p0.bytesPerPixel ?? (bpr ~/ math.max(1, width));
    if (bpp >= 3) {
      // RGBA/BGRA path: use saturation (max-min) as chroma
      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final int base = y * bpr + x * bpp;
          if (base + 2 < p0.bytes.length) {
            final int b = p0.bytes[base];
            final int g = p0.bytes[base + 1];
            final int r = p0.bytes[base + 2];
            final int mx = math.max(r, math.max(g, b));
            final int mn = math.min(r, math.min(g, b));
            final int sat = mx - mn; // 0..255
            sumChroma += sat.toDouble();
            if (sat.toDouble() > _chromaThreshold) colored++;
            count++;
          }
        }
      }
    } else {
      // YUV path: use U/V
      final Plane up = image.planes.length > 1 ? image.planes[1] : image.planes[0];
      final Plane vp = image.planes.length > 2 ? image.planes[2] : image.planes[0];
      final int ubpr = up.bytesPerRow;
      final int vbpr = vp.bytesPerRow;
      final int ubpp = up.bytesPerPixel ?? 1;
      final int vbpp = vp.bytesPerPixel ?? 1;
      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final int ux = (x >> 1);
          final int uy = (y >> 1);
          final int ui = uy * ubpr + ux * ubpp;
          final int vi = uy * vbpr + ux * vbpp;
          if (ui < up.bytes.length && vi < vp.bytes.length) {
            final int u = up.bytes[ui];
            final int v = vp.bytes[vi];
            final double chroma = math.sqrt(((u - 128) * (u - 128) + (v - 128) * (v - 128)).toDouble());
            sumChroma += chroma;
            if (chroma > _chromaThreshold) colored++;
            count++;
          }
        }
      }
    }
    if (count == 0) return (0.0, 0.0);
    return (sumChroma / count, colored / count);
  }

  void _updateStats() {
    _totalSlots = _slots.length;
    _filledSlots = _slots.where((s) => s.isOccupied).length;
    _emptySlots = _totalSlots - _filledSlots;

    if (_dbSyncEnabled) {
      final id = _mapController?.selectedParking?.id;
      if (id != null) {
        _mapController?.updateParkingRealtime(id, _emptySlots, _totalSlots);
      }
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
    
    // Nonaktifkan kamera live (stream atau still-capture)
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
    _stillTimer?.cancel();
    _stillTimer = null;
    
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

    // Nonaktifkan kamera live (stream atau still-capture)
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
    _stillTimer?.cancel();
    _stillTimer = null;

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
    resetDetectionState();
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
      final double sigma = stats.$3;
      final double edgeDensity = _edgeDensityFromImage(image, rect, _edgeMagThreshold);
      final bool darknessOccupied = avgBrightness < (otsu - _statusMargin) || darkRatio > _occupancyRatio;
      final bool textureOccupied = edgeDensity > _edgeRatioThreshold || sigma > _sigmaThreshold;
      final bool candidateOccupied = darknessOccupied && textureOccupied;
      _slots[i] = slot.copyWith(
        currentBrightness: avgBrightness,
        threshold: otsu.toDouble(),
        isOccupied: candidateOccupied,
        darkRatio: darkRatio,
        edgeDensity: edgeDensity,
        sigma: sigma,
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
    final Rect r = _edgeSampleRect(normalizedRect);
    final int width = image.width;
    final int height = image.height;
    final int startX = (r.left * width).toInt().clamp(1, width - 2);
    final int startY = (r.top * height).toInt().clamp(1, height - 2);
    final int endX = (r.right * width).toInt().clamp(1, width - 2);
    final int endY = (r.bottom * height).toInt().clamp(1, height - 2);
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
    final Rect sr = _edgeSampleRect(normalizedRect);
    final Rect r = _transformRectForCamera(sr);
    final int startX = (r.left * width).toInt().clamp(1, width - 2);
    final int startY = (r.top * height).toInt().clamp(1, height - 2);
    final int endX = (r.right * width).toInt().clamp(1, width - 2);
    final int endY = (r.bottom * height).toInt().clamp(1, height - 2);
    int edges = 0;
    int count = 0;
    final int step = math.max(2, (math.min(width, height) / 300).floor());
    final int bppGuess = plane.bytesPerPixel ?? (plane.bytesPerRow ~/ math.max(1, width));
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        int base00 = (y - 1) * plane.bytesPerRow + (x - 1) * bppGuess;
        int base10 = (y - 1) * plane.bytesPerRow + x * bppGuess;
        int base20 = (y - 1) * plane.bytesPerRow + (x + 1) * bppGuess;
        int base01 = y * plane.bytesPerRow + (x - 1) * bppGuess;
        int base21 = y * plane.bytesPerRow + (x + 1) * bppGuess;
        int base02 = (y + 1) * plane.bytesPerRow + (x - 1) * bppGuess;
        int base12 = (y + 1) * plane.bytesPerRow + x * bppGuess;
        int base22 = (y + 1) * plane.bytesPerRow + (x + 1) * bppGuess;
        int p00 = 0, p10 = 0, p20 = 0, p01 = 0, p21 = 0, p02 = 0, p12 = 0, p22 = 0;
        if (base00 >= 0 && base22 + 2 < bytes.length) {
          if (bppGuess >= 3) {
            p00 = ((bytes[base00 + 2] + bytes[base00 + 1] + bytes[base00]) ~/ 3);
            p10 = ((bytes[base10 + 2] + bytes[base10 + 1] + bytes[base10]) ~/ 3);
            p20 = ((bytes[base20 + 2] + bytes[base20 + 1] + bytes[base20]) ~/ 3);
            p01 = ((bytes[base01 + 2] + bytes[base01 + 1] + bytes[base01]) ~/ 3);
            p21 = ((bytes[base21 + 2] + bytes[base21 + 1] + bytes[base21]) ~/ 3);
            p02 = ((bytes[base02 + 2] + bytes[base02 + 1] + bytes[base02]) ~/ 3);
            p12 = ((bytes[base12 + 2] + bytes[base12 + 1] + bytes[base12]) ~/ 3);
            p22 = ((bytes[base22 + 2] + bytes[base22 + 1] + bytes[base22]) ~/ 3);
          } else {
            p00 = bytes[base00];
            p10 = bytes[base10];
            p20 = bytes[base20];
            p01 = bytes[base01];
            p21 = bytes[base21];
            p02 = bytes[base02];
            p12 = bytes[base12];
            p22 = bytes[base22];
          }
        }
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

  Rect _rotateCW(Rect r) {
    final double left = 1.0 - r.bottom;
    final double top = r.left;
    final double right = 1.0 - r.top;
    final double bottom = r.right;
    return Rect.fromLTRB(left.clamp(0.0, 1.0), top.clamp(0.0, 1.0), right.clamp(0.0, 1.0), bottom.clamp(0.0, 1.0));
  }
  Rect _rotateCCW(Rect r) {
    final double left = r.top;
    final double top = 1.0 - r.right;
    final double right = r.bottom;
    final double bottom = 1.0 - r.left;
    return Rect.fromLTRB(left.clamp(0.0, 1.0), top.clamp(0.0, 1.0), right.clamp(0.0, 1.0), bottom.clamp(0.0, 1.0));
  }
  Rect _mirrorH(Rect r) {
    final double left = 1.0 - r.right;
    final double right = 1.0 - r.left;
    return Rect.fromLTRB(left.clamp(0.0, 1.0), r.top, right.clamp(0.0, 1.0), r.bottom);
  }
  Rect _transformRectForCamera(Rect nr) {
    Rect r = nr;
    if (_sensorOrientation == 90) {
      r = _rotateCW(r);
    } else if (_sensorOrientation == 270) {
      r = _rotateCCW(r);
    }
    if (_isFrontCamera) {
      r = _mirrorH(r);
    }
    final double left = r.left.clamp(0.0, 1.0);
    final double top = r.top.clamp(0.0, 1.0);
    final double right = r.right.clamp(left + 0.01, 1.0);
    final double bottom = r.bottom.clamp(top + 0.01, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _edgeSampleRect(Rect r) {
    final double mx = r.width * 0.10;
    final double my = r.height * 0.05;
    final double left = (r.left + mx).clamp(0.0, 1.0);
    final double top = (r.top + my).clamp(0.0, 1.0);
    final double right = (r.right - mx).clamp(left + 0.01, 1.0);
    final double bottom = (r.bottom - my).clamp(top + 0.01, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
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

  void setDbSyncEnabled(bool enabled) {
    _dbSyncEnabled = enabled;
  }

  double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final v = List<double>.from(values)..sort();
    final idx = (p * (v.length - 1)).clamp(0.0, v.length - 1.0).round();
    return v[idx];
  }

  void autoCalibrateFromLiveMetrics() {
    final ds = _slots.map((s) => s.darkRatio).where((v) => v > 0).toList();
    final es = _slots.map((s) => s.edgeDensity).where((v) => v > 0).toList();
    final ss = _slots.map((s) => s.sigma).where((v) => v > 0).toList();
    final cs = _slots.map((s) => s.chroma).where((v) => v > 0).toList();
    final rs = _slots.map((s) => s.colorRatio).where((v) => v > 0).toList();
    if (ds.isEmpty || es.isEmpty || ss.isEmpty) return;
    final medD = _percentile(ds, 0.50);
    final medE = _percentile(es, 0.50);
    final medS = _percentile(ss, 0.50);
    final medC = cs.isNotEmpty ? _percentile(cs, 0.50) : _chromaThreshold;
    final medR = rs.isNotEmpty ? _percentile(rs, 0.50) : _colorRatioThreshold;
    _occupancyRatio = medD + 0.05;
    _edgeRatioThreshold = medE + 0.05;
    _sigmaThreshold = medS + 10.0;
    _chromaThreshold = medC;
    _colorRatioThreshold = (medR + 0.05).clamp(0.05, 0.80);
    _occupancyRatio = _occupancyRatio.clamp(0.15, 0.55);
    _edgeRatioThreshold = _edgeRatioThreshold.clamp(0.05, 0.30);
    _sigmaThreshold = _sigmaThreshold.clamp(5.0, 120.0);
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      final darknessOccupied = s.currentBrightness < (s.threshold - _statusMargin) || s.darkRatio > _occupancyRatio;
      final bool colorOccupied = s.chroma > _chromaThreshold || s.colorRatio > _colorRatioThreshold;
      final textureOccupied = s.edgeDensity > _edgeRatioThreshold || s.sigma > _sigmaThreshold;
      final occ = (darknessOccupied || colorOccupied) && textureOccupied;
      _slots[i] = s.copyWith(isOccupied: occ);
    }
    _updateStats();
    notifyListeners();
  }

  void setAutoLiveCalibrationEnabled(bool enabled) {
    _autoLiveCalibrationEnabled = enabled;
    if (enabled) {
      _lastCalibrateAt = null;
      _baselineMedianBrightness = 0.0;
    }
    notifyListeners();
  }

  void _autoCalibrateSmooth() {
    final ds = _slots.map((s) => s.darkRatio).where((v) => v > 0).toList();
    final es = _slots.map((s) => s.edgeDensity).where((v) => v > 0).toList();
    final ss = _slots.map((s) => s.sigma).where((v) => v > 0).toList();
    final cs = _slots.map((s) => s.chroma).where((v) => v > 0).toList();
    final rs = _slots.map((s) => s.colorRatio).where((v) => v > 0).toList();
    if (ds.isEmpty || es.isEmpty || ss.isEmpty) return;
    final double medD = _percentile(ds, 0.50);
    final double medE = _percentile(es, 0.50);
    final double medS = _percentile(ss, 0.50);
    final double medC = cs.isNotEmpty ? _percentile(cs, 0.50) : _chromaThreshold;
    final double medR = rs.isNotEmpty ? _percentile(rs, 0.50) : _colorRatioThreshold;
    double targetOcc = (medD + 0.05).clamp(0.15, 0.55);
    double targetEdge = (medE + 0.05).clamp(0.05, 0.30);
    double targetSigma = (medS + 10.0).clamp(5.0, 120.0);
    double targetChroma = medC.clamp(15.0, 120.0);
    double targetColorRatio = (medR + 0.05).clamp(0.05, 0.80);
    _occupancyRatio = _occupancyRatio * (1 - _emaAlpha) + targetOcc * _emaAlpha;
    _edgeRatioThreshold = _edgeRatioThreshold * (1 - _emaAlpha) + targetEdge * _emaAlpha;
    _sigmaThreshold = _sigmaThreshold * (1 - _emaAlpha) + targetSigma * _emaAlpha;
    _chromaThreshold = _chromaThreshold * (1 - _emaAlpha) + targetChroma * _emaAlpha;
    _colorRatioThreshold = _colorRatioThreshold * (1 - _emaAlpha) + targetColorRatio * _emaAlpha;
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      final bool darknessOccupied = s.currentBrightness < (s.threshold - _statusMargin) || s.darkRatio > _occupancyRatio;
      final bool colorOccupied = s.chroma > _chromaThreshold || s.colorRatio > _colorRatioThreshold;
      final bool textureOccupied = s.edgeDensity > _edgeRatioThreshold || s.sigma > _sigmaThreshold;
      final bool occ = (darknessOccupied || colorOccupied) && textureOccupied;
      _slots[i] = s.copyWith(isOccupied: occ);
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
