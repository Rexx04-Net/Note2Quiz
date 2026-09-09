import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import 'automation_history_screen.dart';
import 'timetable_scanner_screen.dart';

class AutomationSetupScreen extends StatefulWidget {
  final String notebookId;
  final String initialCourseName;
  final String userEmail;

  const AutomationSetupScreen({
    super.key,
    required this.notebookId,
    required this.initialCourseName,
    required this.userEmail,
  });

  @override
  State<AutomationSetupScreen> createState() => _AutomationSetupScreenState();
}

class _AutomationSetupScreenState extends State<AutomationSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _courseNameController;
  late TextEditingController _emailController;

  // Notebook selection state
  List<dynamic> _userNotebooks = [];
  late String _selectedNotebookId;

  // Timetable integration state
  List<dynamic> _timetableCourses = [];
  String? _selectedLinkedCourseId;
  bool _isLoadingTimetable = false;
  bool _useManualTiming = false;
  String? _autoTimingSummary;

  String _selectedDay = 'Monday';
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  DateTime _semesterStartDate = DateTime.now();
  int _totalWeeks = 14;
  bool _hasBreakWeek = true;

  bool _enableEveningReminder = true;
  TimeOfDay _eveningReminderTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay? _customPrimaryReminderTime;
  bool _isDemoMode = false;

  PlatformFile? _selectedPdf;
  bool _isLoading = false;
  Map<String, dynamic>? _createdAutomation;

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedNotebookId = widget.notebookId;
    _courseNameController = TextEditingController(text: widget.initialCourseName);
    _emailController = TextEditingController(text: widget.userEmail);
    _fetchUserNotebooks();
    _fetchUserTimetableCourses();
  }

  Future<void> _fetchUserNotebooks() async {
    try {
      final email = _emailController.text.trim();
      if (email.isEmpty) return;
      final resp = await http.post(
        Uri.parse('$baseUrl/get-notebooks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted && data is List) {
          setState(() {
            _userNotebooks = data;
            // Match selected notebook if needed
            if (!_userNotebooks.any((nb) => nb['id'].toString() == _selectedNotebookId)) {
              if (_userNotebooks.isNotEmpty) {
                final matched = _userNotebooks.firstWhere(
                  (nb) => nb['title'].toString().toLowerCase().contains(widget.initialCourseName.toLowerCase()),
                  orElse: () => _userNotebooks.first,
                );
                _selectedNotebookId = matched['id'].toString();
                _courseNameController.text = matched['title'] ?? widget.initialCourseName;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user notebooks: $e");
    }
  }

  Future<void> _fetchUserTimetableCourses() async {
    setState(() => _isLoadingTimetable = true);
    try {
      final email = _emailController.text.trim();
      if (email.isEmpty) return;

      final uri = Uri.parse('$baseUrl/api/timetable?user_email=${Uri.encodeComponent(email)}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final courses = data['courses'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _timetableCourses = courses;
            // If courses exist, only auto-match if course name or ID actually matches
            if (_timetableCourses.isNotEmpty && _selectedLinkedCourseId == null) {
              final initial = widget.initialCourseName.toUpperCase().trim();
              dynamic matched;
              for (var c in _timetableCourses) {
                final cid = (c['course_id'] ?? '').toString().toUpperCase().trim();
                final cname = (c['course_name'] ?? '').toString().toUpperCase().trim();
                if (initial.isNotEmpty && (initial.contains(cid) || initial.contains(cname) || (cid.isNotEmpty && cid.contains(initial)))) {
                  matched = c;
                  break;
                }
              }
              if (matched != null) {
                _onSelectTimetableCourse(matched);
              } else {
                // Not in scanned timetable: keep notebook title and allow manual schedule
                _selectedLinkedCourseId = null;
                _useManualTiming = true;
                _courseNameController.text = widget.initialCourseName;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching timetable courses: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTimetable = false);
    }
  }

  void _onSelectTimetableCourse(dynamic course) {
    if (course == null) return;
    final cid = course['course_id']?.toString() ?? '';
    final cname = course['course_name']?.toString() ?? '';
    final classes = course['classes'] as List<dynamic>? ?? [];

    // Filter Lecture (L) sessions
    var lectures = classes.where((cl) => (cl['type'] ?? 'L').toString().toUpperCase() == 'L').toList();
    if (lectures.isEmpty) lectures = classes;

    const dayMap = {
      'mon': 0, 'tue': 1, 'wed': 2, 'thu': 3, 'fri': 4, 'sat': 5, 'sun': 6
    };
    const dayFull = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    lectures.sort((a, b) {
      final da = dayMap[(a['day'] ?? 'mon').toString().toLowerCase()] ?? 0;
      final db = dayMap[(b['day'] ?? 'mon').toString().toLowerCase()] ?? 0;
      if (da != db) return da.compareTo(db);
      return (a['start_time'] ?? '').toString().compareTo((b['start_time'] ?? '').toString());
    });

    final lastLecture = lectures.isNotEmpty ? lectures.last : null;

    setState(() {
      _selectedLinkedCourseId = cid;
      _useManualTiming = false;
      _courseNameController.text = "$cid - $cname";

      if (lastLecture != null) {
        final dShort = (lastLecture['day'] ?? 'Mon').toString().toLowerCase();
        final dIdx = dayMap[dShort] ?? 0;
        _selectedDay = dayFull[dIdx];

        final startParts = (lastLecture['start_time'] ?? '09:00').toString().split(':');
        final endParts = (lastLecture['end_time'] ?? '11:00').toString().split(':');

        if (startParts.length == 2) {
          _startTime = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 9, minute: int.tryParse(startParts[1]) ?? 0);
        }
        if (endParts.length == 2) {
          _endTime = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 11, minute: int.tryParse(endParts[1]) ?? 0);
        }

        _autoTimingSummary = "$_selectedDay at ${_formatTimeOfDay(_endTime)}";
      }
    });
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickSyllabusPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'pptx', 'ppt', 'docx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPdf = result.files.first;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _semesterStartDate = picked;
      });
    }
  }

  Future<void> _selectPrimaryReminderTime() async {
    final initial = _customPrimaryReminderTime ?? _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _customPrimaryReminderTime = picked;
      });
    }
  }

  void _setDemoNowTime() {
    final now = DateTime.now();
    final demoTrigger = now.add(const Duration(minutes: 2));
    final todayDayName = _daysOfWeek[now.weekday - 1];

    setState(() {
      _isDemoMode = true;
      _useManualTiming = true;
      _selectedDay = todayDayName;
      _semesterStartDate = DateTime(now.year, now.month, now.day);
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 9, minute: 0);
      _customPrimaryReminderTime = TimeOfDay(hour: demoTrigger.hour, minute: demoTrigger.minute);
      _autoTimingSummary = "$todayDayName (Today) at ${_formatTimeOfDay(_customPrimaryReminderTime!)} [DEMO MODE]";
      if (_emailController.text.trim().isEmpty ||
          _emailController.text.trim().toLowerCase() == 'guest' ||
          !_emailController.text.contains('@')) {
        _emailController.text = 'yanwaitham@gmail.com';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⚡ Presentation Demo Mode: 1st Alert set to ${_formatTimeOfDay(_customPrimaryReminderTime!)} TODAY (in 2 mins)"),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _selectEveningReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eveningReminderTime,
    );
    if (picked != null) {
      setState(() {
        _eveningReminderTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _submitAutomation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a syllabus PDF file before submitting."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Class End Time must be later than Start Time."),
          backgroundColor: Colors.deepOrange,

        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('$baseUrl/api/automations');
      final request = http.MultipartRequest('POST', uri);

      if (_isDemoMode) {
        final now = DateTime.now();
        final exactDemoTime = now.add(const Duration(minutes: 2));
        _customPrimaryReminderTime = TimeOfDay(hour: exactDemoTime.hour, minute: exactDemoTime.minute);
        _semesterStartDate = DateTime(now.year, now.month, now.day);
        _selectedDay = _daysOfWeek[now.weekday - 1];
      }

      final effectivePrimaryTime = _customPrimaryReminderTime ?? _endTime;

      request.fields['is_demo_mode'] = _isDemoMode ? 'true' : 'false';
      request.fields['demo_minutes'] = '2';
      request.fields['notebook_id'] = _selectedNotebookId;
      request.fields['course_name'] = _courseNameController.text.trim();
      request.fields['user_email'] = _emailController.text.trim();
      if (_selectedLinkedCourseId != null && !_useManualTiming && !_isDemoMode) {
        request.fields['linked_course_id'] = _selectedLinkedCourseId!;
      }
      request.fields['class_day'] = _selectedDay;
      request.fields['class_start_time'] = _formatTimeOfDay(_startTime);
      request.fields['class_end_time'] = _formatTimeOfDay(_endTime);
      request.fields['semester_start_date'] = _formatDate(_semesterStartDate);
      request.fields['total_weeks'] = _totalWeeks.toString();
      request.fields['has_break_week'] = _hasBreakWeek ? 'true' : 'false';
      request.fields['primary_reminder_time'] = _formatTimeOfDay(effectivePrimaryTime);
      request.fields['enable_evening_reminder'] = _enableEveningReminder ? 'true' : 'false';
      request.fields['evening_reminder_time'] = _formatTimeOfDay(_eveningReminderTime);

      if (_selectedPdf!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'syllabus',
          _selectedPdf!.bytes!,
          filename: _selectedPdf!.name,
        ));
      } else if (_selectedPdf!.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'syllabus',
          _selectedPdf!.path!,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isLoading = false;
      });

      Map<String, dynamic> data = {};
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Server returned HTTP ${response.statusCode} (Non-JSON response). Please check if backend is running.");
      }

      if (response.statusCode == 201 && data['success'] == true) {
        setState(() {
          _createdAutomation = data;
        });

        final warnings = List<String>.from(data['warnings'] ?? []);

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("Automation Active!"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Syllabus parsed using: ${data['syllabus_source'] ?? 'AI'}"),
                const SizedBox(height: 10),
                Text("Generated ${data['weekly_schedule']?.length ?? 0} weekly revision triggers."),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("Warnings:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("• $w", style: const TextStyle(fontSize: 12, color: Colors.orange)),
                    ),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AutomationHistoryScreen(
                        notebookId: widget.notebookId,
                        courseName: _courseNameController.text.trim(),
                        userEmail: _emailController.text.trim(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text("View Live History & Progress"),
              ),
            ],
          ),
        );
      } else {
        final errs = data['errors'] ?? [data['message'] ?? 'Failed to setup automation (HTTP ${response.statusCode})'];
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${errs is List ? errs.join(', ') : errs.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network or Server error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Syllabus & Timetable Engine"),
        elevation: 0,
      ),
      backgroundColor: colors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(scheme, colors),
                  const SizedBox(height: 20),
                  
                  // Course & Timetable Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "1. Course & Timetable",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_isLoadingTimetable) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimetableScannerScreen(userEmail: _emailController.text.trim()),
                            ),
                          );
                          _fetchUserTimetableCourses();
                        },
                        icon: const Icon(Icons.document_scanner_rounded, size: 16),
                        label: const Text("Scan Timetable", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                   const SizedBox(height: 10),

                  // Target Notebook Selector (shows all user's notebooks)
                  if (_userNotebooks.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _userNotebooks.any((nb) => nb['id'].toString() == _selectedNotebookId)
                          ? _selectedNotebookId
                          : _userNotebooks.first['id'].toString(),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Target Notebook (All Your Notebooks)",
                        prefixIcon: Icon(Icons.folder_special_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(),
                        helperText: "Choose which notebook to automate",
                      ),
                      items: _userNotebooks.map((nb) {
                        final id = nb['id']?.toString() ?? '';
                        final title = nb['title']?.toString() ?? 'Notebook';
                        final sources = (nb['sources'] as List<dynamic>? ?? []).length;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            "$title ($sources sources)",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          final chosen = _userNotebooks.firstWhere((nb) => nb['id'].toString() == newId, orElse: () => null);
                          if (chosen != null) {
                            setState(() {
                              _selectedNotebookId = newId;
                              _courseNameController.text = chosen['title'] ?? '';
                              // Check if notebook matches any timetable course
                              final titleUpper = (chosen['title'] ?? '').toString().toUpperCase().trim();
                              dynamic matched;
                              for (var c in _timetableCourses) {
                                final cid = (c['course_id'] ?? '').toString().toUpperCase().trim();
                                final cname = (c['course_name'] ?? '').toString().toUpperCase().trim();
                                if (titleUpper.isNotEmpty && (titleUpper.contains(cid) || titleUpper.contains(cname) || (cid.isNotEmpty && cid.contains(titleUpper)))) {
                                  matched = c;
                                  break;
                                }
                              }
                              if (matched != null) {
                                _onSelectTimetableCourse(matched);
                              } else {
                                _selectedLinkedCourseId = null;
                                _useManualTiming = true;
                                _autoTimingSummary = null;
                              }
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // If user has parsed timetable courses, show dropdown
                  if (_timetableCourses.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                "Link to My Timetable (Auto-Schedule)",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String?>(
                            value: _selectedLinkedCourseId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Link to Timetable Course (Optional)",
                              prefixIcon: Icon(Icons.class_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  "None (Custom Course / Manual Schedule)",
                                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                                ),
                              ),
                              ..._timetableCourses.map((c) {
                                final cid = c['course_id']?.toString() ?? '';
                                final cname = c['course_name']?.toString() ?? '';
                                return DropdownMenuItem<String?>(
                                  value: cid,
                                  child: Text(
                                    "$cid - $cname",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val == null) {
                                setState(() {
                                  _selectedLinkedCourseId = null;
                                  _useManualTiming = true;
                                  _autoTimingSummary = null;
                                  _courseNameController.text = widget.initialCourseName;
                                });
                              } else {
                                final selected = _timetableCourses.firstWhere(
                                  (c) => c['course_id'] == val,
                                  orElse: () => null,
                                );
                                if (selected != null) {
                                  _onSelectTimetableCourse(selected);
                                }
                              }
                            },
                          ),
                          if (_autoTimingSummary != null && !_useManualTiming) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt, color: Color(0xFF6C63FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Revision automatically triggers after your weekly Lectures end ($_autoTimingSummary)",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6C63FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _courseNameController,
                    decoration: InputDecoration(
                      labelText: "Course Name / Code",
                      prefixIcon: const Icon(Icons.book_outlined),
                      suffixIcon: _userNotebooks.isNotEmpty
                          ? PopupMenuButton<dynamic>(
                              tooltip: "Select from My Notebooks (${_userNotebooks.length})",
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_open_rounded, size: 16, color: scheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Select Notebook",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down_rounded, size: 20, color: scheme.primary),
                                  ],
                                ),
                              ),
                              onSelected: (nb) {
                                setState(() {
                                  _selectedNotebookId = nb['id']?.toString() ?? '';
                                  _courseNameController.text = nb['title']?.toString() ?? '';
                                  final titleUpper = (nb['title'] ?? '').toString().toUpperCase().trim();
                                  dynamic matched;
                                  for (var c in _timetableCourses) {
                                    final cid = (c['course_id'] ?? '').toString().toUpperCase().trim();
                                    final cname = (c['course_name'] ?? '').toString().toUpperCase().trim();
                                    if (titleUpper.isNotEmpty &&
                                        (titleUpper.contains(cid) ||
                                            titleUpper.contains(cname) ||
                                            (cid.isNotEmpty && cid.contains(titleUpper)))) {
                                      matched = c;
                                      break;
                                    }
                                  }
                                  if (matched != null) {
                                    _onSelectTimetableCourse(matched);
                                  } else {
                                    _selectedLinkedCourseId = null;
                                    _useManualTiming = true;
                                    _autoTimingSummary = null;
                                  }
                                });
                              },
                              itemBuilder: (context) {
                                return _userNotebooks.map((nb) {
                                  final title = nb['title']?.toString() ?? 'Notebook';
                                  final sources = (nb['sources'] as List<dynamic>? ?? []).length;
                                  return PopupMenuItem<dynamic>(
                                    value: nb,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.folder_special_rounded, color: Color(0xFF6C63FF), size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                "$sources source${sources == 1 ? '' : 's'} available",
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? "Course name required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Notification Email",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || !v.contains("@") ? "Valid email required" : null,
                  ),
                  const SizedBox(height: 24),

                  // Timetable Configuration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "2. Semester & Schedule",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_selectedLinkedCourseId != null)
                        TextButton(
                          onPressed: () => setState(() => _useManualTiming = !_useManualTiming),
                          child: Text(
                            _useManualTiming ? "Use Timetable Time" : "Manual Override",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_useManualTiming || _selectedLinkedCourseId == null) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedDay,
                      decoration: const InputDecoration(
                        labelText: "Class Day of Week",
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      items: _daysOfWeek.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectStartTime,
                            icon: const Icon(Icons.access_time),
                            label: Text("Start: ${_formatTimeOfDay(_startTime)}"),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectEndTime,
                            icon: const Icon(Icons.access_time_filled),
                            label: Text("End: ${_formatTimeOfDay(_endTime)}"),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.date_range),
                    label: Text("Semester Start: ${_formatDate(_semesterStartDate)}"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("Semester Duration: ", style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 12, label: Text("12 Wks")),
                          ButtonSegment(value: 13, label: Text("13 Wks")),
                          ButtonSegment(value: 14, label: Text("14 Wks")),
                        ],
                        selected: {_totalWeeks},
                        onSelectionChanged: (set) {
                          setState(() => _totalWeeks = set.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text("Includes Mid-Term Break Week"),
                    subtitle: const Text("Skips calendar week after Week 6"),
                    value: _hasBreakWeek,
                    onChanged: (val) => setState(() => _hasBreakWeek = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // 3. Spaced Revision Reminder Times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "3. Spaced Revision Reminders",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_customPrimaryReminderTime != null || _isDemoMode)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _customPrimaryReminderTime = null;
                            _isDemoMode = false;
                          }),
                          icon: const Icon(Icons.restore, size: 14),
                          label: const Text("Reset to Auto", style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Default: 1st alert is auto-scheduled at class end (${_formatTimeOfDay(_endTime)}). Tap to customize for live presentation demo.",
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // 1st Alert (Clickable Time Picker, Default = Auto class end)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectPrimaryReminderTime,
                          icon: Icon(
                            Icons.alarm_on_rounded,
                            color: _customPrimaryReminderTime != null ? Colors.cyanAccent : Colors.orangeAccent,
                            size: 18,
                          ),
                          label: Text(
                            _customPrimaryReminderTime != null
                                ? "1st (Custom): ${_formatTimeOfDay(_customPrimaryReminderTime!)}"
                                : "1st (Auto): ${_formatTimeOfDay(_endTime)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _customPrimaryReminderTime != null ? Colors.cyanAccent : scheme.onSurface,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            side: BorderSide(
                              color: _customPrimaryReminderTime != null ? Colors.cyanAccent : colors.border,
                            ),
                          ),
                        ),
                      ),
                      if (_enableEveningReminder) ...[
                        const SizedBox(width: 10),
                        // 2nd Alert (Clickable Time Picker, Default = 21:00)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectEveningReminderTime,
                            icon: const Icon(Icons.nightlight_round, color: Color(0xFFA78BFA), size: 18),
                            label: Text(
                              "2nd: ${_formatTimeOfDay(_eveningReminderTime)}",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick Demo Mode Shortcut Row
                  Row(
                    children: [
                      InkWell(
                        onTap: _setDemoNowTime,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bolt, color: Colors.purpleAccent, size: 14),
                              SizedBox(width: 4),
                              Text("⚡ Demo: Now + 2 Mins", style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("Sets 1st alert in 2 mins for live demo", style: TextStyle(color: colors.mutedText, fontSize: 11)),
                    ],
                  ),
                  if (_isDemoMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.purpleAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚡ Live Demo Mode Active: Week 1 alert will trigger TODAY at ${_customPrimaryReminderTime != null ? _formatTimeOfDay(_customPrimaryReminderTime!) : 'now + 2m'} (in 2 mins). Real email will be dispatched to ${_emailController.text.trim()}!",
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  SwitchListTile(
                    title: const Text("2nd Evening Follow-up Alert (9:00 PM)"),
                    subtitle: const Text("Automatically sends a wrap-up reminder only if the quiz is not completed yet"),
                    value: _enableEveningReminder,
                    onChanged: (val) => setState(() => _enableEveningReminder = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Syllabus PDF Upload
                  Text(
                    "4. Syllabus Document",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickSyllabusPdf,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPdf != null ? scheme.primary : colors.border,
                          width: _selectedPdf != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedPdf != null ? Icons.picture_as_pdf : Icons.upload_file,
                            size: 36,
                            color: _selectedPdf != null ? scheme.primary : colors.mutedText,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPdf != null ? _selectedPdf!.name : "Select Syllabus Document (PDF, PPTX, PPT)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedPdf != null
                                      ? "${(_selectedPdf!.size / 1024).toStringAsFixed(1)} KB"
                                      : "Upload teaching plan or lecture presentation",
                                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedPdf != null)
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitAutomation,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Generate Revision Engine", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // Created Schedule Preview Card
                  if (_createdAutomation != null) ...[
                    const SizedBox(height: 32),
                    Text(
                      "Active Revision Schedule",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSchedulePreviewList(_createdAutomation!['weekly_schedule'] ?? [], colors, scheme),
                  ],
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Analyzing Syllabus with Gemini AI..."),
                        SizedBox(height: 4),
                        Text("Calculating weekly revision triggers", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme scheme, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_send, size: 40, color: Colors.white),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Automated Timetable Engine",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  "Parses syllabus topics with Gemini AI and sends email alerts with deep links.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePreviewList(List<dynamic> items, AppColors colors, ColorScheme scheme) {
    return Column(
      children: items.map((item) {
        final week = item['week_number'];
        final topic = item['topic_title'] ?? 'Revision';
        final trigger = item['revision_trigger_timestamp'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Text("W$week", style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary)),
            ),
            title: Text(topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Trigger: $trigger", style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.notifications_active_outlined, size: 20),
          ),
        );
      }).toList(),
    );
  }
}
