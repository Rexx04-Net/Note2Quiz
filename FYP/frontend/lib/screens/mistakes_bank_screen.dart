import 'dart:convert';
import 'package:flutter/material.dart';
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
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('AI generating tailored weakness drill...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/generate-weakness-drill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notebook_id': notebookId,
          'user_email': widget.userEmail ?? 'guest',
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['quiz'] != null) {
          final List<dynamic> questions = data['quiz'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                quizData: questions,
                notebookId: notebookId,
                userEmail: widget.userEmail,
                isWeaknessDrill: true,
              ),
            ),
          ).then((_) => _fetchMistakes());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Could not generate weakness drill.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${res.statusCode}')),
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
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.track_changes_rounded, color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              'Mistakes Bank & Remediation',
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$_totalMistakes Total',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchMistakes,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 12),
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
            ElevatedButton(
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
              ),
              const SizedBox(height: 20),
              Text(
                '🎉 No Mistakes Recorded!',
                style: TextStyle(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You have mastered all attempted quizzes, or have not taken any quizzes yet.\nTake regular quizzes to automatically log weak concepts here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedText, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: scheme.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search questions, concepts, or answers...',
                        hintStyle: TextStyle(color: colors.subtleText, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText, size: 20),
                        filled: true,
                        fillColor: colors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Course Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All Courses ($_totalMistakes)'),
                      selected: _selectedNotebookFilter == null,
                      onSelected: (selected) {
                        setState(() => _selectedNotebookFilter = null);
                      },
                      selectedColor: Colors.orangeAccent.withValues(alpha: 0.2),
                      checkmarkColor: Colors.orangeAccent,
                      labelStyle: TextStyle(
                        color: _selectedNotebookFilter == null ? Colors.orangeAccent : colors.mutedText,
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
                        child: FilterChip(
                          label: Text('$shortLabel ($count)'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedNotebookFilter = selected ? nbId : null;
                            });
                          },
                          selectedColor: Colors.orangeAccent.withValues(alpha: 0.2),
                          checkmarkColor: Colors.orangeAccent,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.orangeAccent : colors.mutedText,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
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
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bookmark_border_rounded, color: Colors.orangeAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseName,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                      backgroundColor: Colors.orangeAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Weakness Drill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
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
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: mistakes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(16),
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
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User's Wrong Answer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Your Answer: ',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: userAns.toString(),
                          style: const TextStyle(
                            color: Colors.redAccent,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Correct Concept: ',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation,
                      style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.4),
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
