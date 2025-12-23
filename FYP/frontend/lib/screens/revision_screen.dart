import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'arena_screen.dart';
import '../config.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class RevisionScreen extends StatefulWidget {
  final String topic;
  final String notes;
  final int level;
  final bool isBoss;

  const RevisionScreen({
    super.key, 
    required this.topic, 
    required this.notes, 
    required this.level,
    required this.isBoss
  });

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  bool _isLoading = false;

  Future<void> _startBattle() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/generate-quiz'));
      
      // Generate quiz based on the notes they just read
      String prompt = "Generate a quiz based on these revision notes about ${widget.topic}.";
      if (widget.isBoss) prompt += " This is a HARD Boss Battle.";
      
      request.fields['notes'] = "${widget.notes}\n\n$prompt"; 
      request.fields['difficulty'] = widget.isBoss ? "Hard" : "Standard";

      var response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        final quizData = jsonDecode(response.body);
        if (mounted) {
          // Go to Arena, wait for result
          final bool? result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ArenaScreen(battleData: quizData))
          );
          
          // Pass the result back to LobbyScreen
          if (mounted) {
             Navigator.pop(context, result);
          }
        }
      } else {
        throw "Failed to generate battle.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Level ${widget.level}: Revision"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(value: 0.5, color: Theme.of(context).primaryColor, backgroundColor: Colors.grey[200]),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TOPIC: ${widget.topic.toUpperCase()}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Text("Review before you fight!", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20),
                  
                  // Notes Content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Text(
                      widget.notes,
                      style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!))
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Ready?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.isBoss ? "Boss Battle Ahead!" : "Quiz Challenge", style: TextStyle(color: widget.isBoss ? Colors.red : Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _startBattle,
                      icon: const Icon(Icons.bolt), // ✅ FIX: Replaced swords with bolt
                      label: const Text("START CHALLENGE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isBoss ? Colors.redAccent : const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    )
              ],
            ),
          )
        ],
      ),
    );
  }
}