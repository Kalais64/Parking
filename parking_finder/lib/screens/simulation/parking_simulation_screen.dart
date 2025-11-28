import 'dart:io';
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
  @override
  void initState() {
    super.initState();
    // Initialize camera when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ParkingDetectionController>();
      if (!controller.isImageMode) {
        controller.initializeCamera();
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (!mounted) return;
      context.read<ParkingDetectionController>().pickAndProcessImage(pickedFile.path);
    }
  }

  @override
  void dispose() {
    // We might want to stop the camera when leaving this screen to save battery
    // But the controller is global, so maybe we just pause?
    // For now, let's keep it running or let the controller handle dispose if it was local.
    // Since we plan to make it global for map updates, we shouldn't dispose the controller here
    // but maybe stop the stream?
    // For this prototype, we'll leave it running.
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
            ],
          ),
          body: Column(
            children: [
              // Camera Feed or Image with Overlay
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (controller.isImageMode && controller.selectedImageFile != null)
                      Image.file(
                        controller.selectedImageFile!,
                        fit: BoxFit.fill,
                      )
                    else if (controller.isCameraInitialized)
                      CameraPreview(controller.cameraController!)
                    else
                      const Center(child: CircularProgressIndicator()),
                      
                    CustomPaint(
                      painter: SlotOverlayPainter(slots: controller.slots),
                    ),
                  ],
                ),
              ),
              // Stats and Controls
              Expanded(
                flex: 2,
                child: Container(
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
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
}

class SlotOverlayPainter extends CustomPainter {
  final List<ParkingSlot> slots;

  SlotOverlayPainter({required this.slots});

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