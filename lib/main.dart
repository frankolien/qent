import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/services/notification_service.dart';
import 'package:qent/core/services/online_status_service.dart';
import 'dart:async';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/pages/login_page.dart';
import 'package:qent/features/auth/presentation/pages/signup_page.dart';
import 'package:qent/features/home/presentation/pages/main_nav_page.dart';
import 'package:qent/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:qent/firebase_options.dart';
import 'package:qent/features/partner/presentation/pages/partner_onboarding_welcome_page.dart';

bool _servicesInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable runtime font fetching - use bundled fonts from assets/fonts/
  GoogleFonts.config.allowRuntimeFetching = true;

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (!e.toString().contains('already been initialized')) {
      debugPrint('Firebase initialization error: $e');
    }
  }
  
  runApp(const ProviderScope(child: MainApp()));
  
  if (!_servicesInitialized) {
    _servicesInitialized = true;
    _initializeServicesAsync();
  }
}

void _initializeServicesAsync() async {
  try {
    NotificationService().initialize().catchError((e) {
      debugPrint('Notification service init error: $e');
    });
    
    CloudinaryService().initialize(
      cloudName: dotenv.env['CLOUDINARY_CLOUD_NAME'],
      apiKey: dotenv.env['CLOUDINARY_API_KEY'],
      apiSecret: dotenv.env['CLOUDINARY_API_SECRET'],
    );
    OnlineStatusService().initialize();
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

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _authSubscription;
  String? _previousUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _previousUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
      
      _authSubscription = ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
        final currentUserId = user?.uid;
        
        if (!OnboardingState.hasSeenOnboarding) {
          _previousUserId = currentUserId;
          return;
        }
        
        if (_previousUserId != null && currentUserId == null) {
          Future.microtask(() {
            if (!mounted) return;
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
        } else if (_previousUserId == null && currentUserId != null) {
          Future.microtask(() {
            if (!mounted) return;
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          });
        }
        
        _previousUserId = currentUserId;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    final initialRoute = authState.user != null 
        ? '/home' 
        : (OnboardingState.hasSeenOnboarding ? '/login' : '/onboarding');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
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
