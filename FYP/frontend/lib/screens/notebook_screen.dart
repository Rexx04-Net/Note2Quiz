import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'automation_setup_screen.dart';
import 'automation_history_screen.dart';
import 'quiz_screen.dart';
import 'quiz_review_screen.dart';
import 'settings_screen.dart';
import 'study_plan_screen.dart';
import 'teacher_leaderboard_screen.dart';

import '../widgets/flashcard_view.dart';
import '../widgets/interactive_mindmap_viewer.dart';
import '../widgets/interactive_note_viewer.dart';
import '../widgets/loading_overlay.dart';
import '../state/app_settings_controller.dart';
import '../theme/app_theme.dart';

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
  Set<String> _selectedSourceIds = {};
  String _selectedDifficulty = 'Standard';
  bool _isStreaming = false;
  int _mistakesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSources();
    _fetchMistakesCount();
  }

  Future<void> _fetchMistakesCount() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/get-notebook-mistakes?notebook_id=${widget.notebook['id']}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _mistakesCount = (data['mistakes_count'] ?? 0) as int;
          });
        }
      }
    } catch (_) {}
  }

  void _loadSources() {
    setState(() {
      _sources = widget.notebook['sources'] ?? [];
      _selectedSourceIds = _sources.map((s) => (s['id'] ?? s['title'] ?? '').toString()).toSet();
    });
  }

  Future<void> _uploadSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'ppt', 'docx', 'txt'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);

    int successCount = 0;
    for (final file in result.files) {
      final uri = Uri.parse('$baseUrl/add-source');
      final request = http.MultipartRequest('POST', uri);
      request.fields['notebook_id'] = widget.notebook['id'];
      request.fields['type'] = 'file';

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
            _selectedSourceIds.add((newSource['id'] ?? newSource['title'] ?? '').toString());
            _selectedTool = 'overview';
          });
          successCount++;
        }
      } catch (e) {
        debugPrint('Error uploading ${file.name}: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);

    if (successCount == 0) {
      _showError('Failed to upload selected source file(s)');
    }
  }

  void _showAddSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Study Source',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to add lecture material',
                style: TextStyle(color: context.appColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file, color: Colors.blue),
                ),
                title: const Text('Upload Files (PDF / PPTX)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Select one or multiple lecture slides or notes'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadSource();
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_fill, color: Colors.red),
                ),
                title: const Text('Add YouTube Video Link', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Automatically extract transcripts from YouTube videos'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddUrlDialog('youtube');
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language, color: Colors.green),
                ),
                title: const Text('Add Web Article Link', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Import content directly from online articles & pages'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddUrlDialog('link');
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.purple),
                ),
                title: const Text('Paste Text / Raw Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Directly type or paste lecture text'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddUrlDialog('text');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddUrlDialog(String type) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    String dialogTitle = type == 'youtube'
        ? 'Add YouTube Video'
        : type == 'link'
            ? 'Add Web Article Link'
            : 'Add Text Note';

    String hintText = type == 'youtube'
        ? 'Paste YouTube Video URL (e.g. https://www.youtube.com/watch?v=...)'
        : type == 'link'
            ? 'Paste Web Article URL (e.g. https://example.com/article)'
            : 'Paste raw text or notes here...';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Source Title (Optional)',
                  hintText: type == 'youtube' ? 'e.g. Lecture 1 Video' : 'e.g. Unit 3 Article',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentController,
                maxLines: type == 'text' ? 5 : 2,
                decoration: InputDecoration(
                  labelText: type == 'text' ? 'Content' : 'URL Link',
                  hintText: hintText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final input = contentController.text.trim();
                if (input.isEmpty) return;
                Navigator.pop(context);
                _submitUrlSource(type, input, titleController.text.trim());
              },
              child: const Text('Add Source'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUrlSource(String type, String content, String title) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-source'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'type': type,
          'content': content,
          if (title.isNotEmpty) 'title': title,
        }),
      );

      if (response.statusCode == 200) {
        final newSource = jsonDecode(response.body);
        setState(() {
          _sources.add(newSource);
          _selectedTool = 'overview';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully added source: ${newSource['title']}')),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        _showError(err['error'] ?? 'Failed to add source');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteSource(String? sourceId, String title) async {
    if (sourceId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Source', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteSource(sourceId);
    }
  }

  Future<void> _deleteSource(String sourceId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete-source'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'source_id': sourceId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _sources.removeWhere((s) => s['id'] == sourceId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Source deleted successfully')),
          );
        }
      } else {
        _showError('Failed to delete source');
      }
    } catch (e) {
      _showError('Error deleting source: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateContent(String toolType) async {
    if (_sources.isEmpty) {
      _showError('Add at least one source first.');
      return;
    }

    final settings = AppSettingsScope.of(context);
    final selectedList = _selectedSourceIds.isNotEmpty
        ? _selectedSourceIds.toList()
        : _sources.map((s) => (s['id'] ?? s['title'] ?? '').toString()).toList();

    // Stream textual items (e.g. Briefing Doc) in real-time via SSE
    if (toolType == 'report') {
      setState(() {
        _isLoading = false;
        _isStreaming = true;
        _selectedTool = toolType;
        _generatedData = '';
      });

      try {
        final client = http.Client();
        final request = http.Request('POST', Uri.parse('$baseUrl/stream-studio-item'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'notebook_id': widget.notebook['id'],
            'notebook_title': widget.notebook['title'] ?? 'Notebook',
            'user_email': widget.notebook['user_email'] ?? 'guest',
            'tool_type': toolType,
            'difficulty': _selectedDifficulty,
            'output_language': settings.outputLanguage,
            'selected_source_ids': selectedList,
            'sources': _sources,
          });

        final streamedResponse = await client.send(request);
        String accumulated = '';

        streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isNotEmpty) {
                try {
                  final payload = jsonDecode(jsonStr);
                  if (payload['chunk'] != null) {
                    accumulated += payload['chunk'].toString();
                    if (mounted) {
                      setState(() {
                        _generatedData = accumulated;
                      });
                    }
                  }
                  if (payload['done'] == true) {
                    if (mounted) {
                      setState(() {
                        _isStreaming = false;
                      });
                    }
                  }
                  if (payload['error'] != null) {
                    if (mounted) {
                      setState(() {
                        _isStreaming = false;
                        _generatedData = 'Error: ${payload['error']}';
                      });
                    }
                  }
                } catch (_) {}
              }
            }
          },
          onDone: () {
            client.close();
            if (mounted) setState(() => _isStreaming = false);
          },
          onError: (err) {
            client.close();
            if (mounted) {
              setState(() {
                _isStreaming = false;
                _generatedData = 'Streaming Error: $err';
              });
            }
          },
          cancelOnError: true,
        );
        return;
      } catch (e) {
        if (mounted) {
          setState(() {
            _isStreaming = false;
            _generatedData = 'Connection Error: $e';
          });
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _isStreaming = false;
      _selectedTool = toolType;
      _generatedData = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-studio-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'notebook_title': widget.notebook['title'] ?? 'Notebook',
          'user_email': widget.notebook['user_email'] ?? 'guest',
          'tool_type': toolType,
          'difficulty': _selectedDifficulty,
          'output_language': settings.outputLanguage,
          'selected_source_ids': selectedList,
          'sources': _sources,
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

  Future<void> _launchWeaknessDrill() async {
    if (_sources.isEmpty) {
      _showError('Add at least one source first.');
      return;
    }

    final settings = AppSettingsScope.of(context);
    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/generate-weakness-drill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'output_language': settings.outputLanguage,
          'sources': _sources,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['has_mistakes'] == false) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.appColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 10),
                  Text('Mistake Bank Clear!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                data['message'] ?? 'No mistakes recorded yet! Take a standard or hard quiz first.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it!'),
                ),
              ],
            ),
          );
          return;
        }

        if (data['success'] == true && data['data'] is List) {
          final List<dynamic> drillQuestions = data['data'];
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                quizData: drillQuestions,
                notebookId: widget.notebook['id'],
                isWeaknessDrill: true,
              ),
            ),
          );
          _fetchMistakesCount();
        } else {
          _showError(data['error'] ?? 'Failed to generate weakness drill.');
        }
      } else {
        _showError('Server error: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Connection error: $e');
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

  Future<void> _showSingleNotebookRoadmapDialog() async {
    if (_sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one source file or text first.')),
      );
      return;
    }

    String durationOption = '3 Days';
    double dailyHours = 2.0;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Roadmap for ${widget.notebook['title'] ?? 'Notebook'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Select Plan Duration:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['1 Day', '3 Days', '7 Days', 'AI Automated'].map((opt) {
                      final isSelected = durationOption == opt;
                      return ChoiceChip(
                        label: Text(opt),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setModalState(() => durationOption = opt);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. Available Daily Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${dailyHours.toStringAsFixed(1)} hrs/day', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                    ],
                  ),
                  Slider(
                    value: dailyHours,
                    min: 0.5,
                    max: 8.0,
                    divisions: 15,
                    onChanged: (val) => setModalState(() => dailyHours = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateSingleRoadmap(durationOption, dailyHours);
                  },
                  child: const Text('Generate Active Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateSingleRoadmap(String durationOption, double dailyHours) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-active-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.notebook['user_email'] ?? 'guest',
          'notebook_ids': [widget.notebook['id']],
          'duration_option': durationOption,
          'daily_hours': dailyHours,
        }),
      );

      if (response.statusCode == 200) {
        final planData = jsonDecode(response.body);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPlanScreen(
              initialPlan: planData,
              userEmail: widget.notebook['user_email'] ?? 'guest',
            ),
          ),
        );
      } else {
        final err = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['error'] ?? 'Failed to generate roadmap.')),
        );
      }
    } catch (e) {
      debugPrint('Error generating single notebook roadmap: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.notebook['title'] ?? 'Notebook'),
            const SizedBox(height: 4),
            Text(
              '${_sources.length} source${_sources.length == 1 ? '' : 's'} | Output: ${settings.outputLanguage}',
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Automation History & Progress',
            onPressed: () {
              final userEmail = FirebaseAuth.instance.currentUser?.email ?? 
                  (widget.notebook['user_email'] ?? '').toString();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AutomationHistoryScreen(
                    notebookId: (widget.notebook['id'] ?? 'nb_default').toString(),
                    courseName: (widget.notebook['title'] ?? 'Course').toString(),
                    userEmail: userEmail,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history_edu, color: Colors.orangeAccent),
          ),
          IconButton(
            tooltip: 'Syllabus & Timetable Engine',
            onPressed: () {
              final userEmail = FirebaseAuth.instance.currentUser?.email ?? 
                  (widget.notebook['user_email'] ?? '').toString();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AutomationSetupScreen(
                    notebookId: (widget.notebook['id'] ?? 'nb_default').toString(),
                    initialCourseName: (widget.notebook['title'] ?? 'Course').toString(),
                    userEmail: userEmail,
                  ),
                ),
              );
            },
            icon: Icon(Icons.auto_awesome, color: scheme.primary),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    userEmail: (widget.notebook['user_email'] ?? 'guest').toString(),
                    settingsController: AppSettingsScope.of(context),
                  ),
                ),
              );
            },
            icon: Icon(Icons.settings_outlined, color: colors.mutedText),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDifficulty,
                dropdownColor: colors.surfaceAlt,
                style: TextStyle(color: scheme.onSurface),
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
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload notes, slides, or study material',
            style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showAddSourceOptions,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Add source'),
            ),
          ),
          if (_sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${_selectedSourceIds.length}/${_sources.length} selected',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_selectedSourceIds.length == _sources.length) {
                        _selectedSourceIds.clear();
                      } else {
                        _selectedSourceIds = _sources
                            .map((s) => (s['id'] ?? s['title'] ?? '').toString())
                            .toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedSourceIds.length == _sources.length ? 'Deselect all' : 'Select all',
                    style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _sources.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description_outlined, color: colors.subtleText),
                        const SizedBox(height: 12),
                        Text(
                          'No sources yet',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a PDF or PPTX to generate quizzes, flashcards, mind maps, and summaries.',
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _sources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final source = _sources[index];
                      final sId = (source['id'] ?? source['title'] ?? '').toString();
                      final isSelected = _selectedSourceIds.contains(sId);
                      final text = (source['content'] ?? '').toString();
                      final preview = text.length > 90 ? '${text.substring(0, 90)}...' : text;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSourceIds.remove(sId);
                            } else {
                              _selectedSourceIds.add(sId);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primary.withOpacity(0.08)
                                : colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary.withOpacity(0.8)
                                  : colors.border,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: scheme.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSourceIds.add(sId);
                                          } else {
                                            _selectedSourceIds.remove(sId);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      source['title'] ?? 'Untitled source',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete source',
                                    onPressed: () => _confirmDeleteSource(source['id'], source['title'] ?? 'Source'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: Text(
                                  preview.isEmpty ? 'Source imported successfully.' : preview,
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistoryModal() async {
    setState(() => _isLoading = true);
    List<dynamic> historyItems = [];
    List<dynamic> quizResults = [];
    List<dynamic> automationItems = [];

    final userEmail = FirebaseAuth.instance.currentUser?.email ??
        (widget.notebook['user_email'] ?? '').toString();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-notebook-history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebook['id'],
          'user_email': userEmail,
        }),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        historyItems = res['history'] ?? [];
        quizResults = res['quiz_results'] ?? [];
      }

      // Fetch course automations
      final autoUri = Uri.parse(
        '$baseUrl/api/automations/${widget.notebook['id']}/history?user_email=${Uri.encodeComponent(userEmail)}',
      );
      final autoResp = await http.get(autoUri);
      if (autoResp.statusCode == 200) {
        final autoData = jsonDecode(autoResp.body);
        if (autoData['all_automations'] is List && (autoData['all_automations'] as List).isNotEmpty) {
          automationItems = autoData['all_automations'];
        } else if (autoData['automation'] != null) {
          automationItems = [autoData['automation']];
        }
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 3,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Practice & History Log',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      isScrollable: true,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: context.appColors.mutedText,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(text: 'Saved Material (${historyItems.length})'),
                        Tab(text: 'Quiz Scores (${quizResults.length})'),
                        Tab(text: 'Automations & Progress (${automationItems.length})'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Saved Material Tab
                          historyItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No saved history yet. Generate a Quiz, Flashcard, Note, or Mind Map!',
                                    style: TextStyle(color: context.appColors.mutedText),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: historyItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = historyItems[index];
                                    final type = item['tool_type'] ?? 'note';
                                    final icon = type == 'quiz'
                                        ? Icons.quiz_outlined
                                        : type == 'flashcard'
                                            ? Icons.style_outlined
                                            : type == 'mindmap'
                                                ? Icons.account_tree_outlined
                                                : Icons.description_outlined;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: context.appColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.appColors.border),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                                        ),
                                        title: Text(
                                          item['title'] ?? 'Saved Item',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          item['created_at'] ?? '',
                                          style: TextStyle(color: context.appColors.mutedText, fontSize: 12),
                                        ),
                                        trailing: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             if (type == 'quiz' && item['data'] is List)
                                               IconButton(
                                                 icon: const Icon(Icons.menu_book_outlined, color: Colors.lightBlueAccent, size: 20),
                                                 tooltip: 'Study Questions & Hints',
                                                 onPressed: () {
                                                   Navigator.pop(context);
                                                   Navigator.push(
                                                     context,
                                                     MaterialPageRoute(
                                                       builder: (_) => QuizReviewScreen(
                                                         quizData: item['data'] as List<dynamic>,
                                                         score: 0,
                                                         correctAnswers: 0,
                                                         totalQuestions: (item['data'] as List).length,
                                                         percentage: 100,
                                                         notebookId: widget.notebook['id'],
                                                         quizTitle: item['title'] ?? 'Saved Quiz',
                                                       ),
                                                     ),
                                                   );
                                                 },
                                               ),
                                             IconButton(
                                               icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent),
                                               tooltip: 'Open / Play',
                                              onPressed: () {
                                                Navigator.pop(context);
                                                if (type == 'quiz' && item['data'] is List) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => QuizScreen(
                                                        quizData: item['data'] as List<dynamic>,
                                                        notebookId: widget.notebook['id'],
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  setState(() {
                                                    _selectedTool = type;
                                                    _generatedData = item['data'];
                                                  });
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () async {
                                                await http.post(
                                                  Uri.parse('$baseUrl/delete-history-item'),
                                                  headers: {'Content-Type': 'application/json'},
                                                  body: jsonEncode({
                                                    'notebook_id': widget.notebook['id'],
                                                    'item_id': item['id'],
                                                    'type': 'generation',
                                                  }),
                                                );
                                                setModalState(() {
                                                  historyItems.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                          // Quiz Scores Tab
                          quizResults.isEmpty
                              ? Center(
                                  child: Text(
                                    'No quiz play attempts recorded yet. Play a practice quiz to record your results!',
                                    style: TextStyle(color: context.appColors.mutedText),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: quizResults.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final res = quizResults[index];
                                    final percent = res['percentage'] ?? 0;
                                    final scoreColor = percent >= 80
                                        ? Colors.greenAccent
                                        : percent >= 50
                                            ? Colors.orangeAccent
                                            : Colors.redAccent;

                                    List<dynamic> qData = res['quiz_data'] is List ? List<dynamic>.from(res['quiz_data']) : [];
                                    final List<dynamic>? bData = res['breakdown'] is List ? List<dynamic>.from(res['breakdown']) : null;

                                    // Fallback to saved quiz in history if legacy quiz result
                                    if (qData.isEmpty) {
                                      final savedQuiz = historyItems.firstWhere(
                                        (h) => h['tool_type'] == 'quiz' && h['data'] is List,
                                        orElse: () => null,
                                      );
                                      if (savedQuiz != null && savedQuiz['data'] is List) {
                                        qData = List<dynamic>.from(savedQuiz['data']);
                                      }
                                    }

                                    void openReview() {
                                      if (qData.isEmpty && (bData == null || bData.isEmpty)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No question details saved for this legacy attempt. Play a new quiz to enable full review.'),
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.pop(context); // close modal
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => QuizReviewScreen(
                                            quizData: qData,
                                            breakdown: bData,
                                            score: res['score'] ?? 0,
                                            correctAnswers: res['correct_answers'] ?? 0,
                                            totalQuestions: res['total_questions'] ?? qData.length,
                                            percentage: percent,
                                            playedAt: res['played_at'] ?? '',
                                            notebookId: widget.notebook['id'],
                                            quizTitle: res['quiz_title'] ?? '${widget.notebook['title'] ?? 'Notebook'} Quiz',
                                          ),
                                        ),
                                      );
                                    }

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: context.appColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.appColors.border),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        onTap: openReview,
                                        leading: CircleAvatar(
                                          backgroundColor: scoreColor.withOpacity(0.2),
                                          child: Text(
                                            '$percent%',
                                            style: TextStyle(
                                              color: scoreColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          'Quiz Score: ${res['score']} pts (${res['correct_answers']}/${res['total_questions']})',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              res['played_at'] ?? '',
                                              style: TextStyle(color: context.appColors.mutedText, fontSize: 12),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: openReview,
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.menu_book_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Review Questions & Hints',
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.primary,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (qData.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.replay_rounded, color: Colors.greenAccent, size: 20),
                                                tooltip: 'Retake Quiz',
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => QuizScreen(
                                                        quizData: qData,
                                                        notebookId: widget.notebook['id'],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              tooltip: 'Delete Score',
                                              onPressed: () async {
                                                await http.post(
                                                  Uri.parse('$baseUrl/delete-history-item'),
                                                  headers: {'Content-Type': 'application/json'},
                                                  body: jsonEncode({
                                                    'notebook_id': widget.notebook['id'],
                                                    'item_id': res['id'],
                                                    'type': 'quiz_result',
                                                  }),
                                                );
                                                setModalState(() {
                                                  quizResults.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                          // Automations & Progress Tab
                          automationItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.orangeAccent),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No course automations scheduled for this notebook yet.',
                                        style: TextStyle(color: context.appColors.mutedText),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.auto_awesome),
                                        label: const Text('Setup Course Automation'),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AutomationSetupScreen(
                                                notebookId: widget.notebook['id'],
                                                initialCourseName: widget.notebook['title'] ?? 'Course',
                                                userEmail: userEmail,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: automationItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final auto = automationItems[index];
                                    final cName = auto['course_name'] ?? 'Course Automation';
                                    final totalW = auto['total_weeks'] ?? 14;
                                    final completedW = auto['completed_weeks_count'] ?? 0;
                                    final progressP = (auto['progress_percentage'] ?? 0.0).toDouble();
                                    final timetable = auto['timetable'] ?? {};
                                    final day = timetable['day_of_week'] ?? 'Weekly';
                                    final startTime = timetable['class_start_time'] ?? '';
                                    final endTime = timetable['class_end_time'] ?? '';

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: context.appColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.auto_stories, color: Colors.orangeAccent, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  cName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '$completedW / $totalW Wks ($progressP%)',
                                                  style: const TextStyle(
                                                    color: Colors.greenAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Class: $day $startTime - $endTime',
                                            style: TextStyle(color: context.appColors.mutedText, fontSize: 13),
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: totalW > 0 ? completedW / totalW : 0.0,
                                              minHeight: 6,
                                              backgroundColor: context.appColors.surfaceAlt,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.timeline, size: 16),
                                                label: const Text('View Timeline & History'),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => AutomationHistoryScreen(
                                                        notebookId: widget.notebook['id'],
                                                        courseName: cName,
                                                        userEmail: userEmail,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionRail() {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final settings = AppSettingsScope.of(context);

    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(12, 12, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study actions',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Move from understanding to active practice',
              style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: colors.primaryText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Generating in ${settings.outputLanguage}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildStageLabel('Active AI Roadmap'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _showSingleNotebookRoadmapDialog,
                icon: const Icon(Icons.alt_route),
                label: const Text('Active Study Roadmap', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
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
            _buildWeaknessDrillBtn(),
            const SizedBox(height: 12),
            _buildStudioBtn('Flashcards', 'Review key concepts fast', Icons.style_outlined, 'flashcard'),
            const SizedBox(height: 18),
            _buildStageLabel('History & Records'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: scheme.primary.withOpacity(0.5)),
                ),
                onPressed: _showHistoryModal,
                icon: const Icon(Icons.history_rounded),
                label: const Text('History & Past Results', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why Note2Quiz feels different',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This workspace turns notes into practice. Generate solo quizzes or launch live classroom challenges from the same material.',
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildCenterContent(),
      ),
    );
  }

  Widget _buildCenterContent() {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    if (_selectedTool == 'quiz' && _generatedData is List) {
      return _buildQuizReadyState(_generatedData as List<dynamic>);
    }

    if (_selectedTool == 'flashcard' && _generatedData is List) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: FlashcardView(flashcards: _generatedData),
      );
    }

    if (_selectedTool == 'mindmap' && _generatedData != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: InteractiveMindMapViewer(data: _generatedData),
      );
    }

    if (_generatedData != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: InteractiveNoteViewer(
          content: _generatedData.toString(),
          title: _selectedTool == 'report' ? 'EXECUTIVE BRIEFING DOC' : _selectedTool.toUpperCase(),
          isStreaming: _isStreaming,
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
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 44,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Turn notes into mastery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload your study material, then generate summaries, flashcards, quizzes, and live classroom challenges in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.mutedText, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _showAddSourceOptions,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
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
          Text(
            'Ready to study',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You have ${_sources.length} source${_sources.length == 1 ? '' : 's'} uploaded. Choose how you want to learn next.',
            style: TextStyle(color: colors.mutedText, fontSize: 15, height: 1.5),
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
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

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
              Text(
                'Quiz generated successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${quizData.length} questions are ready. Use it for solo practice or turn it into a live classroom game.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedText, fontSize: 15, height: 1.6),
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
                      MaterialPageRoute(builder: (_) => QuizScreen(quizData: quizData, notebookId: widget.notebook['id'])),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
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
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primaryText),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.5),
              ),
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
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _generateContent(type),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _selectedTool == type ? colors.primarySoft : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _selectedTool == type ? scheme.primary : colors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.primaryText, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeaknessDrillBtn() {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _launchWeaknessDrill,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _mistakesCount > 0 ? Colors.orange.withValues(alpha: 0.12) : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _mistakesCount > 0 ? Colors.orangeAccent.withValues(alpha: 0.7) : colors.border,
            width: _mistakesCount > 0 ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _mistakesCount > 0 ? Colors.orangeAccent.withValues(alpha: 0.2) : colors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.psychology_alt_rounded,
                color: _mistakesCount > 0 ? Colors.orangeAccent : colors.primaryText,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Weakness Drill',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_mistakesCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_mistakesCount to fix',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mistakesCount > 0
                        ? 'Target and solidify $_mistakesCount failed concept${_mistakesCount == 1 ? '' : 's'}'
                        : 'AI adaptive remediation drill',
                    style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageLabel(String label) {
    final colors = context.appColors;

    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: colors.subtleText,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _actionPill(IconData icon, String label) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.mutedText),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: colors.mutedText)),
        ],
      ),
    );
  }
}
