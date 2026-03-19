import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; 
import '../config.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // --- 1. WEB-OPTIMIZED GOOGLE SIGN-IN ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider.setCustomParameters({'prompt': 'select_account'});

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      final String? email = userCredential.user?.email;

      if (email != null) {
        var response = await http.post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        );

        if (response.statusCode == 200) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(email: email)),
          );
        } else {
          _showError("Backend rejected the login.");
        }
      }
    } catch (e) {
      _showError("Google Sign-In Failed. Check console for details.");
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. STANDARD EMAIL SIGN-IN ---
  Future<void> _signInWithEmail() async {
    String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      var response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(email: email)),
        );
      } else {
        _showError("Failed to connect to server.");
      }
    } catch (e) {
      _showError("Network Error. Is your backend running?");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. NEW: GUEST / ANONYMOUS SIGN-IN ---
  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);

    // We generate a random number so each guest gets their own clean workspace!
    String guestEmail = "anonymous_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}@guest.com";

    try {
      var response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': guestEmail}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(email: guestEmail)),
        );
      } else {
        _showError("Failed to connect to server.");
      }
    } catch (e) {
      _showError("Network Error. Is your backend running?");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E), 
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A35), 
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Log in or sign up", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Save your notes, quizzes, and live games.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 30),

              // --- OAUTH BUTTONS ---
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithGoogle, 
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text("Continue with Google", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              OutlinedButton(
                onPressed: () => _showError("Apple Sign-In coming soon!"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text("Continue with Apple", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR", style: TextStyle(color: Colors.white54, fontSize: 12))),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Email address",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E2E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              // --- ANONYMOUS TEXT BUTTON ---
              const SizedBox(height: 15),
              TextButton(
                onPressed: _isLoading ? null : _signInAsGuest,
                child: const Text(
                  "Skip and continue as Guest",
                  style: TextStyle(
                    color: Colors.white54, 
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}