import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'notebook_screen.dart';
import 'multiplayer_quiz_screen.dart'; // ✅ Connects to Student Screen

class HomeScreen extends StatefulWidget {
  final String? email;
  const HomeScreen({super.key, this.email});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _notebooks = [];
  bool _isLoading = true;
  String _userEmail = "guest"; 

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _userEmail = widget.email!;
    _fetchNotebooks();
  }

  // --- API CALLS ---
  Future<void> _fetchNotebooks() async {
    setState(() => _isLoading = true);
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/get-notebooks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _userEmail}),
      );
      if (response.statusCode == 200) {
        setState(() => _notebooks = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching notebooks: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNotebook() async {
    String? title = await _showInputDialog("New Notebook", "Enter title (e.g. Biology 101)");
    if (title == null || title.isEmpty) return;

    try {
      var response = await http.post(
        Uri.parse('$baseUrl/create-notebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _userEmail, 'title': title}),
      );
      if (response.statusCode == 200) _fetchNotebooks(); 
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ✅ NEW: Delete Notebook Logic
  Future<void> _deleteNotebook(String id) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/delete-notebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      _fetchNotebooks(); // Refresh the list
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  // ✅ NEW: Student Join Game Logic
  Future<void> _joinLiveGame() async {
    String? code = await _showInputDialog("Join Game", "Enter Game PIN");
    if (code == null || code.isEmpty) return;

    String? name = await _showInputDialog("Your Name", "Enter your nickname");
    if (name == null || name.isEmpty) return;

    // Call API to join
    var response = await http.post(
      Uri.parse('$baseUrl/join-game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'name': name}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (!mounted) return;
      // Send student to the Multiplayer Game Screen
      Navigator.push(context, MaterialPageRoute(builder: (_) => 
        MultiplayerQuizScreen(quizData: data['quiz_data'], gameCode: code.toUpperCase(), playerName: name)
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Game PIN!")));
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E), 
      appBar: AppBar(title: const Text("My Library"), backgroundColor: const Color(0xFF1E1E2E), elevation: 0),
      
      // ✅ NEW: Floating Action Button for Students to Join Games
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinLiveGame,
        icon: const Icon(Icons.sports_esports),
        label: const Text("Join Live Quiz", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.2,
                ),
                itemCount: _notebooks.length + 1, 
                itemBuilder: (context, index) {
                  if (index == 0) return _buildAddButton();
                  return _buildNotebookCard(_notebooks[index - 1]);
                },
              ),
            ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _createNotebook,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 40, color: Color(0xFF6C63FF)),
            SizedBox(height: 10),
            Text("New Notebook", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookCard(dynamic notebook) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF464196)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(notebook['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${(notebook['sources'] ?? []).length} Sources", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                // ✅ NEW: Delete Button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white54, size: 20),
                  onPressed: () => _deleteNotebook(notebook['id']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}