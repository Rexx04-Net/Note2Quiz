import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import 'mistakes_bank_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? userEmail;

  const AnalyticsScreen({super.key, this.userEmail});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _analyticsData;
  final Set<String> _selectedCourseFilters = {}; // Empty = "All Courses"
  String _radarLayerMode = 'all'; // 'all', 'automation', 'notebook'

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = widget.userEmail ?? '';
      final url = '$baseUrl/api/analytics/overview?user_email=$email';
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _analyticsData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Server returned status ${res.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to connect: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

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
            const Icon(Icons.insights_rounded, color: Colors.purpleAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              'Learning Analytics & Radar',
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAnalytics,
            tooltip: 'Refresh analytics',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(),
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
              onPressed: _fetchAnalytics,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    final data = _analyticsData ?? {};
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final int retentionIndex = data['overall_retention_index'] ?? 80;
    final int coursesCount = data['courses_count'] ?? 0;
    final int activeMistakes = data['total_active_mistakes'] ?? 0;
    final List<dynamic> radarList = data['radar_data'] ?? [];
    final List<dynamic> courses = data['courses'] ?? [];
    final Map<String, dynamic> diagnostic = data['diagnostic_insight'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top KPI Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Memory Retention',
                      value: '$retentionIndex%',
                      subtitle: 'SM-2 Ebbinghaus Index',
                      icon: Icons.psychology_rounded,
                      accentColor: retentionIndex >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Courses',
                      value: '$coursesCount',
                      subtitle: 'Enrolled Syllabi',
                      icon: Icons.auto_stories_rounded,
                      accentColor: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Mistakes Bank',
                      value: '$activeMistakes',
                      subtitle: 'Tap to view mistakes ➔',
                      icon: Icons.track_changes_rounded,
                      accentColor: activeMistakes > 0 ? Colors.orangeAccent : Colors.greenAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MistakesBankScreen(userEmail: widget.userEmail),
                          ),
                        ).then((_) => _fetchAnalytics());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // AI Diagnostic Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.2),
                      Colors.blue.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                diagnostic['title'] ?? 'AI Diagnostic Insight',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  diagnostic['retention_health'] ?? 'Optimal',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            diagnostic['summary'] ?? 'Consistent spaced reviews will keep memory retention above 80%.',
                            style: TextStyle(color: colors.mutedText, fontSize: 13, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Section: Radar Chart + Course Breakdown
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 750;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildRadarCard(radarList, courses)),
                            const SizedBox(width: 20),
                            Expanded(flex: 6, child: _buildCourseBreakdownCard(courses)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRadarCard(radarList, courses),
                            const SizedBox(height: 20),
                            _buildCourseBreakdownCard(courses),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: onTap != null ? accentColor.withValues(alpha: 0.4) : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(color: colors.mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                  Icon(icon, color: accentColor, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: TextStyle(color: scheme.onSurface, fontSize: 26, fontWeight: FontWeight.bold)),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 14),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: colors.subtleText, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarCard(List<dynamic> allRadarList, List<dynamic> courses) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // Determine current active radar dataset
    List<dynamic> activeRadarList = allRadarList;
    String activeTitle = 'Skill Mastery Radar';
    String activeSubtitle = 'Multi-dimensional retention across all active courses';

    if (_selectedCourseFilters.isEmpty) {
      activeRadarList = allRadarList;
      activeTitle = 'Skill Mastery Radar (All Courses)';
      activeSubtitle = 'Multi-dimensional retention across all enrolled courses';
    } else if (_selectedCourseFilters.length == 1) {
      final targetId = _selectedCourseFilters.first;
      final selectedCourse = courses.firstWhere(
        (c) => c['notebook_id']?.toString() == targetId,
        orElse: () => null,
      );

      if (selectedCourse != null) {
        final cName = (selectedCourse['course_name'] ?? 'Course').toString();
        final shortName = cName.split('-')[0].trim();
        activeTitle = 'Chapter Mastery: $shortName';
        activeSubtitle = 'Topic & chapter-level retention for $shortName';
        final topicRadar = selectedCourse['topic_radar'] as List<dynamic>?;
        if (topicRadar != null && topicRadar.isNotEmpty) {
          activeRadarList = topicRadar;
        }
      }
    } else {
      // Multi-selection (>= 2 courses selected, e.g. UCCB1013 and UCCD1024)
      final selectedCourses = courses.where(
        (c) => _selectedCourseFilters.contains(c['notebook_id']?.toString()),
      ).toList();

      final shortNames = selectedCourses.map((c) => (c['course_name'] ?? '').toString().split('-')[0].trim()).toList();
      activeTitle = 'Comparison: ${shortNames.join(' vs ')}';
      activeSubtitle = 'Comparative retention across ${_selectedCourseFilters.length} selected courses';

      if (selectedCourses.length == 2) {
        // Build 4-vertex comparison diamond using each course and its highest topic
        final List<Map<String, dynamic>> comparisonData = [];
        for (final c in selectedCourses) {
          final sName = (c['course_name'] ?? '').toString().split('-')[0].trim();
          comparisonData.add({
            'subject': '$sName (Overall)',
            'full_name': c['course_name'],
            'score': c['overall_mastery'] ?? 0,
            'fullMark': 100,
          });
          final tRadar = c['topic_radar'] as List<dynamic>?;
          if (tRadar != null && tRadar.isNotEmpty) {
            final topTopic = tRadar[0];
            comparisonData.add({
              'subject': '$sName: ${topTopic['subject'] ?? 'Key Topic'}',
              'full_name': topTopic['full_name'],
              'score': topTopic['score'] ?? 0,
              'fullMark': 100,
            });
          } else {
            comparisonData.add({
              'subject': '$sName (Key)',
              'full_name': '$sName Key Concept',
              'score': c['overall_mastery'] ?? 0,
              'fullMark': 100,
            });
          }
        }
        activeRadarList = comparisonData;
      } else {
        // >= 3 courses selected
        activeRadarList = selectedCourses.map((c) {
          final sName = (c['course_name'] ?? '').toString().split('-')[0].trim();
          return {
            'subject': sName,
            'full_name': c['course_name'],
            'score': c['overall_mastery'] ?? 0,
            'fullMark': 100,
          };
        }).toList();
      }
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeTitle,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent, size: 22),
                tooltip: 'Expand Fullscreen Radar & Breakdown',
                onPressed: () => _showExpandedRadarDialog(
                  context: context,
                  activeRadarList: activeRadarList,
                  activeTitle: activeTitle,
                  activeSubtitle: activeSubtitle,
                  courses: courses,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            activeSubtitle,
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Horizontal Multi-Select Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Courses'),
                  selected: _selectedCourseFilters.isEmpty,
                  onSelected: (selected) {
                    setState(() => _selectedCourseFilters.clear());
                  },
                  selectedColor: Colors.purpleAccent.withValues(alpha: 0.25),
                  checkmarkColor: Colors.purpleAccent,
                  labelStyle: TextStyle(
                    color: _selectedCourseFilters.isEmpty ? Colors.purpleAccent : colors.mutedText,
                    fontWeight: _selectedCourseFilters.isEmpty ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                ...courses.map((c) {
                  final nbId = c['notebook_id']?.toString() ?? '';
                  final cName = (c['course_name'] ?? 'Course').toString();
                  final shortName = cName.split('-')[0].trim();
                  final isSelected = _selectedCourseFilters.contains(nbId);

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(shortName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCourseFilters.add(nbId);
                          } else {
                            _selectedCourseFilters.remove(nbId);
                          }
                        });
                      },
                      selectedColor: Colors.purpleAccent.withValues(alpha: 0.25),
                      checkmarkColor: Colors.purpleAccent,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.purpleAccent : colors.mutedText,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dual-Track Layer Legend & Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                // Automation Legend
                InkWell(
                  onTap: () => setState(() => _radarLayerMode = _radarLayerMode == 'automation' ? 'all' : 'automation'),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Scheduled Auto',
                        style: TextStyle(
                          color: _radarLayerMode == 'automation' || _radarLayerMode == 'all' ? Colors.white : colors.mutedText,
                          fontSize: 11,
                          fontWeight: _radarLayerMode == 'automation' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Notebook Legend
                InkWell(
                  onTap: () => setState(() => _radarLayerMode = _radarLayerMode == 'notebook' ? 'all' : 'notebook'),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Notebook Study',
                        style: TextStyle(
                          color: _radarLayerMode == 'notebook' || _radarLayerMode == 'all' ? Colors.white : colors.mutedText,
                          fontSize: 11,
                          fontWeight: _radarLayerMode == 'notebook' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_radarLayerMode != 'all')
                  GestureDetector(
                    onTap: () => setState(() => _radarLayerMode = 'all'),
                    child: Text('Reset Dual', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animated Radar View or Two-Course Side-by-Side Comparison
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim), child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey('${_selectedCourseFilters.join('_')}_$_radarLayerMode'),
                child: _selectedCourseFilters.length == 2
                    ? _buildTwoCourseComparisonView(courses)
                    : SizedBox(
                        width: 280,
                        height: 280,
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: SkillRadarPainter(
                            radarData: activeRadarList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                            accentColor: const Color(0xFF6C63FF),
                            secondaryAccentColor: Colors.orangeAccent,
                            gridColor: colors.border,
                            textColor: colors.mutedText,
                            layerMode: _radarLayerMode,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoCourseComparisonView(List<dynamic> courses) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final selected = courses.where((c) => _selectedCourseFilters.contains(c['notebook_id']?.toString())).toList();
    if (selected.length < 2) return const SizedBox.shrink();

    final c1 = selected[0] as Map<String, dynamic>;
    final c2 = selected[1] as Map<String, dynamic>;

    final name1 = (c1['course_name'] ?? 'Course 1').toString().split('-')[0].trim();
    final name2 = (c2['course_name'] ?? 'Course 2').toString().split('-')[0].trim();

    final m1 = c1['overall_mastery'] ?? 0;
    final m2 = c2['overall_mastery'] ?? 0;

    final w1 = '${c1['completed_weeks'] ?? 0}/${c1['total_weeks'] ?? 14} wks';
    final w2 = '${c2['completed_weeks'] ?? 0}/${c2['total_weeks'] ?? 14} wks';

    final mist1 = c1['mistakes_count'] ?? 0;
    final mist2 = c2['mistakes_count'] ?? 0;

    const color1 = Color(0xFF6C63FF);
    const color2 = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          // Head-to-head Top Badges
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color1.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color1.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(name1, style: const TextStyle(color: color1, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('$m1%', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 22)),
                      Text('$w1 | $mist1 err', style: TextStyle(color: colors.mutedText, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text('VS', style: TextStyle(color: colors.mutedText, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color2.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(name2, style: const TextStyle(color: color2, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('$m2%', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 22)),
                      Text('$w2 | $mist2 err', style: TextStyle(color: colors.mutedText, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Side-by-Side Metric Comparison Bars
          _buildComparisonRow(label: 'Overall Mastery', v1: m1, v2: m2, color1: color1, color2: color2),
          const SizedBox(height: 10),
          _buildComparisonRow(
            label: 'Scheduled Track',
            v1: c1['overall_mastery'] ?? 0,
            v2: c2['overall_mastery'] ?? 0,
            color1: color1,
            color2: color2,
          ),
          const SizedBox(height: 10),
          _buildComparisonRow(
            label: 'Study Roadmap',
            v1: (c1['quiz_results'] != null && (c1['quiz_results'] as List).isNotEmpty) ? 80 : 0,
            v2: (c2['quiz_results'] != null && (c2['quiz_results'] as List).isNotEmpty) ? 80 : 0,
            color1: color1,
            color2: color2,
          ),
          const SizedBox(height: 10),
          _buildComparisonRow(
            label: 'Syllabus Progress',
            v1: (((c1['completed_weeks'] ?? 0) / math.max(1, c1['total_weeks'] ?? 14)) * 100).round(),
            v2: (((c2['completed_weeks'] ?? 0) / math.max(1, c2['total_weeks'] ?? 14)) * 100).round(),
            color1: color1,
            color2: color2,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required int v1,
    required int v2,
    required Color color1,
    required Color color2,
  }) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$v1%', style: TextStyle(color: color1, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: colors.mutedText, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$v2%', style: TextStyle(color: color2, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Left progress bar (reversed from center)
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (v1 / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation(color1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 4, height: 6, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            // Right progress bar
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (v2 / 100.0).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation(color2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showExpandedRadarDialog({
    required BuildContext context,
    required List<dynamic> activeRadarList,
    required String activeTitle,
    required String activeSubtitle,
    required List<dynamic> courses,
  }) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: colors.border)),
              child: Container(
                width: math.min(MediaQuery.of(context).size.width * 0.92, 920),
                height: math.min(MediaQuery.of(context).size.height * 0.88, 760),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog Header
                    Row(
                      children: [
                        const Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeTitle,
                                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                              const SizedBox(height: 2),
                              Text(activeSubtitle, style: TextStyle(color: colors.mutedText, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dialog Content: Left Radar / 2-Course Board + Right Detailed Topic Breakdown
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Visual (Two-Course Comparison or Radar Chart)
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: _selectedCourseFilters.length == 2
                                  ? SingleChildScrollView(child: _buildTwoCourseComparisonView(courses))
                                  : SizedBox(
                                      width: 380,
                                      height: 380,
                                      child: CustomPaint(
                                        size: const Size(380, 380),
                                        painter: SkillRadarPainter(
                                          radarData: activeRadarList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                                          accentColor: const Color(0xFF6C63FF),
                                          secondaryAccentColor: Colors.orangeAccent,
                                          gridColor: colors.border,
                                          textColor: scheme.onSurface.withValues(alpha: 0.8),
                                          layerMode: _radarLayerMode,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Detailed Chapter Score Breakdown List
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Topic Breakdown (${activeRadarList.length})',
                                        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Row(
                                        children: [
                                          Container(width: 8, height: 8, color: const Color(0xFF6C63FF)),
                                          const SizedBox(width: 4),
                                          Text('Auto', style: TextStyle(color: colors.mutedText, fontSize: 10)),
                                          const SizedBox(width: 8),
                                          Container(width: 8, height: 8, color: Colors.orangeAccent),
                                          const SizedBox(width: 4),
                                          Text('Study', style: TextStyle(color: colors.mutedText, fontSize: 10)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: activeRadarList.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, idx) {
                                        final t = activeRadarList[idx] as Map<String, dynamic>;
                                        final fullName = t['full_name'] ?? t['subject'] ?? 'Topic';
                                        final autoScore = t['automation_score'] ?? t['score'] ?? 0;
                                        final nbScore = t['notebook_score'] ?? 0;

                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: colors.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      fullName,
                                                      style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Auto: $autoScore% | Study: $nbScore%',
                                                    style: TextStyle(color: colors.mutedText, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(99),
                                                child: LinearProgressIndicator(
                                                  value: (autoScore > 0 ? autoScore : nbScore) / 100.0,
                                                  minHeight: 4,
                                                  backgroundColor: colors.border,
                                                  valueColor: AlwaysStoppedAnimation(
                                                    autoScore > 0 ? const Color(0xFF6C63FF) : Colors.orangeAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCourseBreakdownCard(List<dynamic> courses) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Memory Retention Tracker',
                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Live topic decay based on days elapsed since last revision',
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No enrolled course automations yet.', style: TextStyle(color: colors.mutedText)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final c = courses[index] as Map<String, dynamic>;
                final int mastery = c['overall_mastery'] ?? 0;
                final String status = c['retention_status'] ?? 'Active';
                final int mistakes = c['mistakes_count'] ?? 0;

                final Color barColor = mastery >= 75
                    ? Colors.greenAccent
                    : (mastery >= 50 ? Colors.amberAccent : Colors.redAccent);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['course_name'] ?? 'Course',
                              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: barColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '$mastery% $status',
                              style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: mastery / 100.0,
                          minHeight: 6,
                          backgroundColor: colors.border,
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${c['completed_weeks'] ?? 0} weeks reviewed',
                            style: TextStyle(color: colors.subtleText, fontSize: 11),
                          ),
                          if (mistakes > 0)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MistakesBankScreen(
                                      userEmail: widget.userEmail,
                                      initialNotebookId: c['notebook_id']?.toString(),
                                    ),
                                  ),
                                ).then((_) => _fetchAnalytics());
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  '🎯 $mistakes weak points ➔',
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          else
                            Text(
                              '✨ 0 active mistakes',
                              style: TextStyle(color: colors.subtleText, fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class SkillRadarPainter extends CustomPainter {
  final List<Map<String, dynamic>> radarData;
  final Color accentColor;
  final Color? secondaryAccentColor;
  final Color gridColor;
  final Color textColor;
  final String layerMode; // 'all', 'automation', 'notebook'

  SkillRadarPainter({
    required this.radarData,
    required this.accentColor,
    this.secondaryAccentColor,
    required this.gridColor,
    required this.textColor,
    this.layerMode = 'all',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radarData.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 38;
    final int count = radarData.length;
    final angleStep = (math.pi * 2) / count;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric web polygons (4 levels: 25%, 50%, 75%, 100%)
    for (int level = 1; level <= 4; level++) {
      final currentRadius = radius * (level / 4);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + (i * angleStep);
        final x = center.dx + currentRadius * math.cos(angle);
        final y = center.dy + currentRadius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines from center to each vertex
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i * angleStep);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // Helper to draw a radar polygon for a given key
    void drawPolygonLayer(String key, Color color, double alpha) {
      final dataPath = Path();
      final dataPoints = <Offset>[];

      for (int i = 0; i < count; i++) {
        final item = radarData[i];
        final double score = (item[key] ?? item['score'] ?? 0).toDouble();
        final double fraction = (score / 100.0).clamp(0.08, 1.0);
        final currentRadius = radius * fraction;
        final angle = -math.pi / 2 + (i * angleStep);
        final point = Offset(
          center.dx + currentRadius * math.cos(angle),
          center.dy + currentRadius * math.sin(angle),
        );
        dataPoints.add(point);
        if (i == 0) {
          dataPath.moveTo(point.dx, point.dy);
        } else {
          dataPath.lineTo(point.dx, point.dy);
        }
      }
      dataPath.close();

      // Fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(dataPath, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawPath(dataPath, borderPaint);

      // Vertex dots
      final dotPaint = Paint()..color = Colors.white;
      for (final pt in dataPoints) {
        canvas.drawCircle(pt, 3.2, dotPaint);
        canvas.drawCircle(pt, 3.2, borderPaint);
      }
    }

    // Draw layers based on layerMode
    if (layerMode == 'automation') {
      drawPolygonLayer('automation_score', const Color(0xFF6C63FF), 0.35);
    } else if (layerMode == 'notebook') {
      drawPolygonLayer('notebook_score', Colors.orangeAccent, 0.35);
    } else {
      // Dual layers (draw Scheduled Automation in Purple + Notebook Practice in Orange)
      drawPolygonLayer('automation_score', const Color(0xFF6C63FF), 0.30);
      drawPolygonLayer('notebook_score', Colors.orangeAccent, 0.25);
    }

    // Draw text labels around the polygon
    for (int i = 0; i < count; i++) {
      final item = radarData[i];
      final label = item['subject'] ?? '';
      final autoScore = item['automation_score'] ?? item['score'] ?? 0;
      final nbScore = item['notebook_score'] ?? 0;
      final angle = -math.pi / 2 + (i * angleStep);
      final labelRadius = radius + 24;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);

      final String scoreText = layerMode == 'automation'
          ? '$autoScore%'
          : (layerMode == 'notebook' ? '$nbScore%' : '${math.max(autoScore, nbScore)}%');

      final textSpan = TextSpan(
        text: '$label\n$scoreText',
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        lx - (textPainter.width / 2),
        ly - (textPainter.height / 2),
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant SkillRadarPainter oldDelegate) => true;
}
