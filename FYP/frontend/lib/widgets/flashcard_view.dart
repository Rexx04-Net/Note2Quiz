import 'dart:math';
import 'package:flutter/material.dart';

class FlashcardView extends StatefulWidget {
  final List<dynamic> flashcards;

  const FlashcardView({super.key, required this.flashcards});

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  int _currentIndex = 0;
  bool _showFront = true;

  void _flipCard() {
    setState(() => _showFront = !_showFront);
  }

  void _nextCard() {
    if (_currentIndex < widget.flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showFront = true; // Always start new card on the front
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showFront = true; // Always start previous card on the front
      });
    }
  }

  // --- UI FOR THE FRONT OF THE CARD (QUESTION) ---
  Widget _buildFrontCard(String text) {
    return Container(
      width: 350,
      height: 450,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A35), // Dark card background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Text("QUESTION (FRONT)", style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
          ),
          const Spacer(),
          SingleChildScrollView(
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)),
          ),
          const Spacer(),
          const Icon(Icons.touch_app, color: Colors.white24, size: 24),
          const SizedBox(height: 5),
          const Text("Tap to reveal answer", style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  // --- UI FOR THE BACK OF THE CARD (ANSWER) ---
  Widget _buildBackCard(String text) {
    return Container(
      width: 350,
      height: 450,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF), // Purple accent background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Text("ANSWER (BACK)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
          ),
          const Spacer(),
          SingleChildScrollView(
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white, height: 1.5)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const Center(child: Text("No flashcards available.", style: TextStyle(color: Colors.white)));
    }

    final card = widget.flashcards[_currentIndex];
    final String frontText = card['front'] ?? "?";
    final String backText = card['back'] ?? "?";
    
    double progress = (_currentIndex + 1) / widget.flashcards.length;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- PROGRESS BAR & COUNTER ---
          SizedBox(
            width: 350,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Flashcards", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    Text("Card ${_currentIndex + 1} of ${widget.flashcards.length}", style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)), minHeight: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // --- 3D FLIPPING CARD ANIMATION ---
          GestureDetector(
            onTap: _flipCard,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: _showFront ? 0 : pi),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack, // Gives it a nice realistic bounce when flipping
              builder: (context, double val, child) {
                // Determine if we have flipped past the 90-degree mark (pi / 2)
                bool isBack = val >= (pi / 2);
                
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Adds 3D perspective depth
                    ..rotateY(val),
                  child: isBack
                      // If we are looking at the back, we have to flip the content back around so the text isn't mirrored!
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _buildBackCard(backText),
                        )
                      : _buildFrontCard(frontText),
                );
              },
            ),
          ),
          const SizedBox(height: 40),

          // --- NAVIGATION CONTROLS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous Button
              Container(
                decoration: BoxDecoration(color: _currentIndex > 0 ? const Color(0xFF2A2A35) : Colors.transparent, shape: BoxShape.circle),
                child: IconButton(
                  onPressed: _currentIndex > 0 ? _prevCard : null,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: _currentIndex > 0 ? Colors.white : Colors.white24,
                  padding: const EdgeInsets.all(15),
                ),
              ),
              const SizedBox(width: 30),
              
              // Flip Button
              FloatingActionButton(
                onPressed: _flipCard,
                backgroundColor: const Color(0xFF6C63FF),
                elevation: 10,
                child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28),
              ),
              
              const SizedBox(width: 30),
              
              // Next Button
              Container(
                decoration: BoxDecoration(color: _currentIndex < widget.flashcards.length - 1 ? const Color(0xFF2A2A35) : Colors.transparent, shape: BoxShape.circle),
                child: IconButton(
                  onPressed: _currentIndex < widget.flashcards.length - 1 ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                  color: _currentIndex < widget.flashcards.length - 1 ? Colors.white : Colors.white24,
                  padding: const EdgeInsets.all(15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}