import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';
import 'automation_setup_screen.dart';

class AutomationHistoryScreen extends StatefulWidget {
  final String notebookId;
  final String courseName;
  final String userEmail;

  const AutomationHistoryScreen({
    super.key,
    required this.notebookId,
    required this.courseName,
    required this.userEmail,
  });

  @override
  State<AutomationHistoryScreen> createState() => _AutomationHistoryScreenState();
}

class _AutomationHistoryScreenState extends State<AutomationHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _automationData;
  List<dynamic> _weeklySchedule = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchAutomationHistory();
  }

  Future<void> _fetchAutomationHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        '$baseUrl/api/automations/${widget.notebookId}/history?user_email=${Uri.encodeComponent(widget.userEmail)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _automationData = data['automation'];
            _weeklySchedule = data['history'] ?? [];
            _stats = data['stats'] ?? {};
            _isLoading = false;
          });
          return;
        }
      }

      if (response.statusCode == 404) {
        setState(() {
          _automationData = null;
          _weeklySchedule = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = "Failed to load automation history (HTTP ${response.statusCode})";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Network or server error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _launchRevisionQuiz(int weekNumber, String topicTitle) async {
    List<dynamic> quizData = [];
    bool dialogShown = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      dialogShown = true;

      final uri = Uri.parse(
        '$baseUrl/api/automations/revision-quiz?notebook_id=${widget.notebookId}&week_number=$weekNumber',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));

      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body['success'] == true && body['quiz_data'] != null) {
          quizData = body['quiz_data'];
        }
      }
    } catch (e) {
      if (dialogShown && mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        dialogShown = false;
      }
      debugPrint("Quiz fetch error: $e");
    }

    if (quizData.isEmpty) {
      quizData = [
        {
          "question": "Scheduled Revision Quiz - Week $weekNumber: $topicTitle",
          "options": [
            "Mastering key principles of $topicTitle",
            "Skipping foundational review",
            "Outdated legacy concepts",
            "Unrelated theoretical notes"
          ],
          "answer": "Mastering key principles of $topicTitle",
          "hint": "Focus on core concepts for this week."
        }
      ];
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          quizData: quizData,
          notebookId: widget.notebookId,
          weekNumber: weekNumber,
          userEmail: widget.userEmail,
        ),
      ),
    );

      if (result != null && result is Map) {
        try {
          await http.post(
            Uri.parse('$baseUrl/api/automations/quiz-completed'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'notebook_id': widget.notebookId,
              'week_number': weekNumber,
              'user_email': widget.userEmail,
              'score': result['correct_answers'] ?? 0,
              'total_questions': result['total_questions'] ?? 2,
            }),
          );
        } catch (_) {}
      }

      // Refresh history upon return if quiz was completed
      _fetchAutomationHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error launching quiz: $e")),
      );
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  DateTime _parseDateTime(dynamic ts) {
    if (ts is DateTime) return ts.toLocal();
    String str = ts.toString().trim();
    if (!str.endsWith('Z') && !str.contains('+') && str.length >= 19) {
      str = '${str}Z';
    }
    return DateTime.parse(str).toLocal();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "N/A";
    try {
      final dt = _parseDateTime(ts);
      final dayName = _weekdays[(dt.weekday - 1).clamp(0, 6)];
      final monthName = _months[(dt.month - 1).clamp(0, 11)];
      final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$dayName, ${dt.day} $monthName ${dt.year} • $hour12:$minute $amPm';
    } catch (_) {
      return ts.toString();
    }
  }

  String _formatShortDate(dynamic ts) {
    if (ts == null) return "N/A";
    try {
      final dt = _parseDateTime(ts);
      final monthName = _months[(dt.month - 1).clamp(0, 11)];
      final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $monthName • $hour12:$minute $amPm';
    } catch (_) {
      return ts.toString();
    }
  }

  Future<void> _confirmDeleteAutomation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Delete Automation?"),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this syllabus automation schedule? All scheduled revision reminders for this course will be cancelled.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
        '$baseUrl/api/automations/${widget.notebookId}?user_email=${Uri.encodeComponent(widget.userEmail)}',
      );
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Automation record successfully deleted."),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAutomationHistory();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete automation (HTTP ${response.statusCode})"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting automation: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerDemoAlertNow() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$baseUrl/api/automations/${widget.notebookId}/trigger-now?user_email=${Uri.encodeComponent(widget.userEmail)}');
      final response = await http.post(uri);
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚡ ${data['message'] ?? 'Revision alert triggered and email sent!'}"),
            backgroundColor: Colors.purpleAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        _fetchAutomationHistory();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${data['error'] ?? 'Failed to trigger alert'}"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to trigger alert: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Automation & Revision History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.courseName,
              style: TextStyle(fontSize: 12, color: colors.mutedText),
            ),
          ],
        ),
        actions: [
          if (_automationData != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text("⚡ Trigger Alert Now", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _triggerDemoAlertNow,
            ),
          IconButton(
            tooltip: "Refresh History",
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAutomationHistory,
          ),
          if (_automationData != null)
            IconButton(
              tooltip: "Delete Automation",
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDeleteAutomation,
            ),
        ],
      ),
      body: _buildBody(colors, scheme),
    );
  }

  Widget _buildBody(AppColors colors, ColorScheme scheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchAutomationHistory,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    if (_automationData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 64, color: colors.mutedText),
              const SizedBox(height: 16),
              Text(
                "No Active Automation Found",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Configure your syllabus PDF and weekly class timetable to enable automated revision reminders and history tracking.",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedText),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AutomationSetupScreen(
                        notebookId: widget.notebookId,
                        initialCourseName: widget.courseName,
                        userEmail: widget.userEmail,
                      ),
                    ),
                  );
                  _fetchAutomationHistory();
                },
                icon: const Icon(Icons.add_task),
                label: const Text("Setup Automation Engine"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              )
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAutomationHistory,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProgressCard(colors, scheme),
          const SizedBox(height: 20),
          _buildOverviewCard(colors, scheme),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Revision Timeline",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_weeklySchedule.length} Weeks",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._weeklySchedule.map((item) => _buildTimelineItem(item, colors, scheme)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressCard(AppColors colors, ColorScheme scheme) {
    final double progress = (_stats['progress_percentage'] ?? 0.0).toDouble();
    final int completedCount = _stats['completed_weeks_count'] ?? 0;
    final int totalWeeks = _stats['total_weeks'] ?? _weeklySchedule.length;
    final nextTrigger = _stats['next_scheduled_trigger'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.2),
            scheme.secondary.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withOpacity(0.3)),
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
                    "Semester Progress",
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${progress.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "$completedCount / $totalWeeks Completed",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: colors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          if (nextTrigger != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Next Revision Trigger:",
                          style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatTimestamp(nextTrigger),
                          style: TextStyle(fontSize: 13, color: scheme.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(AppColors colors, ColorScheme scheme) {
    final timetable = _automationData?['timetable'] ?? {};
    final semConfig = _automationData?['semester_config'] ?? {};
    final subCal = _automationData?['sub_calendar_details'] ?? {};

    final day = timetable['day_of_week'] ?? 'Monday';
    final startTime = timetable['class_start_time'] ?? '09:00';
    final endTime = timetable['class_end_time'] ?? '11:00';
    final primaryReminder = timetable['primary_reminder_time'] ?? '18:00';
    final enableEve = timetable['enable_evening_reminder'] == true || timetable['enable_evening_reminder'] == null;
    final eveReminder = timetable['evening_reminder_time'] ?? '21:00';
    final startDate = semConfig['start_date'] ?? 'N/A';
    final hasBreak = semConfig['has_break_week'] == true;
    final calendarName = subCal['calendar_name'] ?? 'Note2Quiz Calendar';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                "Course & Timetable Config",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildConfigChip(Icons.calendar_today, "$day $startTime - $endTime", colors),
              _buildConfigChip(Icons.notifications_active, "1st Alert: $primaryReminder", colors),
              if (enableEve) _buildConfigChip(Icons.nightlight_round, "2nd Evening Alert: $eveReminder", colors),
              _buildConfigChip(Icons.play_circle_outline, "Start: $startDate", colors),
              if (hasBreak) _buildConfigChip(Icons.beach_access, "Mid-Term Break (W6)", colors),
              _buildConfigChip(Icons.event_available, calendarName, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigChip(IconData icon, String label, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.mutedText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.mutedText, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, AppColors colors, ColorScheme scheme) {
    final int weekNum = item['week_number'] ?? 1;
    final String topicTitle = item['topic_title'] ?? "Topic";
    final List<dynamic> keyConcepts = item['key_concepts'] ?? [];
    final String status = (item['status'] ?? 'PENDING').toString().toUpperCase();
    final triggerTs = item['primary_trigger_timestamp'] ?? item['actual_trigger_timestamp'] ?? item['revision_trigger_timestamp'];
    final eveTriggerTs = item['evening_trigger_timestamp'];
    final enableEve = item['enable_evening_reminder'] == true;
    final emailSentAt = item['email_dispatched_at'] ?? item['notification_sent_at'];
    final eveSentAt = item['evening_dispatched_at'];
    final quizRecord = item['quiz_record'];
    final mastery = item['mastery'] as Map<String, dynamic>?;

    Color statusColor = Colors.amber;
    IconData statusIcon = Icons.access_time;
    String statusLabel = "Scheduled";

    if (status == "QUIZ_COMPLETED") {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
      statusLabel = "Completed";
    } else if (status == "REMINDER_SENT") {
      statusColor = const Color(0xFFA78BFA); // Purple
      statusIcon = Icons.mail_outline;
      statusLabel = "Email Sent";
    } else if (status == "PROCESSING") {
      statusColor = Colors.lightBlueAccent;
      statusIcon = Icons.sync;
      statusLabel = "Processing";
    } else if (status == "FAILED") {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline;
      statusLabel = "Failed";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == "QUIZ_COMPLETED"
              ? Colors.green.withOpacity(0.4)
              : (status == "REMINDER_SENT" ? const Color(0xFFA78BFA).withOpacity(0.4) : colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  "W$weekNum",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          topicTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (keyConcepts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: keyConcepts.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.toString(),
                          style: TextStyle(fontSize: 11, color: colors.mutedText),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Primary Reminder Time
                  Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 13, color: colors.mutedText),
                      const SizedBox(width: 4),
                      Text(
                        "1st Revision Alert: ${_formatShortDate(triggerTs)}",
                        style: TextStyle(fontSize: 12, color: colors.mutedText),
                      ),
                    ],
                  ),
                  // Evening Reminder Time (if enabled)
                  if (enableEve && eveTriggerTs != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.nightlight_round, size: 13, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 4),
                        Text(
                          "2nd Evening Follow-up: ${_formatShortDate(eveTriggerTs)}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFFA78BFA)),
                        ),
                      ],
                    ),
                  ],
                  if (emailSentAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read_outlined, size: 13, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 4),
                        Text(
                          "1st Email Dispatched: ${_formatShortDate(emailSentAt)}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFFA78BFA)),
                        ),
                      ],
                    ),
                  ],
                  if (eveSentAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read, size: 13, color: Colors.indigoAccent),
                        const SizedBox(width: 4),
                        Text(
                          "Evening Follow-up Dispatched: ${_formatShortDate(eveSentAt)}",
                          style: const TextStyle(fontSize: 12, color: Colors.indigoAccent),
                        ),
                      ],
                    ),
                  ],
                  if (quizRecord != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Quiz Score: ${quizRecord['score']} / ${quizRecord['total_questions'] ?? 5} points",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mastery != null && (mastery['mastery_score'] ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.psychology_rounded, size: 14, color: Colors.purpleAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'SM-2 Retention: ${mastery['mastery_score']}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: (mastery['mastery_score'] ?? 0) >= 80
                                            ? Colors.greenAccent
                                            : ((mastery['mastery_score'] ?? 0) >= 50 ? Colors.amberAccent : Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${mastery['status_label'] ?? ''} (${mastery['decay_days'] ?? 0}d ago)',
                                  style: TextStyle(fontSize: 11, color: colors.subtleText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: ((mastery['mastery_score'] ?? 0) / 100.0).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: colors.border,
                                valueColor: AlwaysStoppedAnimation(
                                  (mastery['mastery_score'] ?? 0) >= 80
                                      ? Colors.greenAccent
                                      : ((mastery['mastery_score'] ?? 0) >= 50 ? Colors.amberAccent : Colors.redAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  // Action button
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchRevisionQuiz(weekNum, topicTitle),
                      icon: Icon(
                        status == "QUIZ_COMPLETED" ? Icons.replay : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(
                        status == "QUIZ_COMPLETED" ? "Retake Quiz" : "Take Quiz",
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
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
  }
}
