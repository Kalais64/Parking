import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // This file needs to be generated

class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print('Firebase initialization error: $e');
      // For development, you can use a fallback configuration
      // This is just a placeholder - you need to generate your own firebase_options.dart
    }
  }
}