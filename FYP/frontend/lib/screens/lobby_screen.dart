import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'teacher_dashboard.dart';
import 'study_hub_screen.dart';
import 'arena_screen.dart';

const String baseUrl = 'http://127.0.0.1:5000';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // Shared Inputs
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  PlatformFile? _selectedFile;
  int _inputType = 0; // 0=File, 1=YouTube, 2=Text

  // Student Inputs
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      var result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'pptx']);
      if (result != null) setState(() => _selectedFile = result.files.first);
    } catch (e) { /* Ignore */ }
  }

  // --- ACTION 1: SELF STUDY ---
  Future<void> _startSelfStudy() async {
    String notesToSend = "";
    String youtubeUrlToSend = "";
    PlatformFile? fileToSend;

    // Only take data from the ACTIVE tab
    if (_inputType == 2) notesToSend = _notesController.text.trim();
    if (_inputType == 1) youtubeUrlToSend = _youtubeController.text.trim();
    if (_inputType == 0) fileToSend = _selectedFile;

    // Navigate directly, passing data. StudyHub handles generation.
    Navigator.push(context, MaterialPageRoute(builder: (context) => StudyHubScreen(
      notes: notesToSend,
      youtubeUrl: youtubeUrlToSend,
      file: fileToSend,
    )));
  }

  // --- ACTION 2: TEACHER HOST ---
  Future<void> _hostGame() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/host-game'));
      
      // Add data based on input type
      if (_inputType == 2) request.fields['notes'] = _notesController.text.trim();
      if (_inputType == 1) request.fields['youtube_url'] = _youtubeController.text.trim();
      if (_inputType == 0 && _selectedFile != null) {
        if (kIsWeb && _selectedFile!.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', _selectedFile!.bytes!, filename: _selectedFile!.name));
        } else if (_selectedFile!.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', _selectedFile!.path!));
        }
      }

      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherDashboard(gameCode: data['code'])));
      } else {
        throw jsonDecode(response.body)['error'] ?? "Server Error";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  // --- ACTION 3: STUDENT JOIN ---
  Future<void> _joinGame() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/join-game'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({ 'code': _gameCodeController.text.trim(), 'name': _studentNameController.text.trim() })
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ArenaScreen(
          battleData: data['quiz'],
          multiplayerCode: _gameCodeController.text.trim(),
          playerName: _studentNameController.text.trim(),
        )));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code!"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error"), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("NOTE 2 QUIZ"),
          bottom: const TabBar(tabs: [
            Tab(text: "SELF STUDY", icon: Icon(Icons.school)),
            Tab(text: "TEACHER", icon: Icon(Icons.cast_for_education)),
            Tab(text: "STUDENT", icon: Icon(Icons.group_add)),
          ]),
        ),
        body: TabBarView(
          children: [
            // TAB 1: SELF STUDY (Uses Shared Input UI)
            _buildInputLayout(
              title: "Start Your Revision",
              buttonText: "GENERATE STUDY HUB",
              onPressed: _startSelfStudy,
              color: const Color(0xFF6C63FF),
            ),

            // TAB 2: TEACHER HOST (Uses Shared Input UI)
            _buildInputLayout(
              title: "Host a Live Game",
              buttonText: "GENERATE & HOST",
              onPressed: _hostGame,
              color: Colors.orangeAccent,
            ),

            // TAB 3: STUDENT JOIN
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("JOIN GAME", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    TextField(controller: _gameCodeController, decoration: const InputDecoration(labelText: "Game Code (e.g. A1B2)", border: OutlineInputBorder())),
                    const SizedBox(height: 20),
                    TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: "Your Nickname", border: OutlineInputBorder())),
                    const SizedBox(height: 30),
                    _isLoading ? const CircularProgressIndicator() : SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(onPressed: _joinGame, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("ENTER ARENA")),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE INPUT WIDGET (For Self Study & Teacher) ---
  Widget _buildInputLayout({required String title, required String buttonText, required VoidCallback onPressed, required Color color}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Input Type Tabs
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildInputTypeBtn(0, Icons.cloud_upload, "File"),
              const SizedBox(width: 10),
              _buildInputTypeBtn(1, Icons.video_library, "YouTube"),
              const SizedBox(width: 10),
              _buildInputTypeBtn(2, Icons.text_fields, "Text"),
            ]),
            const SizedBox(height: 20),

            // Input Area
            Container(
              height: 200, // Increased height for better spacing
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
              child: _inputType == 0 
                ? GestureDetector(onTap: _pickFile, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_selectedFile == null ? Icons.upload_file : Icons.check_circle, size: 40, color: _selectedFile == null ? Colors.white54 : Colors.green), const SizedBox(height: 10), Text(_selectedFile?.name ?? "Click to Upload PDF/PPTX")])))
                : _inputType == 1 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextField(controller: _youtubeController, decoration: const InputDecoration(hintText: "Paste YouTube Link", prefixIcon: Icon(Icons.link))),
                          const SizedBox(height: 10),
                          const Text(
                            "Note: Video MUST have closed captions enabled to extract text.", 
                            style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)
                          ),
                        ],
                      ),
                    )
                  : TextField(controller: _notesController, maxLines: 6, decoration: const InputDecoration(hintText: "Paste Notes Here", border: InputBorder.none)),
            ),
            const SizedBox(height: 30),

            _isLoading ? const CircularProgressIndicator() : SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt),
                label: Text(buttonText),
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputTypeBtn(int index, IconData icon, String label) {
    bool selected = _inputType == index;
    return InkWell(
      onTap: () => setState(() => _inputType = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: selected ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Row(children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)]),
      ),
    );
  }
}