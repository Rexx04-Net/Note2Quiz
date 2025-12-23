import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/lobby_screen.dart';
import 'screens/login_screen.dart';

void main() {
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
        fontFamily: 'Roboto',
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      // ✅ FIX: Go to Lobby directly (Guest Mode)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LobbyScreen(userEmail: null))
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      body: Center(child: Icon(Icons.bolt, size: 80, color: Color(0xFF6C63FF))),
    );
  }
}