import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/core/providers/theme_provider.dart';
import 'package:qent/firebase_options.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:qent/features/auth/presentation/pages/login_page.dart';
import 'package:qent/features/auth/presentation/pages/signup_page.dart';
import 'package:qent/features/home/presentation/pages/main_nav_page.dart';
import 'package:qent/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:qent/features/partner/presentation/pages/partner_onboarding_welcome_page.dart';
import 'package:qent/features/splash/presentation/pages/splash_page.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

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
  const prodUrl = 'https://qent-backend.onrender.com/api';
  final apiClient = ApiClient();
  await apiClient.initialize(
    baseUrl: kReleaseMode
        ? prodUrl
        : (dotenv.env['API_BASE_URL'] ?? prodUrl),
  );

  // Load the saved theme BEFORE the first frame so we never paint with the
  // wrong colors. Defaults to ThemeMode.system for first-time users.
  ThemeModeNotifier.initial = await loadInitialThemeMode();

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

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService initialization error: $e');
  }
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  bool _showedSplash = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      // Use home instead of initialRoute to survive hot reload
      home: _showedSplash ? const _AuthGate() : _buildSplashThenGate(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => MainNavPage(key: MainNavPage.globalKey),
        '/partner/onboarding': (context) => const PartnerOnboardingWelcomePage(),
      },
    );
  }

  Widget _buildSplashThenGate() {
    // Show splash once, then switch to AuthGate permanently
    return SplashPage(
      onComplete: () {
        if (mounted) setState(() => _showedSplash = true);
      },
    );
  }
}

/// Watches auth state and shows login or home — survives hot reload
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _initialCheckDone = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Only show loading screen during initial session restore, not during login
    if (authState.isLoading && !_initialCheckDone) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    // After first load completes, never show the black loading screen again
    if (!authState.isLoading && !_initialCheckDone) {
      _initialCheckDone = true;
    }

    if (authState.user != null) {
      return MainNavPage(key: MainNavPage.globalKey);
    }

    return const LoginPage();
  }
}
