import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartNoteTaker;
  final VoidCallback onStartFlashcards;
  final VoidCallback onStartQuiz;
  final VoidCallback onStartChallenge;
  
  // New fields to handle input directly on Home Screen
  final TextEditingController inputController;
  final PlatformFile? selectedFile;
  final VoidCallback onPickFile;
  final Function(int inputType) onGenerate; // 0=File, 1=YouTube, 2=Text

  const HomeScreen({
    super.key,
    required this.onStartNoteTaker,
    required this.onStartFlashcards,
    required this.onStartQuiz,
    required this.onStartChallenge,
    required this.inputController,
    required this.selectedFile,
    required this.onPickFile,
    required this.onGenerate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrollingForward = true;
  int _homeInputTab = 2; // Default to Text on home screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- HERO SECTION ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6C63FF).withOpacity(0.05), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const Text("Your Everyday Study Partner", textAlign: TextAlign.center, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -1.5)),
                const SizedBox(height: 20),
                const Text("From confused to confident in minutes. Everything you need to learn faster, stress less, score higher.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 40),
                
                // --- MAIN INPUT CARD ---
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))]
                  ),
                  child: Column(
                    children: [
                      // Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTabButton("Upload", 0, Icons.cloud_upload),
                            _buildTabButton("YouTube", 1, Icons.video_library),
                            _buildTabButton("Text", 2, Icons.text_fields),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Input Area
                      if (_homeInputTab == 0) 
                        GestureDetector(
                          onTap: widget.onPickFile,
                          child: Container(
                            height: 150, width: double.infinity,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!, width: 2), borderRadius: BorderRadius.circular(15)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.cloud_upload_outlined, size: 40, color: Theme.of(context).primaryColor),
                                const SizedBox(height: 10),
                                Text(widget.selectedFile?.name ?? "Click to upload PDF/PPTX", style: const TextStyle(color: Colors.grey))
                            ]),
                          ),
                        )
                      else if (_homeInputTab == 1)
                        TextField(
                          controller: widget.inputController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: "Paste YouTube Link (must have captions)",
                            filled: true, fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.link, color: Colors.grey),
                          ),
                        )
                      else 
                        TextField(
                          controller: widget.inputController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: "Paste your study notes, questions, or topics here...",
                            filled: true, fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                          ),
                        ),

                      const SizedBox(height: 30),
                      
                      // Action Button
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome, color: Colors.white),
                          label: const Text("Generate Study Material", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () => widget.onGenerate(_homeInputTab),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- FEATURES CAROUSEL ---
          const SizedBox(height: 40),
          SizedBox(
            height: 350,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
              children: [
                const SizedBox(width: 40),
                _buildInteractiveCard("Stuck on Homework?", "2AM and still clueless?", Icons.help_outline, Colors.orange, "Homework = Done", "Step-by-step AI solutions.", Icons.check_circle, Colors.green, widget.onStartNoteTaker),
                _buildInteractiveCard("Lost in Class?", "Professor talks too fast?", Icons.sentiment_dissatisfied, Colors.redAccent, "Smart Notes", "Instant summaries & structure.", Icons.article, const Color(0xFF6C63FF), widget.onStartNoteTaker),
                _buildInteractiveCard("Test Anxiety?", "Feeling unprepared?", Icons.psychology_alt, Colors.blueGrey, "Ace the Test", "AI Quizzes tailored to you.", Icons.emoji_events, Colors.amber, widget.onStartQuiz),
                _buildInteractiveCard("Memorization Hard?", "Facts won't stick?", Icons.repeat, Colors.brown, "Flashcard Mastery", "Learn faster with repetition.", Icons.style, Colors.teal, widget.onStartFlashcards),
                _buildInteractiveCard("Bored Studying?", "Can't focus?", Icons.snooze, Colors.grey, "Challenge Mode", "Gamified learning path.", Icons.map, Colors.purple, widget.onStartChallenge),
                const SizedBox(width: 40),
              ],
            ),
          ),
          
          // --- GRID SECTION ---
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const Text("One Place for All Your Study", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 10),
                const Text("No more app switching, no more lost notes, just better learning.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 50),
                
                LayoutBuilder(builder: (context, constraints) {
                    double width = constraints.maxWidth > 900 ? (constraints.maxWidth - 60) / 2 : constraints.maxWidth;
                    return Wrap(
                      spacing: 30, runSpacing: 30, alignment: WrapAlignment.center,
                      children: [
                        _buildInteractiveFeatureCard("AI Note Taker", "Turn lectures, PDFs, and videos into organized study notes instantly.", Icons.article, const Color(0xFF6C63FF), width, widget.onStartNoteTaker),
                        _buildInteractiveFeatureCard("AI Flashcards", "Smart flashcards that know when you're about to forget.", Icons.style, Colors.green, width, widget.onStartFlashcards),
                        _buildInteractiveFeatureCard("AI Quiz Generator", "Generate practice quizzes from your materials.", Icons.quiz, Colors.blue, width, widget.onStartQuiz),
                        _buildInteractiveFeatureCard("Challenge Map", "Gamify your learning journey. Unlock levels, defeat bosses.", Icons.map, Colors.orange, width, widget.onStartChallenge),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),

          // --- FOOTER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
            color: const Color(0xFFF9FAFB),
            child: Column(
              children: [
                const Text("Ready to Learn Smarter?", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black87)),
                const SizedBox(height: 15),
                const Text("Join thousands of students mastering their subjects with Note2Quiz.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: widget.onStartQuiz,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text("Get Started Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    bool isSelected = _homeInputTab == index;
    return GestureDetector(
      onTap: () => setState(() => _homeInputTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(25), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)] : []),
        child: Row(children: [Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.grey), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))]),
      ),
    );
  }

  // Helper for the auto-scrolling cards
  Widget _buildInteractiveCard(String t1, String s1, IconData i1, Color c1, String t2, String s2, IconData i2, Color c2, VoidCallback onTap) {
    return HoverCard(initialContent: _buildCardContent(t1, s1, i1, c1, false), hoverContent: _buildCardContent(t2, s2, i2, c2, true), onTap: onTap);
  }

  Widget _buildCardContent(String title, String subtitle, IconData icon, Color color, bool isHovered) {
    return Container(
      width: 300, height: 320, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: isHovered ? color.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: isHovered ? color : Colors.grey.shade100, width: 2), boxShadow: [BoxShadow(color: isHovered ? color.withOpacity(0.1) : Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 40, backgroundColor: isHovered ? color : Colors.grey.shade50, child: Icon(icon, size: 40, color: isHovered ? Colors.white : color)),
        const SizedBox(height: 30),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHovered ? color : Colors.black87)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ]),
    );
  }

  // Helper for the "One Place for All" cards
  Widget _buildInteractiveFeatureCard(String title, String desc, IconData icon, Color color, double width, VoidCallback onTap) {
    return HoverScaleCard(
      onTap: onTap,
      child: Container(
        width: width, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: color.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.transparent)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Icon(icon, color: color, size: 30)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), Icon(Icons.arrow_outward, size: 20, color: Colors.grey[400])]),
            const SizedBox(height: 10),
            Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
          ]))
        ]),
      ),
    );
  }
}

// Hover Widget
class HoverCard extends StatefulWidget {
  final Widget initialContent;
  final Widget hoverContent;
  final VoidCallback onTap;
  const HoverCard({super.key, required this.initialContent, required this.hoverContent, required this.onTap});
  @override
  State<HoverCard> createState() => _HoverCardState();
}
class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: widget.onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _isHovered ? widget.hoverContent : widget.initialContent))));
  }
}

// Scale Widget
class HoverScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const HoverScaleCard({super.key, required this.child, required this.onTap});
  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}
class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: widget.onTap, child: AnimatedScale(scale: _isHovered ? 1.05 : 1.0, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut, child: widget.child)));
  }
}