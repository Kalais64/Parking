import 'package:flutter/material.dart';

class AppColorsNew {
  // Primary gradient colors (like the design)
  static const Color primaryDark = Color(0xFF0A0A0A); // Dark background
  static const Color primaryLight = Color(0xFF1A1A1A); // Slightly lighter dark
  
  // Accent color (lime-green from design)
  static const Color accent = Color(0xFF32CD32); // Lime green
  static const Color accentLight = Color(0xFF7CFC00); // Lawn green
  static const Color accentDark = Color(0xFF228B22); // Forest green
  
  // Status colors matching the design
  static const Color available = Color(0xFF32CD32); // Lime green for available
  static const Color gettingFull = Color(0xFFFFD700); // Gold for getting full
  static const Color full = Color(0xFFFF4500); // Orange red for full
  static const Color unavailable = Color(0xFF696969); // Dim gray for unavailable
  
  // Text colors for dark theme
  static const Color textPrimary = Color(0xFFFFFFFF); // White text
  static const Color textSecondary = Color(0xFFB0B0B0); // Light gray
  static const Color textHint = Color(0xFF808080); // Gray
  
  // Background and surface colors
  static const Color background = Color(0xFF0A0A0A); // Very dark background
  static const Color surface = Color(0xFF1E1E1E); // Dark surface
  static const Color surfaceLight = Color(0xFF2A2A2A); // Lighter surface
  static const Color error = Color(0xFFFF5252); // Red for errors
  
  // Gradient colors for the main background
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFF0A0A0A), // Dark at bottom-left
      Color(0xFF1A1A1A), // Medium dark
      Color(0xFF2A2A2A), // Lighter at top-right
    ],
  );
  
  // Gradient for accent elements
  static const Gradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF32CD32), // Lime green
      Color(0xFF7CFC00), // Lawn green
    ],
  );
  
  // Card colors for parking spots
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF333333);
  static const Color cardShadow = Color(0x4D000000);
  
  // Map colors
  static const Color mapPinAvailable = Color(0xFF32CD32);
  static const Color mapPinGettingFull = Color(0xFFFFD700);
  static const Color mapPinFull = Color(0xFFFF4500);
  static const Color mapPinSelected = Color(0xFF32CD32);
  
  // Button colors
  static const Color buttonPrimary = Color(0xFF32CD32);
  static const Color buttonText = Color(0xFFFFFFFF);
  static const Color buttonDisabled = Color(0xFF444444);
}
