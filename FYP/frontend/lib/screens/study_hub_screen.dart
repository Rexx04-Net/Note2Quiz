import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../widgets/flashcard_view.dart';
import 'arena_screen.dart';

const String baseUrl = 'http://127.0.0.1:5000';

class StudyHubScreen extends StatefulWidget {
  final String notes;
  final String youtubeUrl;
  final PlatformFile? file;
  const StudyHubScreen({super.key, required this.notes, required this.youtubeUrl, this.file});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  int _currentTab = 0; 
  String _generatedNotes = "Loading AI Notes...";
  bool _loadingNotes = true;
  
  bool _loadingQuiz = false;
  String _quizDifficulty = "Standard";

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<http.MultipartRequest> _createRequest(String endpoint) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$endpoint'));
    request.fields['notes'] = widget.notes;
    request.fields['youtube_url'] = widget.youtubeUrl;
    if (widget.file != null) {
      if (kIsWeb && widget.file!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', widget.file!.bytes!, filename: widget.file!.name));
      } else if (widget.file!.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', widget.file!.path!));
      }
    }
    return request;
  }

  Future<void> _fetchNotes() async {
    try {
      var request = await _createRequest('generate-notes');
      var response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        setState(() => _generatedNotes = jsonDecode(response.body)['notes']);
      } else {
        // ✅ FIX: Show the ACTUAL error from the server
        final errorData = jsonDecode(response.body);
        setState(() => _generatedNotes = "Failed: ${errorData['error'] ?? 'Unknown Server Error'}");
      }
    } catch (e) {
      setState(() => _generatedNotes = "Connection Error: Is the backend running?\n\nDetails: $e");
    } finally {
      setState(() => _loadingNotes = false);
    }
  }

  Future<void> _startQuiz() async {
    setState(() => _loadingQuiz = true);
    try {
      var request = await _createRequest('generate-quiz');
      request.fields['difficulty'] = _quizDifficulty;
      var response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        final quizData = jsonDecode(response.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ArenaScreen(battleData: quizData)),
          );
        }
      } else {
        // ✅ FIX: Show error popup if quiz fails
        final errorMsg = jsonDecode(response.body)['error'] ?? "Server Error";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Quiz Error: $errorMsg"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _loadingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Study Hub"), elevation: 0, backgroundColor: Colors.transparent),
      body: Row(
        children: [
          Container(
            width: 80,
            color: Colors.black26,
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildNavIcon(0, Icons.article, "Notes"),
                const SizedBox(height: 20),
                _buildNavIcon(1, Icons.style, "Cards"),
                const SizedBox(height: 20),
                _buildNavIcon(2, Icons.sports_esports, "Quiz"),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    bool selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10))
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_currentTab == 0) return _buildNotesView();
    if (_currentTab == 1) return FlashcardView(createRequest: _createRequest);
    return _buildQuizSetupView();
  }

  Widget _buildNotesView() {
    if (_loadingNotes) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI Generated Notes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Divider(),
          const SizedBox(height: 10),
          Text(_generatedNotes, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildQuizSetupView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text("Battle Arena", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            const Text("Choose Difficulty:", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionBtn("Easy", (val) => _quizDifficulty = val, _quizDifficulty == "Easy"),
                const SizedBox(width: 10),
                _buildOptionBtn("Standard", (val) => _quizDifficulty = val, _quizDifficulty == "Standard"),
                const SizedBox(width: 10),
                _buildOptionBtn("Hard", (val) => _quizDifficulty = val, _quizDifficulty == "Hard"),
              ],
            ),
            const SizedBox(height: 40),
            _loadingQuiz 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _startQuiz,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    child: const Text("ENTER ARENA"),
                  ),
                )
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn(String label, Function(String) onTap, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => onTap(label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}