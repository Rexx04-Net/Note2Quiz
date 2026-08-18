import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'notebook_screen.dart';
import 'settings_screen.dart';
import 'student_lobby_screen.dart';
import 'study_plan_screen.dart';
import '../state/app_settings_controller.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final String? email;
  const DashboardScreen({super.key, this.email});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _notebooks = [];
  bool _isLoading = true;
  String _userEmail = 'guest';

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _userEmail = widget.email!;
    _fetchNotebooks();
  }

  Future<void> _fetchNotebooks() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-notebooks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _userEmail}),
      );
      if (response.statusCode == 200) {
        setState(() => _notebooks = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching notebooks: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNotebook() async {
    final title = await _showInputDialog('New Notebook', 'Enter title (e.g. Biology 101)');
    if (title == null || title.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-notebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _userEmail, 'title': title.trim()}),
      );
      if (response.statusCode == 200) {
        _fetchNotebooks();
      }
    } catch (e) {
      debugPrint('Error creating notebook: $e');
    }
  }

  Future<void> _deleteNotebook(String id) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/delete-notebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      _fetchNotebooks();
    } catch (e) {
      debugPrint('Error deleting notebook: $e');
    }
  }

  Future<void> _joinLiveGame() async {
    final code = await _showInputDialog('Join Game', 'Enter Game PIN');
    if (code == null || code.trim().isEmpty) return;

    final name = await _showInputDialog('Your Name', 'Enter your nickname');
    if (name == null || name.trim().isEmpty) return;

    final response = await http.post(
      Uri.parse('$baseUrl/join-game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code.trim(), 'name': name.trim()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentLobbyScreen(
            quizData: data['quiz_data'],
            gameCode: code.trim().toUpperCase(),
            playerName: name.trim(),
          ),
        ),
      );
    } else {
      final errData = jsonDecode(response.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errData['error'] ?? 'Invalid Game PIN!')),
      );
    }
  }

  Future<void> _showMultiSelectRoadmapDialog() async {
    if (_notebooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create notebooks and add sources first.')),
      );
      return;
    }

    List<String> selectedNotebookIds = [];
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
              title: const Row(
                children: [
                  Icon(Icons.alt_route, color: Colors.purpleAccent),
                  SizedBox(width: 8),
                  Text('Active AI Roadmap', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Select Subjects / Notebooks:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._notebooks.map((nb) {
                      final id = nb['id'].toString();
                      final isChecked = selectedNotebookIds.contains(id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(nb['title'] ?? 'Notebook', style: const TextStyle(fontWeight: FontWeight.w500)),
                        value: isChecked,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              selectedNotebookIds.add(id);
                            } else {
                              selectedNotebookIds.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                    const Divider(height: 24),
                    const Text('2. Select Plan Duration:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        const Text('3. Daily Study Time:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  onPressed: selectedNotebookIds.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _generateRoadmap(selectedNotebookIds, durationOption, dailyHours);
                        },
                  child: const Text('Generate Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateRoadmap(List<String> ids, String durationOption, double dailyHours) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gemini AI is crafting your Active Roadmap...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-active-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _userEmail,
          'notebook_ids': ids,
          'duration_option': durationOption,
          'daily_hours': dailyHours,
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final planData = jsonDecode(response.body);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPlanScreen(
              initialPlan: planData,
              userEmail: _userEmail,
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
      if (mounted) Navigator.pop(context);
      debugPrint('Error generating plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final settingsController = AppSettingsScope.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinLiveGame,
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        icon: const Icon(Icons.sports_esports),
        label: const Text('Join Live Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchNotebooks,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back',
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _userEmail,
                                        style: TextStyle(color: colors.mutedText, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Settings',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SettingsScreen(
                                          userEmail: _userEmail,
                                          settingsController: settingsController,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.settings_outlined,
                                    color: colors.mutedText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  color: colors.surfaceAlt,
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'logout',
                                      child: ListTile(
                                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                                        title: Text(
                                          'Log Out',
                                          style: TextStyle(color: scheme.onSurface),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'logout') {
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: scheme.primary,
                                    child: Text(
                                      _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.menu_book_rounded,
                                    title: 'Notebooks',
                                    value: '${_notebooks.length}',
                                    subtitle: 'Your study spaces',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.auto_awesome,
                                    title: 'Quick start',
                                    value: '1 tap',
                                    subtitle: 'Create a notebook fast',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.groups_rounded,
                                    title: 'Live mode',
                                    value: 'Ready',
                                    subtitle: 'Join or host quiz battles',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'My notebooks',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _showMultiSelectRoadmapDialog,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        side: BorderSide(color: scheme.primary),
                                      ),
                                      icon: const Icon(Icons.alt_route, color: Colors.purpleAccent),
                                      label: const Text('AI Roadmap', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: _createNotebook,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: scheme.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('New notebook'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (_notebooks.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildEmptyState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.15,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildNotebookCard(_notebooks[index]),
                            childCount: _notebooks.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primaryText),
          ),
          const SizedBox(height: 18),
          Text(title, style: TextStyle(color: colors.mutedText, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: colors.subtleText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories_rounded, size: 42, color: colors.primaryText),
          const SizedBox(height: 16),
          Text(
            'Start your first study workspace',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create a notebook, upload notes or slides, then generate quizzes, flashcards, and classroom challenges.',
            style: TextStyle(color: colors.mutedText, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _createNotebook,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create notebook'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookCard(dynamic notebook) {
    final sourceCount = (notebook['sources'] ?? []).length;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook)),
      ).then((_) => _fetchNotebooks()),
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: colors.primaryText),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete notebook',
                    icon: Icon(Icons.delete_outline, color: colors.mutedText),
                    onPressed: () => _deleteNotebook(notebook['id']),
                  )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                notebook['title'] ?? 'Untitled Notebook',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(Icons.description_outlined, '$sourceCount source${sourceCount == 1 ? '' : 's'}'),
                  _chip(Icons.quiz_outlined, 'Quiz-ready'),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Text('Open workspace', style: TextStyle(color: Color(0xFFB8B3FF), fontWeight: FontWeight.w600)),
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

  Widget _chip(IconData icon, String label) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.mutedText),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: colors.mutedText, fontSize: 12)),
        ],
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: scheme.onSurface)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.subtleText),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
