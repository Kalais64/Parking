import 'dart:ui';

class ParkingSlot {
  final String id;
  // Normalized coordinates (0.0 to 1.0) relative to the camera frame
  final Rect rect; 
  double threshold;
  double currentBrightness;
  bool isOccupied;
  double darkRatio;
  double edgeDensity;
  double sigma;
  double chroma;
  double colorRatio;
  double aiConfidence;
  bool aiOccupied;

  ParkingSlot({
    required this.id,
    required this.rect,
    this.threshold = 100.0, // Default threshold, can be tuned
    this.currentBrightness = 0.0,
    this.isOccupied = false,
    this.darkRatio = 0.0,
    this.edgeDensity = 0.0,
    this.sigma = 0.0,
    this.chroma = 0.0,
    this.colorRatio = 0.0,
    this.aiConfidence = 0.0,
    this.aiOccupied = false,
  });

  // Create a copy with updated status
  ParkingSlot copyWith({
    double? currentBrightness,
    bool? isOccupied,
    double? threshold,
    Rect? rect,
    double? darkRatio,
    double? edgeDensity,
    double? sigma,
    double? chroma,
    double? colorRatio,
    double? aiConfidence,
    bool? aiOccupied,
  }) {
    return ParkingSlot(
      id: id,
      rect: rect ?? this.rect,
      threshold: threshold ?? this.threshold,
      currentBrightness: currentBrightness ?? this.currentBrightness,
      isOccupied: isOccupied ?? this.isOccupied,
      darkRatio: darkRatio ?? this.darkRatio,
      edgeDensity: edgeDensity ?? this.edgeDensity,
      sigma: sigma ?? this.sigma,
      chroma: chroma ?? this.chroma,
      colorRatio: colorRatio ?? this.colorRatio,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiOccupied: aiOccupied ?? this.aiOccupied,
    );
  }
}
