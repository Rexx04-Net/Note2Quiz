import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'study_hub_screen.dart';
import '../config.dart';

const String baseUrl = 'https://countryfied-dario-addictively.ngrok-free.dev';

class NoteEditorScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic>? existingRecord; // Null if new note

  const NoteEditorScreen({super.key, required this.userEmail, this.existingRecord});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _urlController;
  
  bool _isVideoMode = false;
  bool _isLoading = false;
  bool _isPinned = false;
  String? _recordId;

  @override
  void initState() {
    super.initState();
    // Initialize from existing record or defaults
    _titleController = TextEditingController(text: widget.existingRecord?['title'] ?? "New Study Session");
    _contentController = TextEditingController(text: widget.existingRecord?['content'] ?? "");
    _urlController = TextEditingController(text: widget.existingRecord?['youtubeUrl'] ?? "");
    _isVideoMode = widget.existingRecord?['type'] == 'video';
    _isPinned = widget.existingRecord?['isPinned'] ?? false;
    _recordId = widget.existingRecord?['id'];
  }

  // --- ACTIONS ---

  Future<void> _fetchTranscript() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-transcript'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _contentController.text = data['transcript'];
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Transcript imported!")));
      } else {
        throw "Failed to fetch captions.";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecord() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/save-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.userEmail,
          'id': _recordId,
          'title': _titleController.text,
          'content': _contentController.text,
          'youtubeUrl': _urlController.text,
          'type': _isVideoMode ? 'video' : 'text',
          'isPinned': _isPinned
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recordId = data['record']['id'];
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Saved successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateStudyHub() async {
    // Save first before generating
    await _saveRecord();

    if (!mounted) return;
    
    // Proceed to revision
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyHubScreen(
          notes: _contentController.text,
          youtubeUrl: _urlController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(border: InputBorder.none, hintText: "Title..."),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          // Pin Toggle
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: _isPinned ? Colors.blue : Colors.grey),
            onPressed: () => setState(() => _isPinned = !_isPinned),
            tooltip: "Pin Note",
          ),
          
          // Mode Toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                _buildToggleBtn("Text", false),
                _buildToggleBtn("Video", true),
              ],
            ),
          ),
          
          // Save Button (Remain Now)
          IconButton(
            onPressed: _isLoading ? null : _saveRecord,
            icon: const Icon(Icons.save, color: Colors.grey),
            tooltip: "Save Changes",
          ),

          // Generate AI (Revision)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton.icon(
              onPressed: _generateStudyHub,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text("Revision Mode"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_isVideoMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[100]!)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.youtube_searched_for, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(hintText: "Paste YouTube Link...", border: InputBorder.none),
                            ),
                          ),
                          IconButton(onPressed: _fetchTranscript, icon: const Icon(Icons.download_rounded, color: Colors.red))
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!)
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: _isVideoMode ? "Transcript appears here..." : "Start typing your notes...",
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isVideo) {
    bool isSelected = _isVideoMode == isVideo;
    return GestureDetector(
      onTap: () => setState(() => _isVideoMode = isVideo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isVideo ? Colors.red[50] : Colors.blue[50]) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black87 : Colors.grey[600],
          fontSize: 12
        )),
      ),
    );
  }
}