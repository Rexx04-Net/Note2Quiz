import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class TeacherLeaderboardScreen extends StatefulWidget {
  final String gameCode;
  const TeacherLeaderboardScreen({super.key, required this.gameCode});

  @override
  State<TeacherLeaderboardScreen> createState() => _TeacherLeaderboardScreenState();
}

class _TeacherLeaderboardScreenState extends State<TeacherLeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _isWaiting = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Fetch live scores every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchLeaderboard();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/get-leaderboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.gameCode}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _leaderboard = data['leaderboard'];
          _isWaiting = data['status'] == 'waiting';
        });
      }
    } catch (e) {
      debugPrint("Leaderboard error: $e");
    }
  }

  Future<void> _startGame() async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/start-game'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.gameCode}),
      );
      if (response.statusCode == 200) {
        setState(() => _isWaiting = false);
      }
    } catch (e) {
      debugPrint("Start game error: $e");
    }
  }

  // Helper to determine row color based on rank
  Color _getRankColor(int index) {
    if (_isWaiting) return Colors.white10; // No colors while waiting
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.blueGrey.shade300; // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.white24; // Everyone else
  }

  @override
  Widget build(BuildContext context) {
    // We calculate a fixed height for each player's row so we can animate them
    const double rowHeight = 80.0; 
    const double rowSpacing = 15.0;
    final double totalStackHeight = _leaderboard.length * (rowHeight + rowSpacing);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(title: const Text("Live Leaderboard"), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("Join at Note2Quiz with Game PIN:", style: TextStyle(color: Colors.white70, fontSize: 18)),
            Text(widget.gameCode, style: const TextStyle(color: Colors.amber, fontSize: 50, fontWeight: FontWeight.bold, letterSpacing: 8)),
            const SizedBox(height: 10),
            
            // Big Start Button
            if (_isWaiting)
              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow, size: 30),
                label: const Text("START QUIZ NOW", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),

            const SizedBox(height: 20),
            Text(_isWaiting ? "Players in Lobby" : "🏆 Live Racing Leaderboard 🏆", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // ✅ THE ANIMATED LEADERBOARD
            Expanded(
              child: _leaderboard.isEmpty 
              ? const Text("Waiting for players to join...", style: TextStyle(color: Colors.white54))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    height: totalStackHeight,
                    child: Stack(
                      children: _leaderboard.asMap().entries.map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        final String playerName = player['name'];
                        final int playerScore = player['score'];

                        return AnimatedPositioned(
                          // ✅ CRITICAL: The ValueKey tells Flutter to track this specific player's widget as they move
                          key: ValueKey(playerName), 
                          duration: const Duration(milliseconds: 800), // 0.8 seconds to slide
                          curve: Curves.easeInOutCubic, // Cool swoosh animation
                          top: index * (rowHeight + rowSpacing),
                          left: 50,
                          right: 50,
                          height: rowHeight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                            decoration: BoxDecoration(
                              color: _getRankColor(index).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: _getRankColor(index), width: index < 3 && !_isWaiting ? 2 : 1)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text("#${index + 1}", style: TextStyle(color: _getRankColor(index), fontSize: 24, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 20),
                                    Text(playerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                if (!_isWaiting)
                                  Text("$playerScore pts", style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ),
            )
          ],
        ),
      ),
    );
  }
}