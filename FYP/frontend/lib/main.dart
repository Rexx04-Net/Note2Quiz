import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'dart:async';
import 'screens/lobby_screen.dart'; 

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

  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note2Quiz Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily, 
      ),
      home: const SplashScreen(),
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.bolt, size: 80, color: Color(0xFF6C63FF)),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _opacityAnimation,
              child: const Text("NOTE 2 QUIZ", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.white)),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}