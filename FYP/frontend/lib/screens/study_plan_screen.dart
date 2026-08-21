import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_note_viewer.dart';
import 'quiz_screen.dart';

class StudyPlanScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPlan;
  final String? planId;
  final String userEmail;

  const StudyPlanScreen({
    super.key,
    this.initialPlan,
    this.planId,
    required this.userEmail,
  });

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  Map<String, dynamic>? _plan;
  bool _isLoading = false;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlan != null) {
      _plan = widget.initialPlan;
    } else {
      _fetchPlan();
    }
  }

  Future<void> _fetchPlan() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-study-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (widget.planId != null) 'plan_id': widget.planId,
          'email': widget.userEmail,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _plan = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching study plan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTaskStatus(String taskId, bool currentStatus) async {
    if (_plan == null) return;
    final planId = _plan!['id'];

    // Optimistic UI update
    setState(() {
      final days = _plan!['days'] as List<dynamic>;
      int completed = 0;
      int total = 0;

      for (var d in days) {
        for (var t in d['tasks']) {
          total++;
          if (t['task_id'] == taskId) {
            t['completed'] = !currentStatus;
          }
          if (t['completed'] == true) {
            completed++;
          }
        }
      }

      _plan!['completed_tasks'] = completed;
      _plan!['total_tasks'] = total;
      _plan!['progress_percentage'] = total > 0 ? (completed / total * 100).roundToDouble() : 0.0;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update-task-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plan_id': planId,
          'task_id': taskId,
          'completed': !currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        final updatedPlan = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _plan = updatedPlan;
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
    }
  }

  void _executeTask(Map<String, dynamic> task) {
    final actionType = task['action_type'] ?? 'note';
    final payload = task['payload'] ?? {};
    final taskId = task['task_id'];
    final isCompleted = task['completed'] == true;

    if (actionType == 'quiz') {
      final quizData = payload['quiz_data'] as List<dynamic>? ?? [];
      if (quizData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No quiz questions generated for this task.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(quizData: quizData),
        ),
      ).then((_) {
        // Mark task completed after completing quiz
        if (!isCompleted && taskId != null) {
          _toggleTaskStatus(taskId, false);
        }
      });
    } else if (actionType == 'flashcard') {
      final flashcards = payload['flashcards'] as List<dynamic>? ?? [];
      _showFlashcardsModal(task, flashcards, taskId, isCompleted);
    } else {
      // Note action
      final noteText = payload['summary_text'] ?? 'No summary text available.';
      _showNoteModal(task, noteText, taskId, isCompleted);
    }
  }

  void _showNoteModal(Map<String, dynamic> task, String noteText, String? taskId, bool isCompleted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task['title'] ?? 'AI Note',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: InteractiveNoteViewer(
                  content: noteText,
                  title: task['title'] ?? 'AI Note',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(isCompleted ? Icons.check_circle : Icons.done),
                  label: Text(
                    isCompleted ? 'Marked as Completed' : 'Mark Note as Completed',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (taskId != null) {
                      _toggleTaskStatus(taskId, isCompleted);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  void _showFlashcardsModal(Map<String, dynamic> task, List<dynamic> flashcards, String? taskId, bool isCompleted) {
    if (flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No flashcards generated for this task.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        int cardIdx = 0;
        bool showBack = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentCard = flashcards[cardIdx];
            return AlertDialog(
              backgroundColor: context.appColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flashcards (${cardIdx + 1}/${flashcards.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: GestureDetector(
                onTap: () {
                  setDialogState(() => showBack = !showBack);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 340,
                    minWidth: 280,
                    maxWidth: 340,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: showBack ? Colors.amber.withOpacity(0.15) : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: showBack ? Colors.amber : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        showBack ? 'DEFINITION' : 'TERM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: showBack ? Colors.amber.shade800 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            showBack ? (currentCard['back'] ?? '') : (currentCard['front'] ?? ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to flip',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: cardIdx > 0
                          ? () {
                              setDialogState(() {
                                cardIdx--;
                                showBack = false;
                              });
                            }
                          : null,
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (taskId != null) {
                          _toggleTaskStatus(taskId, isCompleted);
                        }
                      },
                      child: const Text('Finish Review'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: cardIdx < flashcards.length - 1
                          ? () {
                              setDialogState(() {
                                cardIdx++;
                                showBack = false;
                              });
                            }
                          : null,
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Active AI Roadmap')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_plan == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Active AI Roadmap')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No active study plan generated yet.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchPlan,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    final days = (_plan!['days'] as List<dynamic>?) ?? [];
    final double progress = double.tryParse(_plan!['progress_percentage']?.toString() ?? '0') ?? 0.0;
    final int completedTasks = _plan!['completed_tasks'] ?? 0;
    final int totalTasks = _plan!['total_tasks'] ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _plan!['title'] ?? 'AI Roadmap',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // ✅ TOP RIGHT DYNAMIC PROGRESS BAR & PERCENTAGE PILL
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progress == 100
                        ? [const Color(0xFF10B981), Colors.teal]
                        : [scheme.primary, scheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (progress == 100 ? Colors.teal : scheme.primary).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: progress / 100.0,
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Progress: ${progress.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Overall Progress Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withOpacity(0.7),
                  scheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRICULUM ROADMAP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedTasks of $totalTasks Tasks Completed',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_plan!['duration_option']} (${_plan!['daily_hours']}h/day)',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // Animated Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(height: 10, color: scheme.outline.withOpacity(0.15)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: 10,
                        width: (MediaQuery.of(context).size.width - 72) * (progress / 100.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: progress == 100
                                ? [Colors.green, Colors.teal]
                                : [scheme.primary, scheme.secondary],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Day Navigation Tabs
          if (days.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: days.length,
                itemBuilder: (context, idx) {
                  final isSelected = idx == _selectedDayIndex;
                  final day = days[idx];
                  final dayTasks = (day['tasks'] as List<dynamic>?) ?? [];
                  final dayCompletedCount = dayTasks.where((t) => t['completed'] == true).length;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = idx),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Day ${day['day_number'] ?? (idx + 1)}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : scheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white24
                                  : scheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$dayCompletedCount/${dayTasks.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : scheme.primary,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Selected Day Tasks List
          Expanded(
            child: days.isEmpty
                ? const Center(child: Text('No days scheduled.'))
                : _buildDayTaskList(days[_selectedDayIndex]),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTaskList(Map<String, dynamic> day) {
    final tasks = (day['tasks'] as List<dynamic>?) ?? [];
    final title = day['title'] ?? 'Day Session';
    final estMins = day['estimated_minutes'] ?? 60;
    final topics = (day['topics_covered'] as List<dynamic>?) ?? [];
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${estMins}m est.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: topics.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                '📌 $t',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
              ),
            )).toList(),
          ),
        ],
        const SizedBox(height: 16),
        ...tasks.map((task) => _buildTaskCard(task)).toList(),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final actionType = task['action_type'] ?? 'note';
    final isCompleted = task['completed'] == true;
    final title = task['title'] ?? 'Task';
    final subject = task['notebook_title'] ?? 'Subject';
    final taskId = task['task_id'];

    IconData actionIcon;
    Color actionColor;
    String actionBtnLabel;

    if (actionType == 'quiz') {
      actionIcon = Icons.quiz;
      actionColor = Colors.purple;
      actionBtnLabel = 'Take Quiz';
    } else if (actionType == 'flashcard') {
      actionIcon = Icons.style;
      actionColor = Colors.amber.shade800;
      actionBtnLabel = 'Review Flashcards';
    } else {
      actionIcon = Icons.auto_stories;
      actionColor = Colors.blue;
      actionBtnLabel = 'Read AI Note';
    }

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? scheme.surface.withOpacity(0.5)
            : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.4)
              : scheme.outline.withOpacity(0.2),
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: () {
            if (taskId != null) _toggleTaskStatus(taskId, isCompleted);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : actionColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : actionIcon,
              color: isCompleted ? Colors.white : actionColor,
              size: 22,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : scheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: actionColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? Colors.grey.shade700 : actionColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _executeTask(task),
          child: Text(
            actionBtnLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
