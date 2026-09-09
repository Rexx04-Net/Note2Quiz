import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class MultiplayerQuizScreen extends StatefulWidget {
  final dynamic quizData;
  final String gameCode;
  final String playerName;

  const MultiplayerQuizScreen({
    super.key, 
    required this.quizData, 
    required this.gameCode, 
    required this.playerName
  });

  @override
  State<MultiplayerQuizScreen> createState() => _MultiplayerQuizScreenState();
}

class _MultiplayerQuizScreenState extends State<MultiplayerQuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  
  // Power Card States
  bool _doublePointsActive = false;
  bool _shieldActive = false;

  bool _isAnswered = false;
  String? _selectedOption;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.transparent;

  // 10-Second Countdown Timer States
  static const int _questionDuration = 10;
  int _secondsLeft = _questionDuration;
  Timer? _countdownTimer;

  // Auto-advance Timer after answer/timeout
  Timer? _autoAdvanceTimer;
  int _advanceSecondsLeft = 4;

  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    if (widget.quizData is List) {
      _questions = widget.quizData;
    }
    if (_questions.isNotEmpty) {
      _startQuestionTimer();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  // --- 10-SECOND COUNTDOWN LOGIC ---
  void _startQuestionTimer() {
    _countdownTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    setState(() {
      _secondsLeft = _questionDuration;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _selectedOption = null;

      if (_shieldActive) {
        _feedbackMessage = "Time's up! ⏰ But your SHIELD protected your streak! 🛡️";
        _feedbackColor = Colors.orangeAccent;
        _shieldActive = false;
      } else {
        _streak = 0;
        _feedbackMessage = "Time's up! ⏰ No answer recorded.";
        _feedbackColor = const Color(0xFFEF4444);
      }
    });

    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _advanceSecondsLeft = 4;
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_advanceSecondsLeft > 1) {
        setState(() {
          _advanceSecondsLeft--;
        });
      } else {
        timer.cancel();
        _nextQuestion();
      }
    });
  }

  // --- API Sync ---
  Future<void> _syncScoreToServer() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/update-score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': widget.gameCode,
          'name': widget.playerName,
          'score': _score
        }),
      );
    } catch (e) {
      debugPrint("Score sync failed: $e");
    }
  }

  // --- Answer Handling ---
  void _handleAnswer(String option) {
    if (_isAnswered) return;
    _countdownTimer?.cancel();

    final currentQ = _questions[_currentIndex];
    String correctAnswer = (currentQ['answer'] ?? "").toString();
    bool isCorrect = _checkMatch(option, correctAnswer);

    setState(() {
      _isAnswered = true;
      _selectedOption = option;

      if (isCorrect) {
        // Speed bonus: up to 10 points depending on remaining seconds
        int speedBonus = _secondsLeft;
        int pointsEarned = (_doublePointsActive ? 40 : 20) + speedBonus;
        _score += pointsEarned;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;

        _feedbackMessage = speedBonus > 0
            ? "Correct! +$pointsEarned pts (+$speedBonus speed bonus! ⚡)"
            : "Correct! +$pointsEarned pts";
        _feedbackColor = const Color(0xFF10B981);
        _doublePointsActive = false;

        _syncScoreToServer();

        // Check for Power Card trigger (Every 3 correct)
        if (_streak > 0 && _streak % 3 == 0) {
          _showPowerCardDialog();
        }
      } else {
        if (_shieldActive) {
          _feedbackMessage = "Wrong! But your SHIELD protected your streak! 🛡️";
          _feedbackColor = Colors.orangeAccent;
          _shieldActive = false;
        } else {
          _streak = 0;
          _feedbackMessage = "Wrong! Streak lost. ❌";
          _feedbackColor = const Color(0xFFEF4444);
        }
      }
    });

    _startAutoAdvance();
  }

  bool _checkMatch(String selected, String correct) {
    String cSel = selected.trim().toUpperCase();
    String cCor = correct.trim().toUpperCase();
    if (cSel == cCor) return true;
    if (cSel.startsWith("$cCor)") || cSel.startsWith("$cCor.")) return true;
    if (cCor.length == 1 && cSel.startsWith(cCor)) return true;
    if (cCor.contains(")") && cCor.split(")").last.trim() == cSel) return true;
    return false;
  }

  void _nextQuestion() {
    _countdownTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedOption = null;
        _feedbackMessage = null;
        _feedbackColor = Colors.transparent;
      });
      _startQuestionTimer();
    } else {
      _showGameOverDialog();
    }
  }

  // --- GAME OVER SUMMARY MODAL ---
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text("Quiz Finished!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text("Player: ${widget.playerName}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0062FE).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0062FE).withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Text("FINAL SCORE", style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text("$_score", style: const TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Best Streak: $_bestStreak 🔥", style: const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0062FE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Return to Lobby", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- POWER CARDS ---
  void _showPowerCardDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: const Text("🔥 3 IN A ROW! Pick a Power Card 🔥", textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _powerCard("2x Multiplier", "Next question is worth double!", Icons.bolt, Colors.yellow, () {
              setState(() => _doublePointsActive = true);
              Navigator.pop(context);
            }),
            _powerCard("Shield", "Protects your streak if you get one wrong.", Icons.shield, Colors.blue, () {
              setState(() => _shieldActive = true);
              Navigator.pop(context);
            }),
            _powerCard("+50 Free Points", "Instant score boost!", Icons.star, Colors.green, () {
              setState(() { _score += 50; _syncScoreToServer(); });
              Navigator.pop(context);
            }),
            _powerCard("Coin Purse", "Gain 20 points instantly.", Icons.monetization_on, Colors.amber, () {
              setState(() { _score += 20; _syncScoreToServer(); });
              Navigator.pop(context);
            }),
          ],
        ),
      )
    );
  }

  Widget _powerCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onTap: onTap,
      ),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1424),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0062FE))),
      );
    }

    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final correctAnswer = (q['answer'] ?? '').toString();
    final explanation = (q['explanation'] ?? q['rationale'] ?? q['hint'] ?? '').toString().trim();

    // Timer Color Logic
    Color timerColor;
    if (_secondsLeft > 5) {
      timerColor = const Color(0xFF00D2FF);
    } else if (_secondsLeft > 2) {
      timerColor = Colors.amberAccent;
    } else {
      timerColor = const Color(0xFFEF4444);
    }

    return Title(
      title: 'Note2Quiz',
      color: const Color(0xFF0062FE),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1424),
        appBar: AppBar(
          title: Text(
            "Question ${_currentIndex + 1} / ${_questions.length}   |   PIN: ${widget.gameCode}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Text(
                    "SCORE: $_score",
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Timer & Streak Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Streak & Power-ups
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Text(
                                "Streak: $_streak 🔥",
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_doublePointsActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.yellow.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  "2x ⚡",
                                  style: TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            if (_shieldActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  "SHIELD 🛡️",
                                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // 10s Countdown Badge
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: timerColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: timerColor.withOpacity(0.6), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, color: timerColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "${_secondsLeft}s",
                                style: TextStyle(
                                  color: timerColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Visual Countdown Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        tween: Tween<double>(
                          begin: 1.0,
                          end: (_secondsLeft / _questionDuration).clamp(0.0, 1.0),
                        ),
                        builder: (context, val, _) => LinearProgressIndicator(
                          value: val,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Question, Options & Explanation Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          q['question'] ?? "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Options
                      ...List.generate(options.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildOptionBtn(options[i], correctAnswer),
                        );
                      }),

                      // 3. Explanation & Key Takeaway Card (Shown once answered or timed out)
                      if (_isAnswered) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2238),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF0062FE).withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0062FE).withOpacity(0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: Color(0xFF00D2FF), size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Explanation & Concept Rationale",
                                    style: TextStyle(
                                      color: Color(0xFF00D2FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Next Question Button
                                  FilledButton.icon(
                                    onPressed: () {
                                      _autoAdvanceTimer?.cancel();
                                      _nextQuestion();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0062FE),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.arrow_forward, size: 16),
                                    label: Text(
                                      _currentIndex < _questions.length - 1
                                          ? "Next (${_advanceSecondsLeft}s)"
                                          : "Finish (${_advanceSecondsLeft}s)",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                explanation.isNotEmpty
                                    ? explanation
                                    : "Correct Answer: '$correctAnswer'. Understanding this concept reinforces key lecture principles.",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. Feedback Result Strip
              if (_feedbackMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  width: double.infinity,
                  color: _feedbackColor,
                  child: Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionBtn(String text, String correct) {
    Color bg = const Color(0xFF161B2E);
    BorderSide border = BorderSide(color: Colors.white.withOpacity(0.12), width: 1);
    Widget? trailingIcon;
    Color textColor = Colors.white;

    if (_isAnswered) {
      bool isThisOptionCorrect = _checkMatch(text, correct);
      bool isThisOptionSelected = (text == _selectedOption);

      if (isThisOptionCorrect) {
        bg = const Color(0xFF10B981).withOpacity(0.85);
        border = const BorderSide(color: Color(0xFF34D399), width: 2);
        trailingIcon = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text("Correct", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        );
      } else if (isThisOptionSelected) {
        bg = const Color(0xFFEF4444).withOpacity(0.85);
        border = const BorderSide(color: Color(0xFFF87171), width: 2);
        trailingIcon = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text("Your choice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        );
      } else {
        bg = Colors.white.withOpacity(0.04);
        textColor = Colors.white38;
      }
    }

    return InkWell(
      onTap: _isAnswered ? null : () => _handleAnswer(text),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: _isAnswered && _checkMatch(text, correct) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }
}