import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/parking_detection_controller.dart';
import '../../controllers/map_controller.dart';
import '../../models/parking_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/parking_slot.dart';

class ParkingSimulationScreen extends StatefulWidget {
  const ParkingSimulationScreen({super.key});

  @override
  State<ParkingSimulationScreen> createState() => _ParkingSimulationScreenState();
}

class _ParkingSimulationScreenState extends State<ParkingSimulationScreen> {
  bool _isEditMode = false;
  String? _selectedSlotId;
  final GlobalKey _previewKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  @override
  void initState() {
    super.initState();
    // Initialize camera when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final det = context.read<ParkingDetectionController>();
      det.setMapController(context.read<MapController>());
      det.setDbSyncEnabled(false);
      det.resetDetectionState();
      if (!det.isImageMode) {
        det.initializeCamera();
      }
    });
  }

  void _nudgeSelected(ParkingDetectionController controller, {double dx = 0, double dy = 0, double dWidth = 0, double dHeight = 0}) {
    if (_selectedSlotId == null) return;
    controller.updateSlotRectByDelta(_selectedSlotId!, dx: dx, dy: dy, dWidth: dWidth, dHeight: dHeight);
  }

  Widget _previewContent(ParkingDetectionController controller) {
    final bool hasImageBytes = controller.selectedImageBytes != null;
    final bool hasImageFile = controller.selectedImageFile != null;
    final Widget inner = controller.isImageMode && (hasImageBytes || hasImageFile)
        ? (hasImageBytes
            ? Image.memory(controller.selectedImageBytes!, fit: BoxFit.contain)
            : Image.file(controller.selectedImageFile!, fit: BoxFit.contain))
        : (controller.isCameraInitialized && controller.cameraController != null)
            ? CameraPreview(controller.cameraController!)
            : const Center(child: CircularProgressIndicator());
    final double? aspect = controller.previewAspectRatio;
    final Widget wrapped = aspect != null
        ? AspectRatio(aspectRatio: aspect, child: inner)
        : inner;
    return Container(key: _previewKey, child: wrapped);
  }
  
  Widget _buildPreviewSection(ParkingDetectionController controller) {
    return Expanded(
      flex: 3,
      child: GestureDetector(
        onTapDown: (details) {
          final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final size = box.size;
          final pos = details.localPosition;
          final nx = (pos.dx / size.width).clamp(0.0, 1.0);
          final ny = (pos.dy / size.height).clamp(0.0, 1.0);
          for (final s in controller.slots) {
            final r = s.rect;
            if (nx >= r.left && nx <= r.right && ny >= r.top && ny <= r.bottom) {
              setState(() {
                _selectedSlotId = s.id;
              });
              break;
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewContent(controller),
            CustomPaint(
              painter: SlotOverlayPainter(
                slots: controller.slots,
                selectedSlotId: _selectedSlotId,
                isEditMode: _isEditMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (!mounted) return;
      final bytes = await pickedFile.readAsBytes();
      context.read<ParkingDetectionController>().pickAndProcessBytes(bytes);
    }
  }

  @override
  void dispose() {
    final det = context.read<ParkingDetectionController>();
    det.stopRealtimeSubscription();
    det.resetDetectionState();
    det.releaseCamera();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParkingDetectionController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(controller.isImageMode ? 'Mode Gambar' : 'Mode Kamera Live'),
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_location_alt),
                onPressed: () => _showAddLocationDialog(context, controller),
                tooltip: 'Tambah Lokasi Parkir',
              ),
              IconButton(
                icon: Icon(controller.isImageMode ? Icons.camera_alt : Icons.image),
                onPressed: () {
                  if (controller.isImageMode) {
                    controller.switchToCameraMode();
                  } else {
                    _pickImage();
                  }
                },
                tooltip: controller.isImageMode ? 'Gunakan Kamera' : 'Pilih Gambar',
              ),
              IconButton(
                icon: Icon(_isEditMode ? Icons.edit_off : Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
                tooltip: _isEditMode ? 'Matikan Edit' : 'Edit Grid Slot',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPreviewSection(controller),
              // Stats and Controls
              _buildStatsExpanded(controller),
            ],
          ),
        );
        },
      );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
  
  Widget _buildStats(ParkingDetectionController controller) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total', '${controller.totalSlots}', Colors.blue),
              _buildStatCard('Kosong', '${controller.emptySlots}', Colors.green),
              _buildStatCard('Terisi', '${controller.filledSlots}', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Threshold:', style: TextStyle(color: Colors.white, fontSize: 16)),
              Expanded(
                child: Slider(
                  value: controller.slots.isNotEmpty ? controller.slots.first.threshold : 100,
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: (controller.slots.isNotEmpty ? controller.slots.first.threshold : 100).round().toString(),
                  onChanged: (value) => controller.updateAllThresholds(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Sensitivity:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: controller.occupancyRatio,
                  min: 0.15,
                  max: 0.55,
                  divisions: 40,
                  label: controller.occupancyRatio.toStringAsFixed(2),
                  onChanged: (v) => controller.setOccupancyRatio(v),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Padding:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: controller.innerPadding,
                  min: 0.0,
                  max: 0.25,
                  divisions: 25,
                  label: controller.innerPadding.toStringAsFixed(2),
                  onChanged: (v) => controller.setInnerPadding(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Edge:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: controller.edgeRatioThreshold,
                  min: 0.05,
                  max: 0.30,
                  divisions: 25,
                  label: controller.edgeRatioThreshold.toStringAsFixed(2),
                  onChanged: (v) => controller.setEdgeRatioThreshold(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Chroma:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: controller.chromaThreshold,
                  min: 15.0,
                  max: 120.0,
                  divisions: 21,
                  label: controller.chromaThreshold.toStringAsFixed(0),
                  onChanged: (v) => controller.setChromaThreshold(v),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Color:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: controller.colorRatioThreshold,
                  min: 0.05,
                  max: 0.80,
                  divisions: 15,
                  label: controller.colorRatioThreshold.toStringAsFixed(2),
                  onChanged: (v) => controller.setColorRatioThreshold(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Grid:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              Text('${controller.gridRows} × ${controller.gridCols}', style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: controller.gridRows,
                dropdownColor: Colors.black87,
                iconEnabledColor: Colors.white,
                iconDisabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white),
                items: List<int>.generate(9, (i) => i + 2)
                    .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v', style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) { if (v != null) controller.setGrid(v, controller.gridCols); },
              ),
              const SizedBox(width: 4),
              const Text('×', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: controller.gridCols,
                dropdownColor: Colors.black87,
                iconEnabledColor: Colors.white,
                iconDisabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white),
                items: List<int>.generate(9, (i) => i + 2)
                    .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v', style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) { if (v != null) controller.setGrid(controller.gridRows, v); },
              ),
              const Spacer(),
              if (controller.isImageMode)
                ElevatedButton(onPressed: () => controller.autoCalibrateFromCurrentImage(), child: const Text('Evaluasi Ulang'))
              else ...[
                ElevatedButton(onPressed: () => controller.autoCalibrateFromLiveMetrics(), child: const Text('Kalibrasi Live')),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Text('Auto Live', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 6),
                    Switch(
                      value: controller.autoLiveCalibrationEnabled,
                      onChanged: (v) => controller.setAutoLiveCalibrationEnabled(v),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (_isEditMode && _selectedSlotId != null) ...[
            const SizedBox(height: 8),
            Text('Edit Slot: ${_selectedSlotId!}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(onPressed: () => _nudgeSelected(controller, dx: -0.01), icon: const Icon(Icons.arrow_left, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dx: 0.01), icon: const Icon(Icons.arrow_right, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dy: -0.01), icon: const Icon(Icons.arrow_upward, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dy: 0.01), icon: const Icon(Icons.arrow_downward, color: Colors.white)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(onPressed: () => _nudgeSelected(controller, dWidth: -0.01), icon: const Icon(Icons.remove_circle_outline, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dWidth: 0.01), icon: const Icon(Icons.add_circle_outline, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dHeight: -0.01), icon: const Icon(Icons.vertical_align_center, color: Colors.white)),
                IconButton(onPressed: () => _nudgeSelected(controller, dHeight: 0.01), icon: const Icon(Icons.vertical_align_top, color: Colors.white)),
              ],
            ),
          ],
          const Text('Status Slot:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ...controller.slots.map((slot) => Card(
            color: Colors.grey[800],
            child: ListTile(
              leading: CircleAvatar(backgroundColor: slot.isOccupied ? Colors.red : Colors.green, child: Text(slot.id, style: const TextStyle(color: Colors.white))),
              title: Text('Brightness: ${slot.currentBrightness.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70)),
              subtitle: Text('Thresh: ${slot.threshold.toStringAsFixed(1)}  Dark: ${slot.darkRatio.toStringAsFixed(2)}  Edge: ${slot.edgeDensity.toStringAsFixed(2)}  Sigma: ${slot.sigma.toStringAsFixed(1)}  Chrom: ${slot.chroma.toStringAsFixed(1)}  Color: ${slot.colorRatio.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
              trailing: Text(slot.isOccupied ? 'TERISI' : 'KOSONG', style: TextStyle(color: slot.isOccupied ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
              onTap: () { setState(() { _selectedSlotId = slot.id; }); },
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _showAddLocationDialog(BuildContext context, ParkingDetectionController det) async {
    final map = context.read<MapController>();
    _nameController.text = '';
    _addressController.text = '';
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tambah Lokasi Parkir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lokasi'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final address = _addressController.text.trim();
                final pos = map.currentPosition ?? const LatLng(-6.2088, 106.8456);
                final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                final total = det.totalSlots;
                final empty = det.emptySlots;
                final status = empty == 0
                    ? ParkingStatus.full
                    : (empty < (total * 0.2))
                        ? ParkingStatus.gettingFull
                        : ParkingStatus.available;
                final loc = ParkingLocation(
                  id: id,
                  name: name.isEmpty ? 'Lokasi Baru' : name,
                  address: address.isEmpty ? 'Belum ada alamat' : address,
                  coordinates: pos,
                  status: status,
                  totalCapacity: total,
                  availableSpots: empty,
                  pricePerHour: 5000,
                  vehicleType: 'both',
                  parkingType: 'both',
                  securityLevel: 'medium',
                  hasCctv: true,
                  isWellLit: true,
                  lastUpdated: DateTime.now(),
                );
                map.addOrUpdateParkingLocation(loc);
                map.selectParking(loc);
                map.navigateToParkingWithDirections(loc);
                Navigator.of(ctx).pop();
              },
              child: const Text('Simpan & Navigasi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsExpanded(ParkingDetectionController controller) {
    return Expanded(
      flex: 2,
      child: _buildStats(controller),
    );
  }
}

class SlotOverlayPainter extends CustomPainter {
  final List<ParkingSlot> slots;
  final String? selectedSlotId;
  final bool isEditMode;

  SlotOverlayPainter({required this.slots, this.selectedSlotId, this.isEditMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final slot in slots) {
      // Convert normalized rect to screen coordinates
      final rect = Rect.fromLTWH(
        slot.rect.left * size.width,
        slot.rect.top * size.height,
        slot.rect.width * size.width,
        slot.rect.height * size.height,
      );

      paint.color = slot.isOccupied ? Colors.red : Colors.green;
      if (isEditMode && selectedSlotId == slot.id) {
        paint.strokeWidth = 4.0;
        paint.color = Colors.yellow;
      }
      canvas.drawRect(rect, paint);

      // Draw Background for text
      final bgPaint = Paint()..color = Colors.black54;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, 40, 20),
        bgPaint
      );

      // Draw ID
      textPainter.text = TextSpan(
        text: slot.id,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left + 5, rect.top + 2));

      final String metrics = 'E:${slot.edgeDensity.toStringAsFixed(2)} D:${slot.darkRatio.toStringAsFixed(2)} S:${slot.sigma.toStringAsFixed(1)} C:${slot.chroma.toStringAsFixed(0)} R:${slot.colorRatio.toStringAsFixed(2)}';
      final double metricsWidth = rect.width.clamp(120.0, 180.0);
      canvas.drawRect(
        Rect.fromLTWH(rect.right - metricsWidth, rect.top, metricsWidth, 20),
        bgPaint,
      );
      textPainter.text = TextSpan(
        text: metrics,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      );
      textPainter.layout(maxWidth: metricsWidth - 6);
      textPainter.paint(canvas, Offset(rect.right - metricsWidth + 3, rect.top + 3));
    }
  }

  @override
  bool shouldRepaint(covariant SlotOverlayPainter oldDelegate) {
    return true; // Always repaint when slots change
  }
}
