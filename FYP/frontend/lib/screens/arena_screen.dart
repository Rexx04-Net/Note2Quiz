import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class ArenaScreen extends StatefulWidget {
  final List<dynamic> battleData;
  final String? multiplayerCode;
  final String? playerName;

  const ArenaScreen({
    super.key, 
    required this.battleData, 
    this.multiplayerCode, 
    this.playerName
  });

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> with TickerProviderStateMixin {
  int _currentQIndex = 0;
  double _playerHP = 100;
  double _monsterHP = 100;
  int _totalScore = 0;
  
  bool _isTurnLocked = false;
  String _feedbackText = "Choose your attack!";
  Color _feedbackColor = Colors.white;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn))..addStatusListener((status) { if (status == AnimationStatus.completed) _shakeController.reset(); });
  }

  Future<void> _sendScoreUpdate() async {
    if (widget.multiplayerCode == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/update-score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': widget.multiplayerCode,
          'name': widget.playerName,
          'score': _totalScore
        })
      );
    } catch (e) {
      debugPrint("Score Error: $e");
    }
  }

  void _handleAnswer(String selectedOption) {
    if (_isTurnLocked) return;
    setState(() => _isTurnLocked = true);
    
    final currentQ = widget.battleData[_currentQIndex];
    double damage = (currentQ['damage'] ?? 20).toDouble();

    if (selectedOption == currentQ['answer']) {
      setState(() { 
        _monsterHP = (_monsterHP - damage).clamp(0, 100); 
        _feedbackText = "CRITICAL HIT!"; 
        _feedbackColor = Colors.greenAccent;
        _totalScore += 100; 
      });
      _shakeController.forward();
    } else {
      setState(() { 
        _playerHP = (_playerHP - 25).clamp(0, 100); 
        _feedbackText = "MISS!"; 
        _feedbackColor = Colors.redAccent; 
        _totalScore = (_totalScore - 10).clamp(0, 9999);
      });
      _shakeController.forward();
    }

    _sendScoreUpdate(); 

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_monsterHP <= 0 || _playerHP <= 0) {
        _endGame(_monsterHP <= 0); // Pass true if monster died
      } else if (_currentQIndex < widget.battleData.length - 1) {
        setState(() { _currentQIndex++; _isTurnLocked = false; _feedbackText = "Choose your attack!"; _feedbackColor = Colors.white; });
      } else {
        _endGame(_monsterHP <= 0);
      }
    });
  }

  void _endGame(bool isVictory) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => ResultScreen(isVictory: isVictory, score: _totalScore))
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.battleData[_currentQIndex];
    return Scaffold(
      appBar: AppBar(title: const Text("BOSS BATTLE"), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) => Transform.translate(offset: Offset(sin(_shakeController.value * pi * 4) * 10, 0), child: child),
        child: Column(children: [
          Expanded(flex: 4, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildAvatar(widget.playerName ?? "You", "🧙‍♂️", _playerHP, Colors.blue),
            const Text("VS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.grey)),
            _buildAvatar("Boss", "👹", _monsterHP, Colors.red)
          ])),
          Expanded(flex: 6, child: Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Color(0xFF232342), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_feedbackText, textAlign: TextAlign.center, style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            Text(question['question'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ...(question['options'] as List).map((opt) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, padding: const EdgeInsets.all(16)),
              onPressed: _isTurnLocked ? null : () => _handleAnswer(opt), 
              child: Text(opt, style: const TextStyle(color: Colors.white))
            )))
          ])))
        ]),
      ),
    );
  }
  
  Widget _buildAvatar(String label, String emoji, double hp, Color color) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(emoji, style: const TextStyle(fontSize: 60)), Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), SizedBox(width: 80, child: LinearProgressIndicator(value: hp / 100, color: color))]);
  }
}

class ResultScreen extends StatelessWidget {
  final bool isVictory;
  final int score;
  const ResultScreen({super.key, required this.isVictory, required this.score});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isVictory ? const Color(0xFF1E5631) : const Color(0xFF4A1919),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isVictory ? Icons.emoji_events : Icons.heart_broken, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            Text(isVictory ? "VICTORY!" : "GAME OVER", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text("Final Score: $score", style: const TextStyle(fontSize: 24, color: Colors.amber)),
            const SizedBox(height: 40),
            ElevatedButton(
              // ✅ FIX: Return the victory status when popping
              onPressed: () => Navigator.pop(context, isVictory), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: const Text("Return to Map")
            )
          ],
        ),
      ),
    );
  }
}