import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

class MistakesBankScreen extends StatefulWidget {
  final String? userEmail;
  final String? initialNotebookId;

  const MistakesBankScreen({
    super.key,
    this.userEmail,
    this.initialNotebookId,
  });

  @override
  State<MistakesBankScreen> createState() => _MistakesBankScreenState();
}

class _MistakesBankScreenState extends State<MistakesBankScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _courses = [];
  int _totalMistakes = 0;

  String _searchQuery = '';
  String? _selectedNotebookFilter;

  // Track expanded courses
  final Set<String> _expandedCourses = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialNotebookId != null) {
      _selectedNotebookFilter = widget.initialNotebookId;
      _expandedCourses.add(widget.initialNotebookId!);
    }
    _fetchMistakes();
  }

  Future<void> _fetchMistakes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = widget.userEmail ?? '';
      final url = '$baseUrl/api/mistakes-bank/all?user_email=$email';
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final coursesList = data['courses'] as List<dynamic>? ?? [];
          setState(() {
            _courses = coursesList;
            _totalMistakes = data['total_mistakes'] ?? 0;
            _isLoading = false;

            // Expand all by default
            for (final c in coursesList) {
              final id = c['notebook_id']?.toString() ?? '';
              if (id.isNotEmpty) _expandedCourses.add(id);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load: status ${res.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error connecting to server: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchWeaknessDrill(String notebookId, String courseName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 18),
                Text(
                  'AI generating tailored weakness drill...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Selecting questions targeting your specific error patterns',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final email = widget.userEmail ?? '';
      final url = '$baseUrl/api/mistakes-bank/generate-drill';
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': email,
          'notebook_id': notebookId,
          'num_questions': 5,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final questions = (data['drill_questions'] ?? data['data']) as List<dynamic>? ?? [];

        if (questions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active questions generated for this course yet.')),
          );
          return;
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizScreen(
              quizData: questions,
              notebookId: notebookId,
              userEmail: widget.userEmail,
              isWeaknessDrill: true,
            ),
          ),
        );

        if (result != null && mounted) {
          _fetchMistakes();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate drill: status ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch drill: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // Filter courses and questions
    final filteredCourses = _courses.where((c) {
      final nbId = c['notebook_id']?.toString() ?? '';
      if (_selectedNotebookFilter != null && nbId != _selectedNotebookFilter) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) return true;

      final courseName = (c['course_name'] ?? '').toString().toLowerCase();
      if (courseName.contains(_searchQuery.toLowerCase())) return true;

      final mistakes = c['mistakes'] as List<dynamic>? ?? [];
      return mistakes.any((m) {
        final q = (m['question'] ?? '').toString().toLowerCase();
        final expl = (m['explanation'] ?? '').toString().toLowerCase();
        final correct = (m['correct_answer'] ?? '').toString().toLowerCase();
        final userAns = (m['user_answer'] ?? '').toString().toLowerCase();
        final qSearch = _searchQuery.toLowerCase();
        return q.contains(qSearch) || expl.contains(qSearch) || correct.contains(qSearch) || userAns.contains(qSearch);
      });
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mistakes Bank & Remediation',
          style: GoogleFonts.plusJakartaSans(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchMistakes,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(filteredCourses),
    );
  }

  Widget _buildErrorView() {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 14),
            Text(_errorMessage ?? 'An error occurred', style: TextStyle(color: colors.mutedText)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _fetchMistakes,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(List<dynamic> filteredCourses) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded, color: colors.success, size: 64),
              ),
              const SizedBox(height: 20),
              Text(
                'Zero Weaknesses Detected!',
                style: GoogleFonts.plusJakartaSans(
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  'Great job! You have conquered all attempted practice questions. As you complete more quizzes, questions answered incorrectly will automatically be cataloged here for targeted spaced repetition.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.mutedText, fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Adaptive Learning Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.warningSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.psychology_rounded, color: colors.warning, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adaptive Spaced Repetition',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalMistakes concepts currently queued for reinforcement across ${_courses.length} courses.',
                            style: TextStyle(color: colors.mutedText, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Search & Filter
              TextField(
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search mistake questions, concepts, or terms...',
                  prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText, size: 20),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 14),

              // Course Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All Courses ($_totalMistakes)'),
                      selected: _selectedNotebookFilter == null,
                      onSelected: (selected) {
                        setState(() => _selectedNotebookFilter = null);
                      },
                      selectedColor: colors.primarySoft,
                      labelStyle: TextStyle(
                        color: _selectedNotebookFilter == null ? scheme.primary : colors.mutedText,
                        fontWeight: _selectedNotebookFilter == null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._courses.map((c) {
                      final nbId = c['notebook_id']?.toString() ?? '';
                      final cName = c['course_name']?.toString() ?? 'Course';
                      final count = c['mistakes_count'] ?? 0;
                      final isSelected = _selectedNotebookFilter == nbId;
                      final shortLabel = cName.split('-')[0].trim();

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$shortLabel ($count)'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedNotebookFilter = selected ? nbId : null;
                            });
                          },
                          selectedColor: colors.primarySoft,
                          labelStyle: TextStyle(
                            color: isSelected ? scheme.primary : colors.mutedText,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Courses Mistakes List
              if (filteredCourses.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No mistakes matched your search filter.', style: TextStyle(color: colors.mutedText)),
                  ),
                )
              else
                ...filteredCourses.map((c) => _buildCourseAccordion(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseAccordion(Map<String, dynamic> course) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final nbId = course['notebook_id']?.toString() ?? '';
    final courseName = course['course_name']?.toString() ?? 'Course';
    final int mistakesCount = course['mistakes_count'] ?? 0;
    final List<dynamic> allMistakes = course['mistakes'] as List<dynamic>? ?? [];

    // Filter by search query if present
    final mistakes = allMistakes.where((m) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = (m['question'] ?? '').toString().toLowerCase();
      final expl = (m['explanation'] ?? '').toString().toLowerCase();
      final correct = (m['correct_answer'] ?? '').toString().toLowerCase();
      final userAns = (m['user_answer'] ?? '').toString().toLowerCase();
      final qSearch = _searchQuery.toLowerCase();
      return q.contains(qSearch) || expl.contains(qSearch) || correct.contains(qSearch) || userAns.contains(qSearch);
    }).toList();

    if (mistakes.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedCourses.contains(nbId);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(22),
              bottom: isExpanded ? Radius.zero : const Radius.circular(22),
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCourses.remove(nbId);
                } else {
                  _expandedCourses.add(nbId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.warningSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.bookmark_outline_rounded, color: colors.warning, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseName,
                          style: GoogleFonts.plusJakartaSans(
                            color: scheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$mistakesCount recorded mistakes',
                          style: TextStyle(color: colors.mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _launchWeaknessDrill(nbId, courseName),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.warning,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Practice Drill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: colors.mutedText,
                  ),
                ],
              ),
            ),
          ),

          // Mistakes List
          if (isExpanded) ...[
            Divider(height: 1, color: colors.border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: mistakes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final m = mistakes[index] as Map<String, dynamic>;
                return _buildMistakeCard(m, index + 1);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMistakeCard(Map<String, dynamic> m, int index) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final question = m['question'] ?? 'Question';
    final userAns = m['user_answer'] ?? 'N/A';
    final correctAns = m['correct_answer'] ?? 'N/A';
    final explanation = m['explanation'] ?? '';
    final recordedAt = m['recorded_at'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.errorSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$index',
                  style: TextStyle(color: colors.error, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.plusJakartaSans(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User's Wrong Answer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.errorSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cancel_rounded, color: colors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Previous Mistake: ',
                          style: TextStyle(color: colors.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: userAns.toString(),
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Correct Answer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.successSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: colors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Correct Concept: ',
                          style: TextStyle(color: colors.success, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: correctAns.toString(),
                          style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Explanation / Concept
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: scheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation,
                      style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (recordedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Recorded: $recordedAt',
                style: TextStyle(color: colors.subtleText, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
