import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_theme.dart';
import '../utils/course_colors.dart';
import '../utils/file_downloader.dart';

class TimetableScannerScreen extends StatefulWidget {
  final String userEmail;

  const TimetableScannerScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<TimetableScannerScreen> createState() => _TimetableScannerScreenState();
}

class _TimetableScannerScreenState extends State<TimetableScannerScreen> {
  bool _isLoading = false;
  bool _isUploading = false;
  String? _statusMessage;
  Map<String, dynamic>? _timetableData;
  List<dynamic> _courses = [];
  final Set<String> _selectedCourseIds = {};
  DateTime _semesterStartDate = DateTime(2026, 6, 15);

  @override
  void initState() {
    super.initState();
    _fetchExistingTimetable();
  }

  Future<void> _fetchExistingTimetable() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        '$baseUrl/api/timetable?user_email=${Uri.encodeComponent(widget.userEmail)}',
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['timetable'] != null) {
          setState(() {
            _timetableData = data['timetable'];
            _courses = data['courses'] ?? [];
            if (_timetableData?['semester_start_date'] != null) {
              try {
                _semesterStartDate = DateTime.parse(_timetableData!['semester_start_date'].toString().substring(0, 10));
              } catch (_) {}
            }
            _selectedCourseIds.clear();
            for (var c in _courses) {
              if (c['course_id'] != null) {
                _selectedCourseIds.add(c['course_id'].toString());
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching timetable: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadTimetable() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showSnackBar("Failed to read image data.", isError: true);
        return;
      }

      setState(() {
        _isUploading = true;
        _statusMessage = "Analyzing timetable with Gemini Multimodal Vision...";
      });

      final uri = Uri.parse('$baseUrl/api/timetable/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['user_email'] = widget.userEmail;

      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        file.bytes!,
        filename: file.name,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _timetableData = data['timetable'];
            _courses = data['timetable']['courses'] ?? [];
            _selectedCourseIds.clear();
            for (var c in _courses) {
              if (c['course_id'] != null) {
                _selectedCourseIds.add(c['course_id'].toString());
              }
            }
          });
          _showSnackBar("Timetable scanned and parsed successfully!");
        } else {
          _showSnackBar(data['error'] ?? "Failed to parse timetable.", isError: true);
        }
      } else {
        String errMsg = "Server error (${response.statusCode})";
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['error'] != null) {
            errMsg = err['error'].toString();
          }
        } catch (_) {
          errMsg = "Server returned error ${response.statusCode}. Please try again.";
        }
        _showSnackBar(errMsg, isError: true);
      }
    } catch (e) {
      _showSnackBar("Upload error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _exportIcsCalendar() async {
    if (_selectedCourseIds.isEmpty) {
      _showSnackBar("Please select at least one course to export.", isError: true);
      return;
    }

    setState(() => _statusMessage = "Generating 14-week .ics calendar file...");
    try {
      final startDateFormatted = "${_semesterStartDate.year.toString().padLeft(4, '0')}-${_semesterStartDate.month.toString().padLeft(2, '0')}-${_semesterStartDate.day.toString().padLeft(2, '0')}";
      final uri = Uri.parse('$baseUrl/api/timetable/export-ics');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': widget.userEmail,
          'course_ids': _selectedCourseIds.toList(),
          'semester_start_date': startDateFormatted,
        }),
      );

      if (response.statusCode == 200) {
        final icsBytes = response.bodyBytes;
        // Trigger browser / OS download of the .ics file
        final userPrefix = widget.userEmail.split('@').first;
        downloadFileBytes(icsBytes, "semester_timetable_$userPrefix.ics");
        _showExportSuccessDialog(icsBytes.length, "semester_timetable_$userPrefix.ics");
      } else {
        _showSnackBar("Failed to export .ics file.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Export error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _statusMessage = null);
    }
  }

  Future<void> _selectSemesterStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: "SELECT SEMESTER START DATE (MONDAY)",
    );
    if (picked != null) {
      setState(() => _semesterStartDate = picked);
    }
  }

  String _formatDateDisplay(DateTime dt) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final weekdayStr = weekdays[dt.weekday - 1];
    return "$weekdayStr, ${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  Future<void> _syncGoogleCalendar() async {
    if (_selectedCourseIds.isEmpty) {
      _showSnackBar("Please select at least one course to sync.", isError: true);
      return;
    }

    setState(() {
      _statusMessage = "Connecting directly to Google Calendar API...";
      _isUploading = true;
    });

    try {
      final startDateFormatted = "${_semesterStartDate.year.toString().padLeft(4, '0')}-${_semesterStartDate.month.toString().padLeft(2, '0')}-${_semesterStartDate.day.toString().padLeft(2, '0')}";
      final syncUri = Uri.parse('$baseUrl/api/timetable/sync-google-calendar');
      final syncResp = await http.post(
        syncUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': widget.userEmail,
          'course_ids': _selectedCourseIds.toList(),
          'semester_start_date': startDateFormatted,
        }),
      );

      final data = jsonDecode(syncResp.body);

      if (data['requires_oauth'] == true && data['oauth_url'] != null) {
        final oauthUrl = data['oauth_url'].toString();
        openWebUrl(oauthUrl);
        _showOAuthPromptDialog(oauthUrl);
        return;
      }

      if (data['needs_client_id'] == true) {
        _showGoogleSetupDialog(data['error']?.toString() ?? "Google OAuth needs configuration.");
        return;
      }

      if (syncResp.statusCode == 200 && data['success'] == true) {
        final calTitle = data['calendar_title'] ?? "UTAR Timetable (${startDateFormatted.substring(0, 7)})";
        final eventsCount = data['events_count'] ?? 0;
        _showDirectSyncSuccessDialog(calTitle, eventsCount);
      } else {
        _showSnackBar(data['error'] ?? "Failed to sync to Google Calendar.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Sync error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showOAuthPromptDialog(String oauthUrl) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.appColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_circle_rounded, color: Color(0xFF1A73E8), size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Google Authorization", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "A Google permission tab has been opened for you to authorize Note2Quiz to add your 14-week university schedule directly to your Google Calendar.",
              style: TextStyle(color: context.appColors.mutedText),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF1A73E8), size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Direct 1-Click Sync",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "1. Click 'Allow' on the Google authorization screen.\n2. Note2Quiz will instantly write all ${_selectedCourseIds.length} course schedules into your Google Calendar.\n3. You only need to do this once!",
                    style: TextStyle(fontSize: 11, color: context.appColors.subtleText, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              openWebUrl(oauthUrl);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text("Reopen Google Tab"),
          ),
        ],
      ),
    );
  }

  void _showGoogleSetupDialog(String details) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.appColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Google OAuth Setup", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "To sync directly into your Google Calendar without any manual import, Note2Quiz needs your Google OAuth Client ID.",
              style: TextStyle(color: context.appColors.mutedText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Add to backend/api_secrets.py:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const SelectableText(
                    "GOOGLE_CLIENT_ID = \"your_client_id.apps.googleusercontent.com\"\nGOOGLE_CLIENT_SECRET = \"your_secret\"",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF60A5FA)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Redirect URI to add in Google Cloud Console:\nhttp://localhost:5000/api/timetable/google-oauth-callback",
                    style: TextStyle(fontSize: 11, color: context.appColors.subtleText),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got It"),
          ),
        ],
      ),
    );
  }

  void _showDirectSyncSuccessDialog(String calTitle, int eventsCount) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.appColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Google Calendar Synced", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Successfully created '$calTitle' with ${_selectedCourseIds.length} courses ($eventsCount weekly classes) recurring across all 14 weeks on your Google Calendar!",
              style: TextStyle(color: context.appColors.mutedText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              openWebUrl("https://calendar.google.com");
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.calendar_month_rounded, size: 16),
            label: const Text("Open Google Calendar"),
          ),
        ],
      ),
    );
  }

  void _showExportSuccessDialog(int fileSize, String filename) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.appColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Calendar Exported", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your 14-week university semester schedule has been downloaded to your browser's Downloads folder as '$filename' (${(fileSize / 1024).toStringAsFixed(1)} KB).",
              style: TextStyle(color: context.appColors.mutedText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${_selectedCourseIds.length} course(s) with lectures & practicals included.",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "💡 Open the downloaded .ics file to import into Google Calendar or Apple Calendar with 1 click.",
                    style: TextStyle(fontSize: 11, color: context.appColors.subtleText),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<void> _autoCreateNotebooks() async {
    if (_selectedCourseIds.isEmpty) {
      _showSnackBar("Please select at least one course.", isError: true);
      return;
    }

    setState(() => _statusMessage = "Auto-creating study notebooks for selected courses...");
    try {
      final uri = Uri.parse('$baseUrl/api/timetable/auto-create-notebooks');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': widget.userEmail,
          'course_ids': _selectedCourseIds.toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final createdCount = data['created_count'] ?? 0;
        final skipped = List<String>.from(data['skipped_notebooks'] ?? []);

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: context.appColors.surface,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3451FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.book_rounded, color: Color(0xFF3451FF), size: 24),
                ),
                const SizedBox(width: 12),
                const Text("Notebooks Created", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Successfully generated $createdCount new notebook(s) from your timetable courses.",
                  style: TextStyle(color: context.appColors.mutedText),
                ),
                if (skipped.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Note: ${skipped.length} course(s) already have existing notebooks.",
                    style: TextStyle(fontSize: 12, color: context.appColors.subtleText),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Stay Here"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3451FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Go back to dashboard
                },
                child: const Text("View on Dashboard"),
              ),
            ],
          ),
        );
      } else {
        final err = jsonDecode(response.body);
        _showSnackBar(err['error'] ?? "Failed to create notebooks.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Creation error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _statusMessage = null);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF3451FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text("Smart Timetable OCR"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: "Export .ics File",
            onPressed: _exportIcsCalendar,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Reload Timetable",
            onPressed: _fetchExistingTimetable,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isUploading
              ? _buildProcessingView()
              : _courses.isEmpty
                  ? _buildEmptyState()
                  : _buildTimetableContent(),
      bottomNavigationBar: _courses.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _autoCreateNotebooks,
                        icon: const Icon(Icons.auto_stories_rounded, size: 18),
                        label: Text(
                          "Auto-Create Notebooks (${_selectedCourseIds.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                          foregroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _syncGoogleCalendar,
                        icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                        label: Text(
                          "Sync to Google Calendar (${_selectedCourseIds.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 32),
            Text(
              "Gemini Multimodal OCR",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage ?? "Extracting course schedules, lecture halls, and class times...",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 18),
                  SizedBox(width: 8),
                  Text("Zero manual entry needed", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.appColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3451FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 72,
                color: Color(0xFF3451FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Upload University Timetable",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "Upload a screenshot or photo of your official university timetable (e.g. UTAR Portal schedule). Gemini Vision will automatically parse your lectures, practicals, venues, and timings.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mutedText, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndUploadTimetable,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text("Scan Timetable Image", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3451FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableContent() {
    final colors = context.appColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3451FF).withValues(alpha: 0.15),
                const Color(0xFF6C63FF).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3451FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3451FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded, color: Color(0xFF3451FF), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_courses.length} Courses Extracted",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Select courses to export to Google / Apple Calendar or link to Automated Revision.",
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded),
                tooltip: "Re-scan Image",
                onPressed: _pickAndUploadTimetable,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Semester Start Date Picker Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3451FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF3451FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Semester Start Date (Week 1)",
                      style: TextStyle(fontSize: 11, color: colors.subtleText, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateDisplay(_semesterStartDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _selectSemesterStartDate,
                icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                label: const Text("Change Date", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFF3451FF)),
                  foregroundColor: const Color(0xFF3451FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Select All / Deselect All header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "COURSE LIST",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: colors.subtleText,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedCourseIds.length == _courses.length) {
                    _selectedCourseIds.clear();
                  } else {
                    for (var c in _courses) {
                      if (c['course_id'] != null) {
                        _selectedCourseIds.add(c['course_id'].toString());
                      }
                    }
                  }
                });
              },
              child: Text(
                _selectedCourseIds.length == _courses.length ? "Deselect All" : "Select All",
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Course Cards with distinct colors
        ..._courses.asMap().entries.map((entry) => _buildCourseCard(entry.value, entry.key)),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    final colors = context.appColors;
    final courseId = course['course_id']?.toString() ?? 'COURSE';
    final courseName = course['course_name']?.toString() ?? '';
    final classes = course['classes'] as List<dynamic>? ?? [];
    final isSelected = _selectedCourseIds.contains(courseId);

    final courseColor = CourseColors.getByIndex(index);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? courseColor.primary : colors.border,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: courseColor.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedCourseIds.add(courseId);
                      } else {
                        _selectedCourseIds.remove(courseId);
                      }
                    });
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: courseColor.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: courseColor.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: courseColor.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        courseId,
                        style: TextStyle(
                          color: courseColor.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    courseName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...classes.map((cl) => _buildClassSessionRow(cl, courseColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSessionRow(Map<String, dynamic> cl, CourseColorItem courseColor) {
    final colors = context.appColors;
    final type = cl['type']?.toString() ?? 'L';
    final day = cl['day']?.toString() ?? 'Mon';
    final startTime = cl['start_time']?.toString() ?? '';
    final endTime = cl['end_time']?.toString() ?? '';
    final venue = cl['venue']?.toString() ?? '';
    final group = cl['group']?.toString() ?? '';

    String typeLabel;
    if (type == 'L') {
      typeLabel = 'Lecture';
    } else if (type == 'P') {
      typeLabel = 'Practical/Lab';
    } else {
      typeLabel = 'Tutorial';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Row(
        children: [
          Tooltip(
            message: typeLabel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: courseColor.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: courseColor.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: courseColor.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            "$startTime - $endTime",
            style: TextStyle(color: colors.mutedText, fontSize: 13),
          ),
          const Spacer(),
          if (venue.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                venue,
                style: TextStyle(fontSize: 11, color: colors.mutedText),
              ),
            ),
          if (group.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              "Grp $group",
              style: TextStyle(fontSize: 11, color: colors.subtleText),
            ),
          ],
        ],
      ),
    );
  }
}
