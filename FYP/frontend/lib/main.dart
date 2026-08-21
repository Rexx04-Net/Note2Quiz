import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'screens/lobby_screen.dart';
import 'services/deep_link_service.dart';
import 'state/app_settings_controller.dart';
import 'theme/app_theme.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBXTpUHSEwbeOdx3x0pa7wVlo3_IjKz0qI",
      authDomain: "note2quiz-d8ca9.firebaseapp.com",
      projectId: "note2quiz-d8ca9",
      storageBucket: "note2quiz-d8ca9.firebasestorage.app",
      messagingSenderId: "386464819087",
      appId: "1:386464819087:web:fb9d0c20865584087ccdfa",
      measurementId: "G-6V29B1138C",
    ),
  );

  final settingsController = AppSettingsController();
  await settingsController.load();

  // Initialize DeepLinkService for note2quiz:// deep links
  DeepLinkService().initialize();

  runApp(StudyApp(controller: settingsController));
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key, required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return AppSettingsScope(
          controller: controller,
          child: MaterialApp(
            title: 'Note2Quiz Pro',
            navigatorKey: DeepLinkService().navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: StudyAppTheme.lightTheme(),
            darkTheme: StudyAppTheme.darkTheme(),
            themeMode: controller.themeMode,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LobbyScreen())
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt, size: 80, color: scheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _opacityAnimation,
              child: Text(
                "NOTE 2 QUIZ",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
              ),
            ),
            const SizedBox(height: 50),
            CircularProgressIndicator(color: scheme.primary, strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}
