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
  
  // Power Card States
  bool _doublePointsActive = false;
  bool _shieldActive = false;

  bool _isAnswered = false;
  String? _selectedOption;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.transparent;

  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    if (widget.quizData is List) _questions = widget.quizData;
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

  // --- Logic ---
  void _handleAnswer(String option) {
    if (_isAnswered) return;

    final currentQ = _questions[_currentIndex];
    String correctAnswer = currentQ['answer'] ?? "";
    bool isCorrect = _checkMatch(option, correctAnswer);

    setState(() {
      _isAnswered = true;
      _selectedOption = option;

      if (isCorrect) {
        int pointsEarned = _doublePointsActive ? 40 : 20;
        _score += pointsEarned;
        _streak++;
        _feedbackMessage = "Correct! +$pointsEarned pts";
        _feedbackColor = Colors.green;
        _doublePointsActive = false; // Reset multiplier

        _syncScoreToServer();

        // Check for Power Card trigger (Every 3 correct)
        if (_streak > 0 && _streak % 3 == 0) {
          _showPowerCardDialog();
        }

      } else {
        if (_shieldActive) {
          _feedbackMessage = "Wrong! But your SHIELD protected your streak! 🛡️";
          _feedbackColor = Colors.orange;
          _shieldActive = false; // Consume shield
        } else {
          _streak = 0;
          _feedbackMessage = "Wrong! Streak lost. ❌";
          _feedbackColor = Colors.red;
        }
      }
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion();
    });
  }

  bool _checkMatch(String selected, String correct) {
    String cSel = selected.trim().toUpperCase();
    String cCor = correct.trim().toUpperCase();
    if (cSel == cCor || cSel.startsWith("$cCor)") || cSel.startsWith("$cCor.")) return true;
    return false;
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedOption = null;
        _feedbackMessage = null;
      });
    } else {
      // Game Over Screen logic goes here
      Navigator.pop(context); // Temporarily just exit
    }
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
    if (_questions.isEmpty) return const Scaffold(body: Center(child: Text("Loading...")));

    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        // ✅ FIXED: Now shows "Question 1 / 10 | PIN: XXXXX"
        title: Text("Question ${_currentIndex + 1} / ${_questions.length}   |   PIN: ${widget.gameCode}", style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text("SCORE: $_score", style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
          ))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Streak: $_streak 🔥", style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_doublePointsActive) const Text("2x MULTIPLIER ACTIVE!", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                if (_shieldActive) const Text("SHIELD ACTIVE 🛡️", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Text(q['question'] ?? "", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_,__) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => _buildOptionBtn(options[i], q['answer']),
              ),
            ),
            if (_feedbackMessage != null)
              Container(
                padding: const EdgeInsets.all(15),
                width: double.infinity,
                color: _feedbackColor,
                child: Text(_feedbackMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn(String text, String correct) {
    Color bg = Colors.white12;
    if (_isAnswered) {
      if (_checkMatch(text, correct)) bg = Colors.green.withOpacity(0.8);
      else if (text == _selectedOption) bg = Colors.red.withOpacity(0.8);
    }

    return InkWell(
      onTap: _isAnswered ? null : () => _handleAnswer(text),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
        child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }
}