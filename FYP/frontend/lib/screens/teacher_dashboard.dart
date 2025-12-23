import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class TeacherDashboard extends StatefulWidget {
  final String gameCode;
  const TeacherDashboard({super.key, required this.gameCode});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic> _leaderboard = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 🔄 POLLING: Check for updates every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) => _fetchLeaderboard());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get-leaderboard/${widget.gameCode}'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _leaderboard = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Dashboard"), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          // Game Code Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            color: const Color(0xFF6C63FF),
            child: Column(
              children: [
                const Text("JOIN CODE", style: TextStyle(color: Colors.white70, letterSpacing: 2)),
                Text(widget.gameCode, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text("Ask students to enter this code", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Text("Live Rankings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          
          Expanded(
            child: _leaderboard.isEmpty 
              ? const Center(child: Text("Waiting for players to join..."))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final player = _leaderboard[index]; // Format: ["Name", Score]
                    return Card(
                      color: index == 0 ? Colors.amber.withOpacity(0.2) : Colors.white10,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0 ? Colors.amber : Colors.grey,
                          child: Text("#${index + 1}"),
                        ),
                        title: Text(player[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        trailing: Text("${player[1]} pts", style: const TextStyle(fontSize: 20, color: Colors.greenAccent)),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}