import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  final List<dynamic> quizData;

  const QuizScreen({super.key, required this.quizData});

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
    });
  }

  void _showResultsDialog() {
    final total = widget.quizData.length;
    final percent = total == 0 ? 0 : ((_correctAnswers / total) * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Practice complete',
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
              child: Text(
                percent >= 80
                    ? 'Strong work. You have a good grasp of this topic.'
                    : percent >= 50
                        ? 'Decent progress. Review the weak areas and try again.'
                        : 'You should revisit the source material and retry this quiz.',
                style: TextStyle(color: context.appColors.mutedText, height: 1.5),
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
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Finish'),
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
        title: Text('Solo Practice', style: TextStyle(color: colors.mutedText, fontSize: 16)),
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
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      currentQuestion['question'] ?? 'No question text',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
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
