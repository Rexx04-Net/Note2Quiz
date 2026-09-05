import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _streak = 0;
  int _correctAnswers = 0;
  String _selectedAnswer = '';
  bool _isAnswered = false;
  bool _showHint = false;
  bool _autoAdvance = false;
  Timer? _autoAdvanceTimer;
  final List<Map<String, dynamic>> _userAnswers = [];
  Future<void>? _savingFuture;

  @override
  void initState() {
    super.initState();
    for (var q in widget.quizData) {
      if (q is Map && q['options'] is List) {
        (q['options'] as List).shuffle();
      }
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
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
        _streak++;
        _correctAnswers++;
      } else {
        _streak = 0;
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

    if (_autoAdvance) {
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) _nextQuestion();
      });
    }
  }

  void _nextQuestion() {
    _autoAdvanceTimer?.cancel();
    if (_currentIndex < widget.quizData.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedAnswer = '';
        _showHint = false;
      });
    } else {
      _showResultsDialog();
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
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
    } catch (e) {
      debugPrint('Error saving quiz result: $e');
    }
  }

  void _showResultsDialog() {
    final total = widget.quizData.length;
    final percent = total > 0 ? ((_correctAnswers / total) * 100).round() : 0;
    _savingFuture = _saveQuizResult(percent, total);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colors = ctx.appColors;
        final scheme = Theme.of(ctx).colorScheme;
        final isPassed = percent >= 70;

        return Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.cardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPassed ? colors.successSoft : colors.warningSoft,
                    ),
                    child: Icon(
                      isPassed ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                      color: isPassed ? colors.success : colors.warning,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isPassed ? 'Outstanding Job!' : 'Session Complete!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPassed
                        ? 'You mastered the core concepts of this material.'
                        : 'Review your weak points below to cement knowledge.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Score', '$_score', scheme.primary),
                        Container(width: 1, height: 32, color: colors.border),
                        _buildStatColumn('Accuracy', '$percent%', isPassed ? colors.success : colors.warning),
                        Container(width: 1, height: 32, color: colors.border),
                        _buildStatColumn('Correct', '$_correctAnswers/$total', scheme.onSurface),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _restartQuiz();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: colors.border),
                          ),
                          child: const Text('Retry Session', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizReviewScreen(
                                  quizData: widget.quizData,
                                  breakdown: _userAnswers,
                                  score: _score,
                                  correctAnswers: _correctAnswers,
                                  totalQuestions: total,
                                  percentage: percent,
                                  notebookId: widget.notebookId,
                                  quizTitle: widget.isWeaknessDrill ? '🎯 Weakness Drill' : 'Solo Practice',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: colors.border),
                          ),
                          child: const Text('Review Mistakes', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                    SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        if (_savingFuture != null) await _savingFuture;
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        nav.pop({
                          'completed': percent >= 70,
                          'percentage': percent,
                          'score': _score,
                          'correct_answers': _correctAnswers,
                          'total_questions': total,
                          'user_answers': _userAnswers,
                          'quiz_data': widget.quizData,
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Finish & Return', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Color _getOptionBackground(String option, BuildContext context) {
    final colors = context.appColors;
    if (!_isAnswered) return colors.surface;

    final correctAnswer = widget.quizData[_currentIndex]['answer'];
    if (option == correctAnswer) {
      return colors.successSoft;
    }
    if (option == _selectedAnswer && option != correctAnswer) {
      return colors.errorSoft;
    }
    return colors.surface.withValues(alpha: 0.5);
  }

  Color _getOptionBorder(String option, BuildContext context) {
    final colors = context.appColors;
    if (!_isAnswered) return colors.cardBorder;

    final correctAnswer = widget.quizData[_currentIndex]['answer'];
    if (option == correctAnswer) {
      return colors.success;
    }
    if (option == _selectedAnswer && option != correctAnswer) {
      return colors.error;
    }
    return colors.border.withValues(alpha: 0.3);
  }

  IconData? _getAnswerIcon(String option) {
    if (!_isAnswered) return null;
    final correctAnswer = widget.quizData[_currentIndex]['answer'];
    if (option == correctAnswer) return Icons.check_circle_rounded;
    if (option == _selectedAnswer && option != correctAnswer) return Icons.cancel_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final currentQuestion = widget.quizData[_currentIndex];
    final totalQuestions = widget.quizData.length;
    final progress = totalQuestions > 0 ? (_currentIndex + 1) / totalQuestions : 0.0;
    final options = List<String>.from(currentQuestion['options'] ?? []);
    final explanation = (currentQuestion['explanation'] ?? '').toString();
    final isRemediation = currentQuestion['is_remediation'] == true;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.mutedText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: widget.isWeaknessDrill
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.warningSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_rounded, color: colors.warning, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Adaptive Weakness Drill',
                      style: TextStyle(color: colors.warning, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Text(
                'Active Recall Practice',
                style: GoogleFonts.plusJakartaSans(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          // Streak indicator
          if (_streak > 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                  ),
                ],
              ),
            ),

          // Score Badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: scheme.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: TextStyle(color: scheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Bar & Question Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUESTION ${_currentIndex + 1} OF $totalQuestions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: colors.mutedText,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}% Completed',
                        style: TextStyle(color: colors.subtleText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isRemediation ? colors.warning.withValues(alpha: 0.5) : colors.cardBorder,
                        width: isRemediation ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRemediation) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.warningSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, color: colors.warning, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Adaptive Recall: Reviewing past mistake',
                                  style: TextStyle(
                                    color: colors.warning,
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
                          style: GoogleFonts.plusJakartaSans(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hint Button / Accordion
                  if ((currentQuestion['hint'] ?? '').toString().isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isAnswered ? null : () => setState(() => _showHint = !_showHint),
                        icon: Icon(Icons.lightbulb_outline_rounded, size: 16, color: colors.warning),
                        label: Text(
                          _showHint ? 'Hide Hint' : 'Need a Hint?',
                          style: TextStyle(color: colors.warning, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (_showHint)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.warningSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          currentQuestion['hint'],
                          style: TextStyle(color: scheme.onSurface, fontSize: 13, height: 1.45),
                        ),
                      ),
                  ] else
                    const SizedBox(height: 12),

                  // Options List
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: options.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final answerIcon = _getAnswerIcon(option);
                        final optionLetter = String.fromCharCode(65 + index); // A, B, C, D

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _isAnswered ? null : () => _submitAnswer(option),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: _getOptionBackground(option, context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _getOptionBorder(option, context),
                                  width: _isAnswered && (option == currentQuestion['answer'] || option == _selectedAnswer)
                                      ? 2.0
                                      : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.surfaceAlt,
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Center(
                                      child: Text(
                                        optionLetter,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: colors.mutedText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: scheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  if (answerIcon != null) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      answerIcon,
                                      color: option == currentQuestion['answer'] ? colors.success : colors.error,
                                      size: 22,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Answer Explanation & Self-Paced Continue Action
                  if (_isAnswered)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (explanation.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: scheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Key Takeaway & Explanation',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              explanation,
                              style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.45),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _nextQuestion,
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: Text(
                                _currentIndex < totalQuestions - 1 ? 'Next Question' : 'View Quiz Summary',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
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
