import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'automation_history_screen.dart';
import 'notebook_screen.dart';
import 'settings_screen.dart';
import 'student_lobby_screen.dart';
import 'study_plan_screen.dart';
import 'timetable_scanner_screen.dart';
import '../state/app_settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/course_colors.dart';

class DashboardScreen extends StatefulWidget {
  final String? email;
  const DashboardScreen({super.key, this.email});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _notebooks = [];
  List<dynamic> _automations = [];
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

      // Fetch all automations for progress tracking
      final autoUri = Uri.parse(
        '$baseUrl/api/automations?user_email=${Uri.encodeComponent(_userEmail)}',
      );
      final autoResp = await http.get(autoUri);
      if (autoResp.statusCode == 200) {
        final autoData = jsonDecode(autoResp.body);
        setState(() => _automations = autoData['automations'] ?? []);
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

    List<Map<String, dynamic>> roadmapHistory = [];
    bool isLoadingHistory = true;
    bool isCreatingNew = false;

    // Fetch history
    try {
      final historyResp = await http.get(
        Uri.parse('$baseUrl/get-study-plan-history?email=$_userEmail'),
      );
      if (historyResp.statusCode == 200) {
        final data = jsonDecode(historyResp.body);
        roadmapHistory = List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching roadmap history: $e");
    } finally {
      isLoadingHistory = false;
    }

    if (!mounted) return;

    List<String> selectedNotebookIds = [];
    String durationOption = 'AI Automated';
    double dailyHours = 2.0;

    // If no history, default directly to creation view
    if (roadmapHistory.isEmpty) {
      isCreatingNew = true;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = context.appColors;
            final scheme = Theme.of(context).colorScheme;

            // Calculate total sources across selected notebooks
            int totalSelectedSources = 0;
            for (var nb in _notebooks) {
              final id = nb['id'].toString();
              if (selectedNotebookIds.contains(id)) {
                final sources = nb['sources'] as List<dynamic>? ?? [];
                totalSelectedSources += sources.length;
              }
            }

            return Dialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 580,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.alt_route_rounded, color: Color(0xFF6C63FF), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCreatingNew ? 'Create AI Study Roadmap' : 'AI Study Roadmaps',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text(
                                isCreatingNew
                                    ? 'Detailed, topic-by-topic learning path with active recall'
                                    : 'Active learning paths & roadmap history',
                                style: TextStyle(color: colors.mutedText, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        child: isCreatingNew
                            ? _buildCreateRoadmapContent(
                                colors,
                                scheme,
                                setModalState,
                                selectedNotebookIds,
                                durationOption,
                                dailyHours,
                                totalSelectedSources,
                                (opt) => setModalState(() => durationOption = opt),
                                (hrs) => setModalState(() => dailyHours = hrs),
                              )
                            : _buildRoadmapHistoryList(
                                colors,
                                scheme,
                                setModalState,
                                roadmapHistory,
                                isLoadingHistory,
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isCreatingNew && roadmapHistory.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setModalState(() => isCreatingNew = false),
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('View History'),
                          )
                        else if (!isCreatingNew)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF6C63FF)),
                              foregroundColor: const Color(0xFF6C63FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => setModalState(() => isCreatingNew = true),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create New Roadmap'),
                          )
                        else
                          const SizedBox.shrink(),

                        if (isCreatingNew)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: selectedNotebookIds.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _generateRoadmap(selectedNotebookIds, durationOption, dailyHours);
                                  },
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: Text(
                              'Generate Plan (${totalSelectedSources > 0 ? "$totalSelectedSources Topics" : "Select Subjects"})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
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

  Widget _buildRoadmapHistoryList(
    AppColors colors,
    ColorScheme scheme,
    StateSetter setModalState,
    List<Map<String, dynamic>> history,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.map_outlined, size: 48, color: colors.subtleText),
              const SizedBox(height: 12),
              const Text('No study roadmaps yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'Generate your first customized AI learning roadmap from your subjects!',
                style: TextStyle(color: colors.mutedText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Learning Paths:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ...history.map((plan) {
          final planId = plan['id']?.toString() ?? '';
          final title = plan['title'] ?? 'Study Roadmap';
          final subjects = (plan['notebook_titles'] as List<dynamic>?)?.join(', ') ?? 'All Subjects';
          final duration = plan['duration_option'] ?? 'Custom';
          final progress = (plan['progress_percentage'] as num?)?.toDouble() ?? 0.0;
          final completedTasks = plan['completed_tasks'] ?? 0;
          final totalTasks = plan['total_tasks'] ?? 0;
          final totalTopics = plan['total_topics_count'] ?? 0;
          final daysCount = plan['days_count'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            color: colors.surfaceAlt,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: 'Delete Roadmap',
                        onPressed: () async {
                          try {
                            await http.post(
                              Uri.parse('$baseUrl/delete-study-plan'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({'plan_id': planId, 'email': _userEmail}),
                            );
                            setModalState(() {
                              history.removeWhere((p) => p['id'] == planId);
                            });
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📚 $subjects',
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysCount Days ($duration)',
                          style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (totalTopics > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalTopics Topics Covered',
                            style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${progress.toStringAsFixed(0)}% ($completedTasks/$totalTasks tasks)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.mutedText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalTasks > 0 ? (completedTasks / totalTasks) : 0.0,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 100 ? Colors.green : const Color(0xFF6C63FF),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudyPlanScreen(
                              planId: planId,
                              userEmail: _userEmail,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(progress >= 100 ? 'Review Completed Roadmap' : 'Continue Study Roadmap'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCreateRoadmapContent(
    AppColors colors,
    ColorScheme scheme,
    StateSetter setModalState,
    List<String> selectedNotebookIds,
    String durationOption,
    double dailyHours,
    int totalSelectedSources,
    ValueChanged<String> onDurationChanged,
    ValueChanged<double> onHoursChanged,
  ) {
    String pacingGuidance = '';
    if (totalSelectedSources > 0) {
      if (durationOption == 'AI Automated') {
        int recommendedDays = totalSelectedSources <= 4 ? 3 : (totalSelectedSources <= 8 ? 5 : (totalSelectedSources <= 14 ? 7 : 12));
        pacingGuidance = '💡 AI recommends $recommendedDays days for $totalSelectedSources topics (~2-3 topics/day) with comprehensive notes & quizzes.';
      } else if (durationOption == '1 Day') {
        pacingGuidance = '⚡ Intensive Cram Mode: All $totalSelectedSources topics condensed for rapid review.';
      } else if (durationOption == '3 Days') {
        double tpd = totalSelectedSources / 3.0;
        pacingGuidance = '🎯 Fast-Paced Sprint: ~${tpd.toStringAsFixed(1)} topics per day.';
      } else if (durationOption == '7 Days') {
        double tpd = totalSelectedSources / 7.0;
        pacingGuidance = '📖 Balanced Pacing: ~${tpd.toStringAsFixed(1)} topics per day with deep recall quizzes.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Select Subjects / Notebooks to Include:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        ..._notebooks.map((nb) {
          final id = nb['id'].toString();
          final title = nb['title'] ?? 'Notebook';
          final sources = nb['sources'] as List<dynamic>? ?? [];
          final isChecked = selectedNotebookIds.contains(id);

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isChecked ? const Color(0xFF6C63FF) : colors.border,
              ),
            ),
            color: isChecked ? const Color(0xFF6C63FF).withValues(alpha: 0.08) : colors.surfaceAlt,
            child: CheckboxListTile(
              dense: true,
              value: isChecked,
              activeColor: const Color(0xFF6C63FF),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                '${sources.length} lecture topics/sources ready',
                style: TextStyle(color: colors.mutedText, fontSize: 11),
              ),
              onChanged: (val) {
                setModalState(() {
                  if (val == true) {
                    selectedNotebookIds.add(id);
                  } else {
                    selectedNotebookIds.remove(id);
                  }
                });
              },
            ),
          );
        }),

        if (totalSelectedSources > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$totalSelectedSources total topics will be scheduled into the learning path.',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ],

        const Divider(height: 24),
        const Text('2. Select Plan Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            {'label': 'AI Automated (Smart)', 'val': 'AI Automated'},
            {'label': '3 Days (Crash Course)', 'val': '3 Days'},
            {'label': '7 Days (Paced)', 'val': '7 Days'},
            {'label': '1 Day (Intensive)', 'val': '1 Day'},
          ].map((item) {
            final isSelected = durationOption == item['val'];
            return ChoiceChip(
              label: Text(item['label']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: const Color(0xFF6C63FF),
              labelStyle: TextStyle(color: isSelected ? Colors.white : colors.primaryText),
              onSelected: (selected) {
                if (selected) onDurationChanged(item['val']!);
              },
            );
          }).toList(),
        ),

        if (pacingGuidance.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            pacingGuidance,
            style: TextStyle(fontSize: 11, color: colors.mutedText, height: 1.4),
          ),
        ],

        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('3. Daily Study Time Commitment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              '${dailyHours.toStringAsFixed(1)} hrs/day',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), fontSize: 13),
            ),
          ],
        ),
        Slider(
          value: dailyHours,
          min: 0.5,
          max: 8.0,
          divisions: 15,
          activeColor: const Color(0xFF6C63FF),
          onChanged: onHoursChanged,
        ),
      ],
    );
  }

  Future<void> _showAllAutomationsDialog() async {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.alarm_on, color: Colors.orangeAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Automations & Progress',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Track and review weekly progress across all your notebooks',
                              style: TextStyle(fontSize: 12, color: colors.mutedText),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _automations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 56, color: Colors.orangeAccent),
                                const SizedBox(height: 14),
                                Text(
                                  'No active course automations yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Open any notebook to setup an automated revision schedule.',
                                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _automations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final auto = _automations[index];
                              final cName = auto['course_name'] ?? 'Course';
                              final notebookId = auto['notebook_id'] ?? '';
                              final totalW = auto['total_weeks'] ?? 14;
                              final completedW = auto['completed_weeks_count'] ?? 0;
                              final progressP = (auto['progress_percentage'] ?? 0.0).toDouble();
                              final timetable = auto['timetable'] ?? {};
                              final day = timetable['day_of_week'] ?? 'Weekly';
                              final startTime = timetable['class_start_time'] ?? '';
                              final endTime = timetable['class_end_time'] ?? '';
                              final nextTrigger = auto['next_scheduled_trigger'];

                              // Match notebook name
                              final matchedNb = _notebooks.firstWhere(
                                (n) => n['id'] == notebookId,
                                orElse: () => null,
                              );
                              final nbTitle = matchedNb != null ? matchedNb['title'] : cName;

                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.school_outlined, color: Colors.orangeAccent, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                'Notebook: $nbTitle',
                                                style: TextStyle(color: colors.mutedText, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            '$completedW / $totalW Weeks ($progressP%)',
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 13, color: colors.mutedText),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$day $startTime - $endTime',
                                          style: TextStyle(color: colors.mutedText, fontSize: 12),
                                        ),
                                        if (nextTrigger != null) ...[
                                          const SizedBox(width: 14),
                                          const Icon(Icons.alarm_on, size: 13, color: Colors.orangeAccent),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Next: $nextTrigger',
                                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: totalW > 0 ? (completedW / totalW).clamp(0.0, 1.0) : 0.0,
                                        minHeight: 8,
                                        backgroundColor: colors.surfaceAlt,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (matchedNb != null) ...[
                                          TextButton.icon(
                                            icon: const Icon(Icons.folder_open, size: 16),
                                            label: const Text('Open Notebook'),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NotebookScreen(notebook: matchedNb),
                                                ),
                                              ).then((_) => _fetchNotebooks());
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.orangeAccent.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.timeline, size: 16),
                                          label: const Text('View Timeline & History', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AutomationHistoryScreen(
                                                  notebookId: notebookId,
                                                  courseName: cName,
                                                  userEmail: _userEmail,
                                                ),
                                              ),
                                            ).then((_) => _fetchNotebooks());
                                          },
                                        ),
                                      ],
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
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: _showAllAutomationsDialog,
                                    child: _buildStatCard(
                                      icon: Icons.alarm_on,
                                      title: 'Automations',
                                      value: '${_automations.length} Active',
                                      subtitle: 'Track course schedules',
                                    ),
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
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TimetableScannerScreen(userEmail: _userEmail),
                                          ),
                                        );
                                        _fetchNotebooks();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        side: const BorderSide(color: Color(0xFF3451FF)),
                                      ),
                                      icon: const Icon(Icons.document_scanner_rounded, color: Color(0xFF3451FF), size: 18),
                                      label: const Text(
                                        'Smart Timetable',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _showAllAutomationsDialog,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        side: const BorderSide(color: Colors.orangeAccent),
                                      ),
                                      icon: const Icon(Icons.alarm_on, color: Colors.orangeAccent, size: 18),
                                      label: Text(
                                        'Automations & Progress (${_automations.length})',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _showMultiSelectRoadmapDialog,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        side: BorderSide(color: scheme.primary),
                                      ),
                                      icon: const Icon(Icons.alt_route, color: Colors.purpleAccent, size: 18),
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
    final title = notebook['title']?.toString() ?? 'Untitled Notebook';

    final courseColor = CourseColors.getByCourseId(title);

    final matchingAuto = _automations.firstWhere(
      (a) => a['notebook_id'] == notebook['id'],
      orElse: () => null,
    );

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
          border: Border.all(
            color: matchingAuto != null 
                ? Colors.orangeAccent.withValues(alpha: 0.6) 
                : courseColor.border,
            width: matchingAuto != null ? 1.5 : 1.2,
          ),
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
                      color: matchingAuto != null 
                          ? Colors.orangeAccent.withValues(alpha: 0.15) 
                          : courseColor.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: matchingAuto != null 
                            ? Colors.orangeAccent.withValues(alpha: 0.3) 
                            : courseColor.border,
                      ),
                    ),
                    child: Icon(
                      matchingAuto != null ? Icons.alarm_on : Icons.menu_book_rounded,
                      color: matchingAuto != null ? Colors.orangeAccent : courseColor.primary,
                    ),
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
                title,
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
                  if (matchingAuto != null)
                    _chip(
                      Icons.alarm_on,
                      '${matchingAuto['progress_percentage']}% Wks',
                      isHighlight: true,
                    )
                  else
                    _chip(Icons.quiz_outlined, 'Quiz-ready'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    matchingAuto != null ? 'Open & View Schedule' : 'Open workspace',
                    style: TextStyle(
                      color: matchingAuto != null ? Colors.orangeAccent : const Color(0xFFB8B3FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: matchingAuto != null ? Colors.orangeAccent : const Color(0xFFB8B3FF),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool isHighlight = false}) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.orangeAccent.withOpacity(0.15) : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? Colors.orangeAccent.withOpacity(0.4) : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isHighlight ? Colors.orangeAccent : colors.mutedText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? Colors.orangeAccent : colors.mutedText,
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
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
