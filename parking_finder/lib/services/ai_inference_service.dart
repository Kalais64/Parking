import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/parking_slot.dart';

class AiSlotResult {
  final String id;
  final bool occupied;
  final double confidence;
  AiSlotResult(this.id, this.occupied, this.confidence);
}

enum AiMode { off, hybrid, detector }

class AiInferenceService {
  List<AiSlotResult> inferImage(img.Image image, List<ParkingSlot> slots, {double innerPadding = 0.10}) {
    final List<AiSlotResult> results = [];
    final int width = image.width;
    final int height = image.height;
    for (final s in slots) {
      final rect = s.rect;
      double left = rect.left + innerPadding * rect.width;
      double top = rect.top + innerPadding * rect.height;
      double right = rect.right - innerPadding * rect.width;
      double bottom = rect.bottom - innerPadding * rect.height;
      left = left.clamp(0.0, 1.0);
      top = top.clamp(0.0, 1.0);
      right = right.clamp(left + 0.01, 1.0);
      bottom = bottom.clamp(top + 0.01, 1.0);

      final int startX = (left * width).toInt();
      final int startY = (top * height).toInt();
      final int endX = (right * width).toInt();
      final int endY = (bottom * height).toInt();
      int count = 0;
      double sumBrightness = 0.0;
      double sumVar = 0.0;
      int edges = 0;
      int colored = 0;
      final int step = math.max(1, (math.min(width, height) / 300).floor());
      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final px = image.getPixel(x, y);
          final int r = px.r.toInt();
          final int g = px.g.toInt();
          final int b = px.b.toInt();
          final int gray = ((r + g + b) ~/ 3);
          sumBrightness += gray;
          sumVar += gray * gray;

          if (x + 1 < endX && y + 1 < endY && x > startX && y > startY) {
            final pr = image.getPixel(x + 1, y);
            final pl = image.getPixel(x - 1, y);
            final pu = image.getPixel(x, y - 1);
            final pd = image.getPixel(x, y + 1);
            final int gr = ((pr.r.toInt() + pr.g.toInt() + pr.b.toInt()) ~/ 3);
            final int gl = ((pl.r.toInt() + pl.g.toInt() + pl.b.toInt()) ~/ 3);
            final int gu = ((pu.r.toInt() + pu.g.toInt() + pu.b.toInt()) ~/ 3);
            final int gd = ((pd.r.toInt() + pd.g.toInt() + pd.b.toInt()) ~/ 3);
            final int gx = gr - gl;
            final int gy = gd - gu;
            final double mag = math.sqrt((gx * gx + gy * gy).toDouble());
            if (mag >= 40) edges++;
          }
          final int mx = math.max(r, math.max(g, b));
          final int mn = math.min(r, math.min(g, b));
          final int sat = mx - mn;
          if (sat > 25) colored++;
          count++;
        }
      }
      if (count == 0) {
        results.add(AiSlotResult(s.id, false, 0.0));
        continue;
      }
      final double avgBright = sumBrightness / count;
      final double variance = (sumVar / count) - (avgBright * avgBright);
      final double sigma = variance <= 0 ? 0.0 : math.sqrt(variance);
      final double edgeDensity = edges / count;
      final double colorRatio = colored / count;

      final double darkRatio = _estimateDarkRatio(image, startX, startY, endX, endY, step);
      double score = 0.0;
      score += darkRatio.clamp(0.0, 1.0) * 0.35;
      score += edgeDensity.clamp(0.0, 1.0) * 0.25;
      score += colorRatio.clamp(0.0, 1.0) * 0.20;
      score += (math.min(sigma, 128.0) / 128.0) * 0.20;
      final double confidence = score.clamp(0.0, 1.0);
      final bool occupied = confidence >= 0.45;
      results.add(AiSlotResult(s.id, occupied, confidence));
    }
    return results;
  }

  double _estimateDarkRatio(img.Image image, int startX, int startY, int endX, int endY, int step) {
    final List<int> hist = List<int>.filled(256, 0);
    int total = 0;
    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final p = image.getPixel(x, y);
        final int g = ((p.r.toInt() + p.g.toInt() + p.b.toInt()) ~/ 3).clamp(0, 255);
        hist[g]++;
        total++;
      }
    }
    if (total == 0) return 0.0;
    int sum = 0;
    for (int t = 0; t < 256; t++) {
      sum += t * hist[t];
    }
    int sumB = 0;
    int wB = 0;
    double maxVar = 0.0;
    int otsu = 128;
    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final double mB = sumB / wB;
      final double mF = (sum - sumB) / wF;
      final double between = wB * wF * (mB - mF) * (mB - mF);
      if (between > maxVar) {
        maxVar = between;
        otsu = t;
      }
    }
    int dark = 0;
    for (int t = 0; t < otsu; t++) {
      dark += hist[t];
    }
    return dark / total;
  }
}
