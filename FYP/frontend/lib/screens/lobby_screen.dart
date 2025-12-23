import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../data/level_data.dart';
import 'teacher_dashboard.dart';
import 'study_hub_screen.dart';
import 'arena_screen.dart';
import 'revision_screen.dart';
import 'home_screen.dart'; 
import '../widgets/loading_overlay.dart';
import 'note_editor_screen.dart';
import 'login_screen.dart';
import '../config.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class LobbyScreen extends StatefulWidget {
  final String? userEmail; // Nullable for Guest Mode
  const LobbyScreen({super.key, this.userEmail});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // Input State
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _homeInputController = TextEditingController();

  PlatformFile? _selectedFile;
  int _selectedInputTab = 0;
  int _mainTab = 0; 
  bool _isLoading = false;
  
  // Records State
  List<dynamic> _records = [];
  bool _loadingRecords = false;
  
  // Theme State
  bool _isDarkMode = false; // Default to Light Mode as requested

  List<GameLevel> _levels = generateLevels();

  @override
  void initState() {
    super.initState();
    if (widget.userEmail != null) {
      _fetchRecords();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _youtubeController.dispose();
    _gameCodeController.dispose();
    _studentNameController.dispose();
    _homeInputController.dispose();
    super.dispose();
  }

  // --- RECORD MANAGEMENT ---
  Future<void> _fetchRecords() async {
    if (widget.userEmail == null) return;
    setState(() => _loadingRecords = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-records'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail}),
      );
      if (response.statusCode == 200) {
        setState(() => _records = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching records: $e");
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  // --- NAVIGATION & MENU ---
  void _login() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (context) => const LobbyScreen(userEmail: null)),
      (route) => false
    );
  }

  void _showUserMenu(bool isGuest) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF2D2B42) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              // User Info
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isGuest ? Colors.grey : const Color(0xFF6C63FF),
                  child: Icon(isGuest ? Icons.person : Icons.check, color: Colors.white),
                ),
                title: Text(isGuest ? "Guest User" : (widget.userEmail ?? "User"), 
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                subtitle: Text(isGuest ? "Sign in to save history" : "Logged in", 
                  style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.grey)),
              ),
              const Divider(),
              // Theme Toggle
              SwitchListTile(
                title: Text("Dark Mode", style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87)),
                secondary: Icon(Icons.dark_mode, color: _isDarkMode ? Colors.white : Colors.grey),
                value: _isDarkMode,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (val) {
                  setState(() => _isDarkMode = val);
                  Navigator.pop(context); // Close menu to apply/refresh
                },
              ),
              const Divider(),
              // Action (Login/Logout)
              ListTile(
                leading: Icon(isGuest ? Icons.login : Icons.logout, color: isGuest ? Colors.green : Colors.redAccent),
                title: Text(isGuest ? "Log In" : "Log Out", 
                  style: TextStyle(color: isGuest ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  isGuest ? _login() : _logout();
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _openNoteEditor([Map<String, dynamic>? record]) async {
    if (record != null && widget.userEmail == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          userEmail: widget.userEmail ?? "guest",
          existingRecord: record,
        ),
      ),
    );
    if (widget.userEmail != null) _fetchRecords(); 
  }

  Future<void> _pickFile() async {
    try {
      var result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'pptx']);
      if (result != null) setState(() => _selectedFile = result.files.first);
    } catch (e) { /* Ignore */ }
  }

  Future<void> _startStudy() async {
    String notes = "";
    String youtube = "";
    if (_mainTab == 0) {
       if (_selectedInputTab == 2) notes = _homeInputController.text.trim();
       if (_selectedInputTab == 1) youtube = _homeInputController.text.trim();
    } else {
       if (_selectedInputTab == 2) notes = _notesController.text.trim();
       if (_selectedInputTab == 1) youtube = _youtubeController.text.trim();
    }
    if (_selectedInputTab == 0 && _selectedFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a file first!"))); return;
    }
    if (_selectedInputTab == 1 && youtube.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please paste a YouTube link!"))); return;
    }
    if (_selectedInputTab == 2 && notes.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter some notes!"))); return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => StudyHubScreen(notes: notes, youtubeUrl: youtube, file: _selectedFile)));
    }
  }
  
  Future<void> _hostGame() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/host-game'));
      if (_selectedInputTab == 2) request.fields['notes'] = _notesController.text.trim();
      if (_selectedInputTab == 1) request.fields['youtube_url'] = _youtubeController.text.trim();
      if (_selectedInputTab == 0 && _selectedFile != null) {
         if (_selectedFile!.bytes != null) {
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

  Future<void> _startLevel(GameLevel level) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/generate-notes'));
      
      String prompt = "Create a concise, bullet-point revision summary about: ${level.topic}. Focus on key facts relevant for a quiz.";
      request.fields['notes'] = prompt;

      var response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notes = data['notes'];
        
        if (mounted) {
          final bool? victory = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => RevisionScreen(
              topic: level.topic,
              notes: notes,
              level: level.level,
              isBoss: level.isBoss,
            ))
          );

          if (victory == true) {
             if (level.level < _levels.length) {
               setState(() {
                 int nextLevelIndex = level.level; 
                 if (nextLevelIndex < _levels.length) {
                    var old = _levels[nextLevelIndex];
                    _levels[nextLevelIndex] = GameLevel(
                      level: old.level,
                      topic: old.topic,
                      isBoss: old.isBoss,
                      isLocked: false 
                    );
                 }
               });
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Level Complete! Next level unlocked!"), backgroundColor: Colors.green));
             } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CONGRATULATIONS! YOU FINISHED ALL LEVELS!"), backgroundColor: Colors.amber));
             }
          }
        }
      } else {
        throw "Failed to generate revision notes.";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Level Error: $e"), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  String _getHeaderTitle() {
    switch (_mainTab) {
      case 0: return "AI Study Hub";
      case 1: return "AI Note Taker";
      case 2: return "AI Flashcard Maker";
      case 3: return "AI Quiz Generator";
      case 4: return "Challenge Map";
      case 5: return "Teacher Host";
      case 6: return "Join Live Game";
      default: return "Note2Quiz";
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isGuest = widget.userEmail == null;
    Color bgColor = _isDarkMode ? const Color(0xFF1E1E2E) : const Color(0xFFF5F6FA);
    Color cardColor = _isDarkMode ? const Color(0xFF2D2B42) : Colors.white;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;
    Color subTextColor = _isDarkMode ? Colors.white54 : Colors.grey[600]!;
    
    // Sidebar colors dependent on Theme
    Color sidebarColor = _isDarkMode ? const Color(0xFF171717) : const Color(0xFFF9F9F9);
    Color sidebarTextColor = _isDarkMode ? Colors.white : Colors.black87;
    Color sidebarIconColor = _isDarkMode ? Colors.white : Colors.black54;
    Color sidebarDividerColor = _isDarkMode ? Colors.white12 : Colors.black12;
    Color sidebarHoverColor = _isDarkMode ? Colors.white10 : Colors.black12;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor, 
          body: Row(
            children: [
              // --- SIDEBAR (Adapts to Theme) ---
              Container(
                width: 260,
                color: sidebarColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openNoteEditor(),
                          icon: Icon(Icons.add, size: 16, color: sidebarTextColor),
                          label: Text("New chat", style: TextStyle(color: sidebarTextColor)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.black12),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                          ),
                        ),
                      ),
                    ),

                    _buildSidebarItem(Icons.home, "Home", 0, sidebarTextColor, sidebarIconColor, sidebarHoverColor),
                    _buildSidebarItem(Icons.map, "Challenge Map", 4, sidebarTextColor, sidebarIconColor, sidebarHoverColor),
                    
                    Divider(color: sidebarDividerColor),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("History", style: TextStyle(color: sidebarIconColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                if (!isGuest)
                                  InkWell(onTap: _fetchRecords, child: Icon(Icons.refresh, size: 14, color: sidebarIconColor))
                              ],
                            ),
                          ),
                          Expanded(
                            child: isGuest 
                              ? Padding(padding: const EdgeInsets.all(20.0), child: Text("Sign in to save your history.", style: TextStyle(color: sidebarIconColor.withOpacity(0.5), fontSize: 13)))
                              : _loadingRecords 
                                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: sidebarIconColor))
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _records.length,
                                    itemBuilder: (context, index) {
                                      final r = _records[index];
                                      return InkWell(
                                        onTap: () => _openNoteEditor(r),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(children: [
                                              Icon(Icons.chat_bubble_outline, size: 14, color: sidebarIconColor),
                                              const SizedBox(width: 10),
                                              Expanded(child: Text(r['title'] ?? "Untitled", style: TextStyle(color: sidebarTextColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          ]),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: sidebarDividerColor),

                    // 4. Bottom User Profile (Click for Settings)
                    InkWell(
                      onTap: () => _showUserMenu(isGuest),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isGuest ? Colors.grey : const Color(0xFF6C63FF),
                              child: Icon(isGuest ? Icons.person : Icons.check, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isGuest ? "Guest (Settings)" : (widget.userEmail ?? "User"),
                                style: TextStyle(color: sidebarTextColor, fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.more_horiz, color: sidebarIconColor, size: 18)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- MAIN CONTENT AREA ---
              Expanded(
                child: _mainTab == 0 
                ? HomeScreen(
                    inputController: _homeInputController, 
                    selectedFile: _selectedFile,
                    onPickFile: _pickFile,
                    onStartNoteTaker: () => _switchToTab(1),
                    onStartFlashcards: () => _switchToTab(2),
                    onStartQuiz: () => _switchToTab(3),
                    onStartChallenge: () => _switchToTab(4),
                    onGenerate: (type) {
                       setState(() {
                         _selectedInputTab = type;
                         if (type == 0) _pickFile(); 
                         else _startStudy();
                       });
                    },
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Center(
                          child: Text(_getHeaderTitle(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                         ),
                         const SizedBox(height: 40),
                         if (_mainTab == 4) _buildChallengeMap(cardColor, textColor)
                         else if (_mainTab == 6) _buildStudentJoinCard(cardColor, textColor, subTextColor)
                         else if (_mainTab == 5) Container(child: Text("Teacher Dashboard Triggered via Host Game", style: TextStyle(color: textColor))) 
                         else _buildGeneratorCard(cardColor, textColor, subTextColor),
                      ],
                    ),
                  ),
              )
            ],
          ),
        ),
        if (_isLoading) const LoadingOverlay()
      ],
    );
  }

  // --- HELPER UI ---
  void _switchToTab(int index) => setState(() => _mainTab = index);

  Widget _buildSidebarItem(IconData icon, String label, int index, Color textColor, Color iconColor, Color hoverColor) {
    bool isActive = _mainTab == index;
    return InkWell(
      onTap: () => setState(() => _mainTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: isActive ? hoverColor : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textColor, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildChallengeMap(Color cardColor, Color textColor) {
    return Center(
      child: Wrap(
        spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
        children: _levels.map((level) => _buildLevelCard(level, cardColor, textColor)).toList(),
      ),
    );
  }

  Widget _buildLevelCard(GameLevel level, Color cardColor, Color textColor) {
    return Container(
      width: 140, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
      child: Column(
        children: [
          Icon(level.isLocked ? Icons.lock : Icons.star, color: level.isLocked ? Colors.grey : Colors.amber, size: 30),
          const SizedBox(height: 10),
          Text("Level ${level.level}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: level.isLocked ? null : () => _startLevel(level), child: const Text("Play", style: TextStyle(fontSize: 10)))
        ],
      ),
    );
  }

  Widget _buildGeneratorCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
      child: Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
              _buildInputTab("Upload", 0, textColor),
              _buildInputTab("YouTube", 1, textColor),
              _buildInputTab("Text", 2, textColor),
          ]),
          const SizedBox(height: 30),
          if (_selectedInputTab == 1)
             TextField(controller: _youtubeController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "YouTube Link", border: const OutlineInputBorder(), hintStyle: TextStyle(color: subTextColor))),
          if (_selectedInputTab == 2)
             TextField(controller: _notesController, maxLines: 5, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Notes", border: const OutlineInputBorder(), hintStyle: TextStyle(color: subTextColor))),
          if (_selectedInputTab == 0)
             ElevatedButton(onPressed: _pickFile, child: Text(_selectedFile?.name ?? "Upload File")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startStudy, 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
            child: const Text("Generate")
          )
        ],
      ),
    );
  }

  Widget _buildStudentJoinCard(Color cardColor, Color textColor, Color subTextColor) {
     return Container(
       padding: const EdgeInsets.all(30),
       decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
       child: Column(children: [
         TextField(controller: _gameCodeController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Game Code", hintStyle: TextStyle(color: subTextColor))),
         const SizedBox(height: 10),
         TextField(controller: _studentNameController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Name", hintStyle: TextStyle(color: subTextColor))),
         const SizedBox(height: 20),
         ElevatedButton(onPressed: _joinGame, child: const Text("Join"))
       ]),
     );
  }

  Widget _buildInputTab(String label, int index, Color textColor) {
    bool isSelected = _selectedInputTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedInputTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent, 
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.5))
        ),
        child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : textColor)),
      ),
    );
  }
}