import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'quiz_screen.dart';
import 'teacher_leaderboard_screen.dart';
import '../widgets/flashcard_view.dart';
import '../widgets/loading_overlay.dart';

class NotebookScreen extends StatefulWidget {
  final Map<String, dynamic> notebook;
  const NotebookScreen({super.key, required this.notebook});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  String _selectedTool = 'overview';
  bool _isLoading = false;
  dynamic _generatedData;
  List<dynamic> _sources = [];
  String _selectedDifficulty = 'Standard';

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  void _loadSources() {
    setState(() {
      _sources = widget.notebook['sources'] ?? [];
    });
  }

  Future<void> _uploadSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx'],
      withData: true,
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    final uri = Uri.parse('$baseUrl/add-source');
    final request = http.MultipartRequest('POST', uri);
    request.fields['notebook_id'] = widget.notebook['id'];
    request.fields['type'] = 'file';

    final file = result.files.first;
    if (kIsWeb || file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final newSource = jsonDecode(respStr);
        setState(() {
          _sources.add(newSource);
          _selectedTool = 'overview';
        });
      } else {
        _showError('Failed to upload source');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateContent(String toolType) async {
    if (_sources.isEmpty) {
      _showError('Add at least one source first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedTool = toolType;
      _generatedData = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-studio-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'tool_type': toolType,
          'difficulty': _selectedDifficulty,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() => _generatedData = jsonResponse['data']);
      } else {
        setState(() => _generatedData = 'Error: Server returned ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _generatedData = 'Connection Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hostLiveGame(List<dynamic> quizData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/host-game'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'quiz_data': quizData,
          'email': widget.notebook['user_email'] ?? 'teacher',
        }),
      );

      if (response.statusCode == 200) {
        final code = jsonDecode(response.body)['code'];
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeacherLeaderboardScreen(gameCode: code)),
        );
      } else {
        _showError('Failed to create game room.');
      }
    } catch (e) {
      _showError('Connection Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A),
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.notebook['title'] ?? 'Notebook'),
            const SizedBox(height: 2),
            Text(
              '${_sources.length} source${_sources.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDifficulty,
                dropdownColor: const Color(0xFF232334),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedDifficulty = value);
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              _buildSourcesRail(),
              Expanded(child: _buildMainContent()),
              _buildActionRail(),
            ],
          ),
          if (_isLoading) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildSourcesRail() {
    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sources',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload notes, slides, or study material',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _uploadSource,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Add source'),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _sources.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description_outlined, color: Colors.white38),
                        SizedBox(height: 12),
                        Text(
                          'No sources yet',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a PDF or PPTX to generate quizzes, flashcards, mind maps, and summaries.',
                          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _sources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final source = _sources[index];
                      final text = (source['content'] ?? '').toString();
                      final preview = text.length > 90 ? '${text.substring(0, 90)}...' : text;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF9C96FF), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    source['title'] ?? 'Untitled source',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              preview.isEmpty ? 'Source imported successfully.' : preview,
                              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRail() {
    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(12, 12, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study actions',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Move from understanding to active practice',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          _buildStageLabel('Understand'),
          const SizedBox(height: 10),
          _buildStudioBtn('Briefing Doc', 'Generate summary report', Icons.description_outlined, 'report'),
          const SizedBox(height: 12),
          _buildStudioBtn('Mind Map', 'Visualize key connections', Icons.account_tree_outlined, 'mindmap'),
          const SizedBox(height: 18),
          _buildStageLabel('Practice'),
          const SizedBox(height: 10),
          _buildStudioBtn('Quiz', 'Test your knowledge', Icons.quiz_outlined, 'quiz'),
          const SizedBox(height: 12),
          _buildStudioBtn('Flashcards', 'Review key concepts fast', Icons.style_outlined, 'flashcard'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why Note2Quiz feels different',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This workspace turns notes into practice. Generate solo quizzes or launch live classroom challenges from the same material.',
                  style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161621),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildCenterContent(),
      ),
    );
  }

  Widget _buildCenterContent() {
    if (_selectedTool == 'quiz' && _generatedData is List) {
      return _buildQuizReadyState(_generatedData as List<dynamic>);
    }

    if (_selectedTool == 'flashcard' && _generatedData is List) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: FlashcardView(flashcards: _generatedData),
      );
    }

    if (_generatedData != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedTool.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                letterSpacing: 1.2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _generatedData.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.7),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 44, color: Color(0xFF9C96FF)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Turn notes into mastery',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upload your study material, then generate summaries, flashcards, quizzes, and live classroom challenges in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _uploadSource,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload first source'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to study',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'You have ${_sources.length} source${_sources.length == 1 ? '' : 's'} uploaded. Choose how you want to learn next.',
            style: const TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.35,
              children: [
                _buildFeatureCard(
                  title: 'Understand faster',
                  subtitle: 'Generate a briefing doc or mind map to capture the main ideas quickly.',
                  icon: Icons.psychology_alt_outlined,
                  onTap: () => _generateContent('report'),
                ),
                _buildFeatureCard(
                  title: 'Practice smarter',
                  subtitle: 'Create a quiz based on your uploaded content and difficulty level.',
                  icon: Icons.quiz_outlined,
                  onTap: () => _generateContent('quiz'),
                ),
                _buildFeatureCard(
                  title: 'Memorize key points',
                  subtitle: 'Use flashcards for quick review sessions before exams or class.',
                  icon: Icons.style_outlined,
                  onTap: () => _generateContent('flashcard'),
                ),
                _buildFeatureCard(
                  title: 'Go live in class',
                  subtitle: 'Generate a quiz and launch a multiplayer challenge for students.',
                  icon: Icons.groups_rounded,
                  onTap: () => _generateContent('quiz'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuizReadyState(List<dynamic> quizData) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.task_alt_rounded, color: Colors.greenAccent, size: 52),
              ),
              const SizedBox(height: 22),
              const Text(
                'Quiz generated successfully',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${quizData.length} questions are ready. Use it for solo practice or turn it into a live classroom game.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _actionPill(Icons.bolt_rounded, _selectedDifficulty),
                  _actionPill(Icons.help_outline_rounded, '${quizData.length} questions'),
                  _actionPill(Icons.menu_book_outlined, '${_sources.length} sources'),
                ],
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => QuizScreen(quizData: quizData)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Play solo mode'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _hostLiveGame(quizData),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Host live multiplayer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D2B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF9C96FF)),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
              const Spacer(),
              const Row(
                children: [
                  Text('Open', style: TextStyle(color: Color(0xFFB8B3FF), fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFFB8B3FF)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioBtn(String title, String subtitle, IconData icon, String type) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _generateContent(type),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _selectedTool == type ? const Color(0xFF26263A) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _selectedTool == type ? const Color(0xFF6C63FF) : Colors.white10,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF9C96FF), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _actionPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}