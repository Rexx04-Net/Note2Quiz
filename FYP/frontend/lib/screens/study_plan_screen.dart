import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_note_viewer.dart';
import 'quiz_screen.dart';
import 'quiz_review_screen.dart';

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

  @override
  void dispose() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    super.dispose();
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

  void _executeTask(Map<String, dynamic> task) async {
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

      // If already completed or has prior attempt breakdown, show review/retake options sheet
      if (isCompleted || payload['last_breakdown'] != null) {
        _showQuizReviewOrRetakeOptions(task, quizData);
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            quizData: quizData,
            notebookId: task['notebook_id'],
            userEmail: widget.userEmail,
          ),
        ),
      );

      if (result != null && result is Map) {
        _handleQuizResult(task, result, quizData);
      }
    } else if (actionType == 'flashcard') {
      final flashcards = payload['flashcards'] as List<dynamic>? ?? [];
      _showFlashcardsModal(task, flashcards, taskId, isCompleted);
    } else {
      // Note action
      final noteText = payload['summary_text'] ?? 'No summary text available.';
      _showNoteModal(task, noteText, taskId, isCompleted);
    }
  }

  void _handleQuizResult(Map<String, dynamic> task, Map<dynamic, dynamic> result, List<dynamic> quizData) {
    final taskId = task['task_id'];
    final isCompleted = task['completed'] == true;
    final int percentage = (result['percentage'] ?? 0) as int;
    final int correct = (result['correct_answers'] ?? 0) as int;
    final int total = (result['total_questions'] ?? quizData.length) as int;
    final userAnswers = result['user_answers'];

    setState(() {
      task['payload']['last_score'] = percentage;
      task['payload']['last_correct'] = correct;
      task['payload']['last_total'] = total;
      task['payload']['last_breakdown'] = userAnswers;
    });

    if (percentage >= 80) {
      // Passed mastery threshold (>= 80%)
      if (!isCompleted && taskId != null) {
        _toggleTaskStatus(taskId, false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            showCloseIcon: true,
            closeIconColor: Colors.white,
            content: Text('🎉 Mastery Achieved ($percentage% - $correct/$total)! Quiz marked as completed.'),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        });
      }
    } else {
      // Failed (< 80%) - Do NOT mark completed
      if (isCompleted && taskId != null) {
        _toggleTaskStatus(taskId, true); // uncheck if previously checked
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            showCloseIcon: true,
            closeIconColor: Colors.white,
            content: Text('⚠️ Scored $percentage% ($correct/$total). Reach 80% accuracy to pass and complete this task!'),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        });
      }
    }
  }

  void _showQuizReviewOrRetakeOptions(Map<String, dynamic> task, List<dynamic> quizData) {
    final payload = task['payload'] ?? {};
    final breakdown = payload['last_breakdown'] as List<dynamic>?;
    final int lastScore = (payload['last_score'] as num?)?.toInt() ?? 100;
    final int lastCorrect = (payload['last_correct'] as num?)?.toInt() ?? quizData.length;
    final int lastTotal = (payload['last_total'] as num?)?.toInt() ?? quizData.length;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.quiz, color: Colors.purpleAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] ?? 'Checkpoint Quiz',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Latest Score: $lastScore% ($lastCorrect/$lastTotal Correct)',
                          style: TextStyle(
                            fontSize: 13,
                            color: lastScore >= 80 ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake Quiz'),
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              quizData: quizData,
                              notebookId: task['notebook_id'],
                              userEmail: widget.userEmail,
                            ),
                          ),
                        );
                        if (result != null && result is Map) {
                          _handleQuizResult(task, result, quizData);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.fact_check),
                      label: const Text('Review Answers'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizReviewScreen(
                              quizData: quizData,
                              breakdown: breakdown,
                              score: lastScore,
                              correctAnswers: lastCorrect,
                              totalQuestions: lastTotal,
                              percentage: lastScore,
                              notebookId: task['notebook_id'],
                              quizTitle: task['title'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
        double currentEF = double.tryParse(task['ease_factor']?.toString() ?? '2.5') ?? 2.5;
        int currentIntervalDays = int.tryParse((task['sm2_interval'] ?? '1d').toString().replaceAll('d', '')) ?? 1;
        int cardsMastered = 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isFinished = cardIdx >= flashcards.length;

            if (isFinished) {
              return AlertDialog(
                backgroundColor: context.appColors.surfaceAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.military_tech, color: Colors.amber, size: 28),
                    SizedBox(width: 10),
                    Text('SM-2 Review Consolidated!'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withValues(alpha: 0.2), Colors.blue.withValues(alpha: 0.1)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '🎉 All ${flashcards.length} Flashcards Completed!',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Mastered', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text('$cardsMastered/${flashcards.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Ease Factor', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(currentEF.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purpleAccent)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Next Recall', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text('+${currentIntervalDays}d', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.greenAccent)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your active recall performance has been recorded. Ebbinghaus memory curve reset for this topic.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (taskId != null) {
                        _toggleTaskStatus(taskId, isCompleted);
                      }
                    },
                    child: const Text('Complete & Consolidate Task', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }

            void processSM2Rating(int q, String nextIntervalLabel, int nextDays) {
              // SM-2 Formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
              double newEF = currentEF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
              if (newEF < 1.3) newEF = 1.3;

              setDialogState(() {
                currentEF = newEF;
                currentIntervalDays = nextDays;
                if (q >= 3) cardsMastered++;
                cardIdx++;
                showBack = false;
              });
            }

            final currentCard = flashcards[cardIdx];

            return AlertDialog(
              backgroundColor: context.appColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.purpleAccent, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SM-2 Active Recall (${cardIdx + 1}/${flashcards.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'EF: ${currentEF.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (cardIdx + 1) / flashcards.length,
                      minHeight: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    ),
                  ),
                ],
              ),
              content: GestureDetector(
                onTap: () => setDialogState(() => showBack = !showBack),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  constraints: const BoxConstraints(
                    minHeight: 210,
                    maxHeight: 320,
                    minWidth: 300,
                    maxWidth: 380,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: showBack ? Colors.purple.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: showBack ? Colors.purpleAccent : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        showBack ? '💡 ANSWER / DEFINITION' : '❓ TERM / CONCEPT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: showBack ? Colors.purpleAccent : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            showBack ? (currentCard['back'] ?? '') : (currentCard['front'] ?? ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        showBack ? 'Tap card to flip back' : '👆 Tap to reveal definition & rate recall',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (!showBack)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Exit'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purpleAccent.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.touch_app, size: 16),
                        label: const Text('Show Answer'),
                        onPressed: () => setDialogState(() => showBack = true),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Rate your recall (SM-2 Spaced Repetition):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => processSM2Rating(1, '<10m', 1),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('<10m', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orangeAccent,
                                side: const BorderSide(color: Colors.orangeAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => processSM2Rating(3, '1d', 1),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Hard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('1d', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.greenAccent,
                                side: const BorderSide(color: Colors.greenAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => processSM2Rating(4, '3d', 3),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Good', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('3d', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => processSM2Rating(5, '6d', 6),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Easy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                  Text('6d', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    final focusObj = day['focus_objective']?.toString();
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
        if (focusObj != null && focusObj.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withValues(alpha: 0.15), Colors.indigo.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, size: 18, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SM-2 Learning Goal: $focusObj',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purpleAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final isSm2Review = task['is_sm2_review'] == true;
    final sm2Interval = task['sm2_interval'] ?? '1d';
    final difficulty = task['difficulty_tier'] ?? 'Intermediate';
    final cognitive = task['cognitive_load'] ?? 'Moderate';
    final payload = task['payload'] ?? {};
    final lastScore = payload['last_score'];

    IconData actionIcon;
    Color actionColor;
    String actionBtnLabel;

    if (actionType == 'quiz') {
      actionIcon = isCompleted ? Icons.fact_check : Icons.quiz;
      actionColor = isCompleted ? Colors.purple : (lastScore != null ? Colors.orange.shade800 : Colors.purple);
      if (isCompleted) {
        actionBtnLabel = 'Review Answers';
      } else if (lastScore != null) {
        actionBtnLabel = 'Retake ($lastScore%)';
      } else {
        actionBtnLabel = 'Take Quiz';
      }
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

    // Difficulty chip colors
    Color diffColor = Colors.amber;
    if (difficulty.toString().toLowerCase().contains('foundat')) {
      diffColor = Colors.teal;
    } else if (difficulty.toString().toLowerCase().contains('high') || difficulty.toString().toLowerCase().contains('exam')) {
      diffColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? scheme.surface.withValues(alpha: 0.5)
            : (isSm2Review ? Colors.purple.withValues(alpha: 0.04) : scheme.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.4)
              : (isSm2Review ? Colors.purpleAccent.withValues(alpha: 0.5) : scheme.outline.withValues(alpha: 0.2)),
          width: isCompleted || isSm2Review ? 1.5 : 1,
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
              color: isCompleted ? Colors.green : actionColor.withValues(alpha: 0.15),
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
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
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
              if (isSm2Review)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '🧠 SM-2 Recall ($sm2Interval)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: diffColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚡ $cognitive',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
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
