import 'dart:async';
import 'package:flutter/material.dart';

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
        backgroundColor: const Color(0xFF232334),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Practice complete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score: $_score points',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Correct: $_correctAnswers / $total',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: $percent%',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                percent >= 80
                    ? 'Strong work. You have a good grasp of this topic.'
                    : percent >= 50
                        ? 'Decent progress. Review the weak areas and try again.'
                        : 'You should revisit the source material and retry this quiz.',
                style: const TextStyle(color: Colors.white70, height: 1.5),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor(String option) {
    if (!_isAnswered) return const Color(0xFF232334);

    final correctAnswer = widget.quizData[_currentIndex]['answer'];

    if (option == correctAnswer) {
      return Colors.green.withOpacity(0.85);
    }
    if (option == _selectedAnswer && option != correctAnswer) {
      return Colors.redAccent.withOpacity(0.85);
    }
    return const Color(0xFF232334).withOpacity(0.45);
  }

  Color _getBorderColor(String option) {
    if (!_isAnswered) return Colors.white10;
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
    final currentQuestion = widget.quizData[_currentIndex];
    final totalQuestions = widget.quizData.length;
    final progress = (_currentIndex + 1) / totalQuestions;
    final options = List<String>.from(currentQuestion['options'] ?? []);
    final explanation = (currentQuestion['explanation'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Solo Practice', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A26),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      currentQuestion['question'] ?? 'No question text',
                      style: const TextStyle(
                        color: Colors.white,
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
                        style: const TextStyle(color: Colors.white70, height: 1.5),
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
                                color: _getButtonColor(option),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _getBorderColor(option), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        color: Colors.white,
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
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Why this is correct',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            explanation,
                            style: const TextStyle(color: Colors.white70, height: 1.5),
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