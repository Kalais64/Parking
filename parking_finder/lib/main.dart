import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/loading/loading_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/payment/payment_methods_screen.dart';
import 'screens/payment/add_payment_card_screen.dart';
import 'screens/nfc/nfc_scan_page.dart';
import 'screens/camera/camera_scan_page.dart';
import 'screens/payment/manual_card_input_screen.dart';
import 'constants/app_colors_new.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/nfc_payment_service.dart';
import 'services/firebase_config.dart';
import 'services/voice_service.dart';
import 'services/audio_navigation_service.dart';
import 'services/voice_integration_manager.dart';
import 'services/location_service.dart';
import 'controllers/map_controller.dart';
import 'models/user_location.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable provider debug check for VoiceService
  Provider.debugCheckInvalidValueType = null;
  
  // Initialize Firebase
  await FirebaseConfig.initialize();
  
  runApp(const ParkingFinderApp());
}

class ParkingFinderApp extends StatelessWidget {
  const ParkingFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize notification service
    NotificationService().initialize(context);
    
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<NFCPaymentService>(create: (_) => NFCPaymentService()),
        ChangeNotifierProvider<MapController>(create: (_) => MapController()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<VoiceService>(create: (_) => VoiceService(), lazy: false),
        Provider<AudioNavigationService>(
          create: (context) => AudioNavigationService(
            voiceService: context.read<VoiceService>(),
            locationService: context.read<LocationService>(),
          ),
        ),
        ChangeNotifierProvider<VoiceIntegrationManager>(
          create: (context) => VoiceIntegrationManager(),
        ),
        StreamProvider<User?>.value(
          value: AuthService().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'ParkirYuk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          primaryColor: AppColorsNew.accent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColorsNew.accent,
            primary: AppColorsNew.accent,
            secondary: AppColorsNew.accentLight,
            surface: AppColorsNew.surface,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: AppColorsNew.background,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColorsNew.textPrimary,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColorsNew.textPrimary,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColorsNew.accent,
            foregroundColor: AppColorsNew.buttonText,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorsNew.accent,
              foregroundColor: AppColorsNew.buttonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(8),
            color: AppColorsNew.cardBackground,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColorsNew.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColorsNew.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColorsNew.accent, width: 2),
            ),
            filled: true,
            fillColor: AppColorsNew.surface,
          ),
        ),
        initialRoute: '/loading',
        routes: {
          '/loading': (context) => const LoadingScreen(),
          '/': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/payment-methods': (context) => const PaymentMethodsScreen(),
          '/add-payment-card': (context) => const AddPaymentCardScreen(nfcAvailable: true),
          '/nfc-scan-page': (context) => const NFCScanPage(),
          '/camera-scan-page': (context) => const CameraScanPage(),
          '/manual-card-input': (context) => const ManualCardInputScreen(),
        },
      ),
    );
  }
}
