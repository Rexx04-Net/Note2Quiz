import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

class QuizReviewScreen extends StatefulWidget {
  final List<dynamic> quizData;
  final List<dynamic>? breakdown;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final String? playedAt;
  final String? notebookId;
  final String? quizTitle;

  const QuizReviewScreen({
    super.key,
    required this.quizData,
    this.breakdown,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    this.playedAt,
    this.notebookId,
    this.quizTitle,
  });

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  String _selectedFilter = 'all'; // 'all', 'incorrect', 'correct'

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final total = widget.totalQuestions > 0
        ? widget.totalQuestions
        : (widget.quizData.isNotEmpty ? widget.quizData.length : 1);
    final percent = widget.percentage;
    final scoreColor = percent >= 80
        ? Colors.greenAccent
        : percent >= 50
            ? Colors.orangeAccent
            : Colors.redAccent;

    // Build unified question review items
    final List<Map<String, dynamic>> items = [];
    final hasBreakdown = widget.breakdown != null && widget.breakdown!.isNotEmpty;
    final totalCount = widget.quizData.length > (widget.breakdown?.length ?? 0)
        ? widget.quizData.length
        : (widget.breakdown?.length ?? 0);

    for (int i = 0; i < totalCount; i++) {
      final qData = (i < widget.quizData.length ? widget.quizData[i] : null) as Map<String, dynamic>? ?? {};
      Map<String, dynamic>? bData;
      if (hasBreakdown && i < widget.breakdown!.length) {
        bData = widget.breakdown![i] as Map<String, dynamic>?;
      }

      final questionText = bData?['question'] ?? qData['question'] ?? 'Question ${i + 1}';
      final options = List<String>.from(bData?['options'] ?? qData['options'] ?? []);
      final correctAnswer = (bData?['correct_answer'] ?? qData['answer'] ?? '').toString();
      final selectedAnswer = (bData?['selected_answer'] ?? '').toString();
      final isAnswered = selectedAnswer.isNotEmpty;
      final isCorrect = bData?['is_correct'] ?? (isAnswered ? (selectedAnswer == correctAnswer) : null);
      final hint = (bData?['hint'] ?? qData['hint'] ?? '').toString();
      final explanation = (bData?['explanation'] ?? qData['explanation'] ?? '').toString();
      final isRemediation = bData?['is_remediation'] == true || qData['is_remediation'] == true;

      items.add({
        'index': i + 1,
        'question': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'selected_answer': selectedAnswer,
        'is_answered': isAnswered,
        'is_correct': isCorrect,
        'hint': hint,
        'explanation': explanation,
        'is_remediation': isRemediation,
      });
    }

    final incorrectCount = items.where((item) => item['is_correct'] == false).length;
    final correctCount = items.where((item) => item['is_correct'] == true).length;

    final filteredItems = items.where((item) {
      if (_selectedFilter == 'incorrect') {
        return item['is_correct'] == false;
      } else if (_selectedFilter == 'correct') {
        return item['is_correct'] == true;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.quizTitle ?? 'Quiz Review & Learning',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.playedAt != null && widget.playedAt!.isNotEmpty)
              Text(
                'Attempted: ${widget.playedAt}',
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (widget.quizData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        quizData: widget.quizData,
                        notebookId: widget.notebookId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Retake Quiz'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scoreColor.withOpacity(0.15),
                          border: Border.all(color: scoreColor, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Score: ${widget.score} pts (${widget.correctAnswers} / $total Correct)',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              percent >= 80
                                  ? 'Excellent understanding! Review questions and hints below to reinforce knowledge.'
                                  : percent >= 50
                                      ? 'Good progress! Check hints and explanations for missed questions to improve.'
                                      : 'Take time to study the hints and explanations below, then retake the quiz!',
                              style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Filter Buttons
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'All Questions (${items.length})',
                      value: 'all',
                      colors: colors,
                      scheme: scheme,
                    ),
                    const SizedBox(width: 10),
                    if (incorrectCount > 0) ...[
                      _buildFilterChip(
                        label: 'Incorrect ($incorrectCount)',
                        value: 'incorrect',
                        colors: colors,
                        scheme: scheme,
                        highlightColor: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (correctCount > 0) ...[
                      _buildFilterChip(
                        label: 'Correct ($correctCount)',
                        value: 'correct',
                        colors: colors,
                        scheme: scheme,
                        highlightColor: Colors.greenAccent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // Empty filter state
                if (filteredItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Text(
                      'No questions in this filter.',
                      style: TextStyle(color: colors.mutedText),
                    ),
                  ),

                // Question Review Cards
                ...filteredItems.map((item) => _buildQuestionCard(item, colors, scheme)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required dynamic colors,
    required ColorScheme scheme,
    Color? highlightColor,
  }) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? (highlightColor ?? scheme.onPrimary)
              : colors.mutedText,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: highlightColor != null
          ? highlightColor.withOpacity(0.2)
          : scheme.primary.withOpacity(0.3),
      backgroundColor: colors.surfaceAlt,
      side: BorderSide(
        color: isSelected
            ? (highlightColor ?? scheme.primary)
            : colors.border,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> item, dynamic colors, ColorScheme scheme) {
    final int index = item['index'];
    final String question = item['question'];
    final List<String> options = item['options'];
    final String correctAnswer = item['correct_answer'];
    final String selectedAnswer = item['selected_answer'];
    final bool? isCorrect = item['is_correct'];
    final String hint = item['hint'];
    final String explanation = item['explanation'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect == true
              ? Colors.green.withOpacity(0.4)
              : isCorrect == false
                  ? Colors.redAccent.withOpacity(0.4)
                  : colors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header & Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Q$index',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isCorrect == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Correct (+10 pts)',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isCorrect == false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Incorrect (0 pts)',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              if (item['is_remediation'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_alt_rounded, color: Colors.orangeAccent, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Weakness Reinforcement',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Question Text
          Text(
            question,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          ...options.map((opt) {
            final isUserChoice = opt == selectedAnswer;
            final isAnswerKey = opt == correctAnswer;

            Color optBg = colors.surfaceAlt;
            Color optBorder = colors.border;
            IconData? optIcon;
            Color? optIconColor;
            String? tag;
            Color? tagColor;

            if (isUserChoice && isAnswerKey) {
              // User chose correctly
              optBg = Colors.green.withOpacity(0.18);
              optBorder = Colors.greenAccent;
              optIcon = Icons.check_circle_rounded;
              optIconColor = Colors.greenAccent;
              tag = 'Your Answer (Correct)';
              tagColor = Colors.greenAccent;
            } else if (isUserChoice && !isAnswerKey) {
              // User chose incorrectly
              optBg = Colors.redAccent.withOpacity(0.18);
              optBorder = Colors.redAccent;
              optIcon = Icons.cancel_rounded;
              optIconColor = Colors.redAccent;
              tag = 'Your Answer';
              tagColor = Colors.redAccent;
            } else if (isAnswerKey) {
              // Correct answer
              optBg = Colors.green.withOpacity(0.12);
              optBorder = Colors.greenAccent.withOpacity(0.8);
              optIcon = Icons.check_circle_outline_rounded;
              optIconColor = Colors.greenAccent;
              tag = 'Correct Answer';
              tagColor = Colors.greenAccent;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: optBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: optBorder, width: isUserChoice || isAnswerKey ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  if (optIcon != null) ...[
                    Icon(optIcon, color: optIconColor, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: isUserChoice || isAnswerKey ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor?.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Hint Section (Learning Tool)
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Hint & Learning Clue',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],

          // Explanation Section
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: scheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Explanation',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
