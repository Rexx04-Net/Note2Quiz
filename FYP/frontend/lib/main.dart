import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'screens/lobby_screen.dart';
import 'services/deep_link_service.dart';
import 'state/app_settings_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
  } catch (e) {
    debugPrint("⚠️ [Firebase] Init warning: $e");
  }

  final settingsController = AppSettingsController();
  try {
    await settingsController.load();
  } catch (e) {
    debugPrint("⚠️ [Settings] Load warning: $e");
  }

  // DeepLinkService is only required on native mobile apps
  if (!kIsWeb) {
    try {
      DeepLinkService().initialize();
    } catch (e) {
      debugPrint("⚠️ [DeepLink] Init warning: $e");
    }
  }

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
            title: 'Note2Quiz',
            onGenerateTitle: (context) => 'Note2Quiz',
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

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
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
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0062FE).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _opacityAnimation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "NOTE2",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: colors.primaryText,
                    ),
                  ),
                  const Text(
                    "QUIZ",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: Color(0xFF0062FE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: scheme.primary, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
