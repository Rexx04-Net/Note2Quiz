import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String? userEmail;
  const LobbyScreen({super.key, this.userEmail});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  // --- SCROLLING LOGIC ---
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrollingForward = true;

  // --- ANIMATIONS ---
  late AnimationController _heroController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));
    _heroController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    const double scrollSpeed = 1.0;
    const Duration tickDuration = Duration(milliseconds: 30);
    _scrollTimer = Timer.periodic(tickDuration, (timer) {
      if (!_scrollController.hasClients) return;
      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentScroll = _scrollController.offset;
      if (_isScrollingForward) {
        if (currentScroll >= maxScroll) _isScrollingForward = false;
        else _scrollController.jumpTo(currentScroll + scrollSpeed);
      } else {
        if (currentScroll <= 0) _isScrollingForward = true;
        else _scrollController.jumpTo(currentScroll - scrollSpeed);
      }
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // --- NEW NAVIGATION LOGIC ---
  
  // 1. "Try Note2Quiz" -> Go STRAIGHT to Dashboard (No Login required)
  void _enterAppDirectly() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        // If email is null, we pass "Guest" so the dashboard still works
        builder: (_) => DashboardScreen(email: widget.userEmail ?? "Guest")
      )
    );
  }

  // 2. "Log In" -> Go to Login Screen
  void _goToLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F25),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -150, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 600, height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.08),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.15), blurRadius: 150, spreadRadius: 50)],
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- NAV BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF6C63FF), size: 30),
                      const SizedBox(width: 10),
                      const Text("Note2Quiz", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      
                      // LOG IN BUTTON (Only shows if not logged in)
                      if (widget.userEmail == null)
                        TextButton(
                          onPressed: _goToLogin, // ✅ Goes to Login Screen
                          child: const Text("Log In", style: TextStyle(color: Colors.white70))
                        ),

                      const SizedBox(width: 20),
                      
                      // MAIN CTA (Try Note2Quiz)
                      ElevatedButton(
                        onPressed: _enterAppDirectly, // ✅ Goes directly to Dashboard
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                        ),
                        child: const Text("Try Note2Quiz", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- HERO SECTION ---
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            children: [
                              TextSpan(text: "Understand ", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5, fontFamily: 'Roboto')),
                              TextSpan(text: "Anything", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Color(0xFF6C63FF), letterSpacing: -1.5, fontFamily: 'Roboto')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 700,
                          child: Text(
                            "Your AI-powered research and study partner. Upload documents, YouTube videos, or notes and instantly generate quizzes, flashcards, and mind maps.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, color: Colors.white54, height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 50),
                        
                        // BIG CTA BUTTON
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _enterAppDirectly, // ✅ Goes directly to Dashboard
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)]),
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))]
                              ),
                              child: const Text("Try Note2Quiz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 120),

                // --- FEATURES GRID ---
                const Text("How people are using Note2Quiz", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 60),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Wrap(
                    spacing: 40, runSpacing: 40, alignment: WrapAlignment.center,
                    children: [
                      _buildFeatureColumn(Icons.school_outlined, "Power study", "Upload lecture slides, textbooks, and notes. Ask Note2Quiz to create practice exams."),
                      _buildFeatureColumn(Icons.account_tree_outlined, "Organize thinking", "Turn messy thoughts into structured Mind Maps and Executive Reports automatically."),
                      _buildFeatureColumn(Icons.lightbulb_outline, "Spark new ideas", "Generate infinite flashcards and gamified quizzes to master any topic in minutes."),
                    ],
                  ),
                ),

                const SizedBox(height: 120),

                // --- MOVING CARDS ---
                const Text("What functions inside?", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 40),
                
                SizedBox(
                  height: 320, 
                  child: ListView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(), 
                    children: [
                      const SizedBox(width: 20),
                      _buildHoverCard("Too many readings?", "😫", Colors.redAccent, "AI Summarizer", "Summarize PDFs in seconds.", Icons.article, Colors.blueAccent),
                      _buildHoverCard("Can't memorize?", "🧠", Colors.orangeAccent, "Smart Flashcards", "Spaced repetition built-in.", Icons.style, Colors.greenAccent),
                      _buildHoverCard("Exam tomorrow?", "🔥", Colors.deepOrangeAccent, "Boss Battles", "Gamified practice tests.", Icons.sports_esports, Colors.redAccent),
                      _buildHoverCard("Messy ideas?", "🕸️", Colors.purpleAccent, "Mind Maps", "Auto-structure your thoughts.", Icons.account_tree, Colors.orangeAccent),
                      _buildHoverCard("Long lectures?", "📺", Colors.red, "Video to Notes", "Get transcripts instantly.", Icons.play_circle_filled, Colors.white),
                      _buildHoverCard("Bored students?", "😴", Colors.grey, "Live Games", "Host classroom battles.", Icons.cast_for_education, Colors.tealAccent),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),

                const SizedBox(height: 100),

                // --- FOOTER ---
                Container(
                  padding: const EdgeInsets.all(40),
                  width: double.infinity,
                  color: Colors.black12,
                  child: const Column(
                    children: [
                      Icon(Icons.bolt, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Note2Quiz Created by Rexx", style: TextStyle(color: Colors.white30)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildFeatureColumn(IconData icon, String title, String desc) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 40),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHoverCard(
    String qTitle, String qEmoji, Color qColor, 
    String aTitle, String aDesc, IconData aIcon, Color aColor
  ) {
    return HoverCard(
      initialContent: Container(
        width: 260, height: 300,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2E36),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(qEmoji, style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 20),
            Text(qTitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: qColor)),
            const SizedBox(height: 10),
            Text("Hover for answer", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
      hoverContent: Container(
        width: 280, height: 320, 
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: aColor.withOpacity(0.15), 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: aColor),
          boxShadow: [BoxShadow(color: aColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 30, backgroundColor: aColor, child: Icon(aIcon, color: Colors.white, size: 30)),
            const SizedBox(height: 20),
            Text(aTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(aDesc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// --- HOVER CARD WIDGET ---
class HoverCard extends StatefulWidget {
  final Widget initialContent;
  final Widget hoverContent;
  const HoverCard({super.key, required this.initialContent, required this.hoverContent});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInBack,
          child: _isHovered 
            ? KeyedSubtree(key: const ValueKey("hover"), child: widget.hoverContent) 
            : KeyedSubtree(key: const ValueKey("initial"), child: widget.initialContent),
        ),
      ),
    );
  }
}