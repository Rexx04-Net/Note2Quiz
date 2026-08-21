import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import 'quiz_review_screen.dart';

class QuizScreen extends StatefulWidget {
  final List<dynamic> quizData;
  final String? notebookId;
  final int? weekNumber;
  final String? userEmail;
  final bool isWeaknessDrill;

  const QuizScreen({
    super.key,
    required this.quizData,
    this.notebookId,
    this.weekNumber,
    this.userEmail,
    this.isWeaknessDrill = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  String _selectedAnswer = '';
  bool _isAnswered = false;
  bool _showHint = false;
  final List<Map<String, dynamic>> _userAnswers = [];

  @override
  void initState() {
    super.initState();
    for (var q in widget.quizData) {
      if (q is Map && q['options'] is List) {
        (q['options'] as List).shuffle();
      }
    }
  }

  void _submitAnswer(String answer) {
    if (_isAnswered) return;

    final currentQuestion = widget.quizData[_currentIndex];
    final isCorrect = answer == currentQuestion['answer'];

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _showHint = false;

      if (isCorrect) {
        _score += 10;
        _correctAnswers++;
      }

      _userAnswers.add({
        'question': currentQuestion['question'] ?? '',
        'options': List<String>.from(currentQuestion['options'] ?? []),
        'selected_answer': answer,
        'correct_answer': (currentQuestion['answer'] ?? '').toString(),
        'is_correct': isCorrect,
        'hint': (currentQuestion['hint'] ?? '').toString(),
        'explanation': (currentQuestion['explanation'] ?? '').toString(),
        'is_remediation': currentQuestion['is_remediation'] == true,
      });
    });

    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_currentIndex < widget.quizData.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedAnswer = '';
        });
      } else {
        _showResultsDialog();
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _selectedAnswer = '';
      _isAnswered = false;
      _showHint = false;
      _userAnswers.clear();
    });
  }

  Future<void> _saveQuizResult(int percent, int total) async {
    if (widget.notebookId == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/save-quiz-result'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': widget.notebookId,
          'score': _score,
          'correct_answers': _correctAnswers,
          'total_questions': total,
          'percentage': percent,
          'quiz_data': widget.quizData,
          'breakdown': _userAnswers,
          'quiz_title': widget.isWeaknessDrill ? '🎯 Weakness Drill' : 'Solo Practice',
        }),
      );

      // Also record in syllabus automation history if launched as revision quiz
      if (widget.weekNumber != null) {
        await http.post(
          Uri.parse('$baseUrl/api/automations/quiz-completed'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'notebook_id': widget.notebookId,
            'week_number': widget.weekNumber,
            'score': _correctAnswers,
            'total_questions': total,
            'user_email': widget.userEmail ?? '',
          }),
        );
      }
    } catch (e) {
      debugPrint('Error saving quiz result: $e');
    }
  }

  void _showResultsDialog() {
    final total = widget.quizData.length;
    final percent = total == 0 ? 0 : ((_correctAnswers / total) * 100).round();
    final scheme = Theme.of(context).colorScheme;

    _saveQuizResult(percent, total);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          widget.isWeaknessDrill ? '🎯 Weakness Drill Complete' : 'Practice complete',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score: $_score points',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Correct: $_correctAnswers / $total',
              style: TextStyle(color: context.appColors.mutedText, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: $percent%',
              style: TextStyle(color: context.appColors.mutedText, fontSize: 15),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    percent >= 80 ? Icons.emoji_events_outlined : Icons.track_changes_outlined,
                    color: percent >= 80 ? Colors.amber : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isWeaknessDrill
                          ? (percent >= 80
                              ? 'Excellent remediation! You mastered your previously missed concepts.'
                              : 'Keep practicing! Review explanations to solidify weak areas.')
                          : (percent >= 80
                              ? 'Strong understanding shown. Try harder questions or take this live.'
                              : 'Review weak spots and try another practice round.'),
                      style: TextStyle(color: context.appColors.mutedText, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartQuiz();
            },
            child: const Text('Practice again'),
          ),
          if (_userAnswers.isNotEmpty)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizReviewScreen(
                      quizData: widget.quizData,
                      breakdown: _userAnswers,
                      score: _score,
                      correctAnswers: _correctAnswers,
                      totalQuestions: total,
                      percentage: percent,
                      notebookId: widget.notebookId,
                    ),
                  ),
                );
              },
              child: const Text('Review Answers'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Finish session'),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor(String option, Color defaultColor) {
    if (!_isAnswered) return defaultColor;

    final correctAnswer = widget.quizData[_currentIndex]['answer'];

    if (option == correctAnswer) {
      return Colors.green.withOpacity(0.85);
    }
    if (option == _selectedAnswer && option != correctAnswer) {
      return Colors.redAccent.withOpacity(0.85);
    }
    return defaultColor.withOpacity(0.45);
  }

  Color _getBorderColor(String option, Color defaultColor) {
    if (!_isAnswered) return defaultColor;
    final correctAnswer = widget.quizData[_currentIndex]['answer'];
    if (option == correctAnswer) return Colors.greenAccent;
    if (option == _selectedAnswer && option != correctAnswer) return Colors.redAccent;
    return Colors.transparent;
  }

  IconData? _getAnswerIcon(String option) {
    if (!_isAnswered) return null;
    final correctAnswer = widget.quizData[_currentIndex]['answer'];
    if (option == correctAnswer) return Icons.check_circle;
    if (option == _selectedAnswer && option != correctAnswer) return Icons.cancel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final currentQuestion = widget.quizData[_currentIndex];
    final totalQuestions = widget.quizData.length;
    final progress = (_currentIndex + 1) / totalQuestions;
    final options = List<String>.from(currentQuestion['options'] ?? []);
    final explanation = (currentQuestion['explanation'] ?? '').toString();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.mutedText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: widget.isWeaknessDrill
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology_alt_rounded, color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Weakness Remediation Drill',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Text('Solo Practice', style: TextStyle(color: colors.mutedText, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.diamond_outlined, color: Colors.lightBlueAccent, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    '$_score',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1} of $totalQuestions',
                        style: TextStyle(color: colors.mutedText, fontSize: 15),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(color: colors.subtleText, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: currentQuestion['is_remediation'] == true
                            ? Colors.orangeAccent.withValues(alpha: 0.6)
                            : colors.border,
                        width: currentQuestion['is_remediation'] == true ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentQuestion['is_remediation'] == true) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.psychology_alt_rounded, color: Colors.orangeAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  '🎯 Weakness Reinforcement Point',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Text(
                          currentQuestion['question'] ?? 'No question text',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if ((currentQuestion['hint'] ?? '').toString().isNotEmpty)
                    TextButton.icon(
                      onPressed: _isAnswered
                          ? null
                          : () => setState(() => _showHint = !_showHint),
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text(_showHint ? 'Hide hint' : 'Show hint'),
                    ),
                  if (_showHint)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.25)),
                      ),
                      child: Text(
                        currentQuestion['hint'],
                        style: TextStyle(color: colors.mutedText, height: 1.5),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final answerIcon = _getAnswerIcon(option);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _isAnswered ? null : () => _submitAnswer(option),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _getButtonColor(option, colors.surfaceAlt),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _getBorderColor(option, colors.border),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  if (answerIcon != null) ...[
                                    const SizedBox(width: 12),
                                    Icon(answerIcon, color: Colors.white),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isAnswered && explanation.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this is correct',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            explanation,
                            style: TextStyle(color: colors.mutedText, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
