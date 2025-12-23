import 'package:flutter/material.dart';
import 'dart:async';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _loadingText = "Initializing...";
  int _dotCount = 0;
  Timer? _textTimer;

  // Simulate "steps" in the AI process
  final List<String> _loadingSteps = [
    "Analyzing Content...",
    "Extracting Key Concepts...",
    "Drafting Questions...",
    "Generating Distractors...",
    "Finalizing Quiz...",
    "Almost Ready..."
  ];

  @override
  void initState() {
    super.initState();
    
    // Progress Animation (0 to 95% over 5 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), 
    );
    
    _animation = Tween<double>(begin: 0.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn)
    );
    
    _controller.forward();

    // Cycle through status text
    _cycleText();
  }

  void _cycleText() {
    int stepIndex = 0;
    _textTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) return;
      setState(() {
        if (stepIndex < _loadingSteps.length) {
          _loadingText = _loadingSteps[stepIndex];
          stepIndex++;
        }
        _dotCount = (_dotCount + 1) % 4; // 0, 1, 2, 3
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1F25).withOpacity(0.95), // Dark sleek overlay
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2E36), // Slightly lighter card
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- CIRCULAR INDICATOR ---
              SizedBox(
                height: 120,
                width: 120,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Circle
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 8,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        // Progress Circle
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: _animation.value,
                            strokeWidth: 8,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                            backgroundColor: Colors.transparent,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Percentage Text
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${(_animation.value * 100).toInt()}%",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 30),
              
              // --- STATUS TEXT ---
              Text(
                "AI IS WORKING",
                style: TextStyle(
                  color: const Color(0xFF6C63FF).withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  "$_loadingText${"." * _dotCount}",
                  key: ValueKey<String>(_loadingText), // Animate when text changes
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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