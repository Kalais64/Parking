import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email and password login
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Email login error: $e');
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  // Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Apple Sign In tidak tersedia di perangkat ini');
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.yourapp.service', // Replace with your Apple Service ID
          redirectUri: Uri.parse('https://your-app.firebaseapp.com/__/auth/handler'), // Replace with your redirect URI
        ),
      );

      // Create OAuth credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      return await _auth.signInWithCredential(oauthCredential);
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      rethrow;
    }
  }

  // Phone authentication - send OTP
  Future<String?> verifyPhoneNumber(String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto verification completed
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          // Verification failed
          onError(e.message ?? 'Verifikasi gagal');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Code sent to phone
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto retrieval timeout
        },
      );
      return null;
    } catch (e) {
      debugPrint('Phone verification error: $e');
      onError(e.toString());
      return null;
    }
  }

  // Phone authentication - verify OTP
  Future<UserCredential?> verifyOTP(String verificationId, String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('OTP verification error: $e');
      rethrow;
    }
  }

  // Get available authentication methods
  Map<String, bool> getAvailableAuthMethods() {
    return {
      'google': true,
      'apple': SignInWithApple.isAvailable() != null,
      'phone': true,
      'email': true,
    };
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Get user display name
  String getUserDisplayName(User? user) {
    if (user == null) return '';
    return user.displayName ?? user.email ?? user.phoneNumber ?? 'Pengguna';
  }

  // Get user email or phone
  String? getUserEmailOrPhone(User? user) {
    if (user == null) return null;
    return user.email ?? user.phoneNumber;
  }

  // Check if user is new
  bool isNewUser(User? user) {
    if (user == null) return false;
    // Check if user was created recently (within last 5 minutes)
    final creationTime = user.metadata.creationTime;
    final now = DateTime.now();
    if (creationTime != null) {
      return now.difference(creationTime).inMinutes < 5;
    }
    return false;
  }
}