import 'package:flutter/material.dart';
import 'package:qent/features/onboarding/presentation/pages/onboarding_screen.dart';


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        //'/onboarding2': (context) => const OnboardingSecondPage(),
      },
    );
  }
}
