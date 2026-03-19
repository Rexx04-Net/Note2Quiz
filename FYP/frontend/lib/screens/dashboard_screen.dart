import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'notebook_screen.dart';
import 'student_lobby_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinLiveGame,
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.black,
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
                                      const Text(
                                        'Welcome back',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _userEmail,
                                        style: const TextStyle(color: Colors.white60, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  color: const Color(0xFF232334),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'logout',
                                      child: ListTile(
                                        leading: Icon(Icons.logout, color: Colors.redAccent),
                                        title: Text('Log Out', style: TextStyle(color: Colors.white)),
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
                                    backgroundColor: const Color(0xFF6C63FF),
                                    child: Text(
                                      _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                const Text(
                                  'My notebooks',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _createNotebook,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('New notebook'),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF9C96FF)),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_stories_rounded, size: 42, color: Color(0xFF9C96FF)),
          const SizedBox(height: 16),
          const Text(
            'Start your first study workspace',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create a notebook, upload notes or slides, then generate quizzes, flashcards, and classroom challenges.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _createNotebook,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
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
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook)),
      ).then((_) => _fetchNotebooks()),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A26),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
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
                      color: const Color(0xFF6C63FF).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF9C96FF)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete notebook',
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () => _deleteNotebook(notebook['id']),
                  )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                notebook['title'] ?? 'Untitled Notebook',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232334),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}