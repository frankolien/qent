import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:qent/firebase_options.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/pages/login_page.dart';
import 'package:qent/features/auth/presentation/pages/signup_page.dart';
import 'package:qent/features/home/presentation/pages/main_nav_page.dart';
import 'package:qent/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:qent/features/partner/presentation/pages/partner_onboarding_welcome_page.dart';

bool _servicesInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Initialize Firebase (needed for chat, notifications, online status)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize API client with backend URL
  final apiClient = ApiClient();
  await apiClient.initialize(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080/api',
  );

  runApp(const ProviderScope(child: MainApp()));

  if (!_servicesInitialized) {
    _servicesInitialized = true;
    _initializeServicesAsync();
  }
}

void _initializeServicesAsync() async {
  try {
    CloudinaryService().initialize(
      cloudName: dotenv.env['CLOUDINARY_CLOUD_NAME'],
      apiKey: dotenv.env['CLOUDINARY_API_KEY'],
      apiSecret: dotenv.env['CLOUDINARY_API_SECRET'],
    );
  } catch (e) {
    debugPrint('Async service initialization error: $e');
  }
}

class OnboardingState {
  static bool _hasSeenOnboarding = false;

  static bool get hasSeenOnboarding => _hasSeenOnboarding;

  static void markOnboardingAsSeen() {
    _hasSeenOnboarding = true;
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    final initialRoute = authState.user != null
        ? '/home'
        : (OnboardingState.hasSeenOnboarding ? '/login' : '/onboarding');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const MainNavPage(),
        '/partner/onboarding': (context) => const PartnerOnboardingWelcomePage(),
      },
    );
  }
}
