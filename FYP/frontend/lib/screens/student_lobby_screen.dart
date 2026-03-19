import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'multiplayer_quiz_screen.dart';

class StudentLobbyScreen extends StatefulWidget {
  final String gameCode;
  final String playerName;
  final dynamic quizData;

  const StudentLobbyScreen({
    super.key, required this.gameCode, required this.playerName, required this.quizData
  });

  @override
  State<StudentLobbyScreen> createState() => _StudentLobbyScreenState();
}

class _StudentLobbyScreenState extends State<StudentLobbyScreen> {
  Timer? _timer;
  List<String> _players = [];
  String _status = 'waiting';

  @override
  void initState() {
    super.initState();
    // Ask the server every 2 seconds if the teacher started the game
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/get-game-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.gameCode}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _players = List<String>.from(data['players']);
          _status = data['status'];
        });

        // ✅ If the teacher started the game, jump to the Quiz!
        if (_status == 'playing') {
          _timer?.cancel();
          if (!mounted) return;
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => MultiplayerQuizScreen(
              quizData: widget.quizData, gameCode: widget.gameCode, playerName: widget.playerName
            ))
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(title: Text("Game PIN: ${widget.gameCode}"), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orangeAccent),
            const SizedBox(height: 30),
            Text("You are in, ${widget.playerName}!", style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Waiting for teacher to start...", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 50),
            Text("${_players.length} Players in Lobby:", style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  return Text("🎮 ${_players[index]}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                }
              )
            )
          ],
        ),
      )
    );
  }
}