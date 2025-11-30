import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/parking_detection_controller.dart';
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
  @override
  void initState() {
    super.initState();
    // Initialize camera when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ParkingDetectionController>();
      if (!controller.isImageMode) {
        controller.initializeCamera();
      }
      controller.startRealtimeSubscription();
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
            ? Image.memory(controller.selectedImageBytes!, fit: BoxFit.fill)
            : Image.file(controller.selectedImageFile!, fit: BoxFit.fill))
        : controller.isCameraInitialized
            ? CameraPreview(controller.cameraController!)
            : const Center(child: CircularProgressIndicator());
    return Container(key: _previewKey, child: inner);
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
    context.read<ParkingDetectionController>().stopRealtimeSubscription();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Threshold:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Expanded(
                child: Slider(
                  value: controller.slots.isNotEmpty ? controller.slots.first.threshold : 100,
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: (controller.slots.isNotEmpty ? controller.slots.first.threshold : 100).round().toString(),
                  onChanged: (value) {
                    controller.updateAllThresholds(value);
                  },
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
                onChanged: (v) {
                  if (v != null) {
                    controller.setGrid(v, controller.gridCols);
                  }
                },
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
                onChanged: (v) {
                  if (v != null) {
                    controller.setGrid(controller.gridRows, v);
                  }
                },
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => controller.autoCalibrateFromCurrentImage(),
                child: const Text('Auto'),
              ),
            ],
          ),
          (_isEditMode && _selectedSlotId != null)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Edit Slot: ${_selectedSlotId!}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dx: -0.01),
                          icon: const Icon(Icons.arrow_left, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dx: 0.01),
                          icon: const Icon(Icons.arrow_right, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dy: -0.01),
                          icon: const Icon(Icons.arrow_upward, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dy: 0.01),
                          icon: const Icon(Icons.arrow_downward, color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dWidth: -0.01),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dWidth: 0.01),
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dHeight: -0.01),
                          icon: const Icon(Icons.vertical_align_center, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => _nudgeSelected(controller, dHeight: 0.01),
                          icon: const Icon(Icons.vertical_align_top, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          const Text(
            'Status Slot:',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.slots.length,
              itemBuilder: (context, index) {
                final slot = controller.slots[index];
                return Card(
                  color: Colors.grey[800],
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: slot.isOccupied ? Colors.red : Colors.green,
                      child: Text(slot.id, style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      'Brightness: ${slot.currentBrightness.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    subtitle: Text(
                      'Threshold: ${slot.threshold.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      slot.isOccupied ? 'TERISI' : 'KOSONG',
                      style: TextStyle(
                        color: slot.isOccupied ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedSlotId = slot.id;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
    }
  }

  @override
  bool shouldRepaint(covariant SlotOverlayPainter oldDelegate) {
    return true; // Always repaint when slots change
  }
}