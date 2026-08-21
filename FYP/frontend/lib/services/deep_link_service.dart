import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../screens/quiz_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void initialize() {
    // Catch initial link if app was launched via deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }).catchError((err) {
      debugPrint("⚠️ [DeepLink] Initial link error: $err");
    });

    // Listen to incoming deep links while running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("⚠️ [DeepLink] Stream error: $err");
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint("🔗 [DeepLink] Received URI: $uri");
    if (uri.scheme != 'note2quiz') return;

    if (uri.host == 'revision' || uri.path.contains('revision')) {
      final notebookId = uri.queryParameters['notebook_id'];
      final weekNumberStr = uri.queryParameters['week_number'];

      if (notebookId == null || weekNumberStr == null) {
        debugPrint("⚠️ [DeepLink] Missing notebook_id or week_number parameter");
        return;
      }

      await _navigateToRevisionQuiz(notebookId, weekNumberStr);
    }
  }

  Future<void> _navigateToRevisionQuiz(String notebookId, String weekNumberStr) async {
    try {
      final apiUrl = Uri.parse('$baseUrl/api/automations/revision-quiz?notebook_id=$notebookId&week_number=$weekNumberStr');
      final resp = await http.get(apiUrl);

      List<dynamic> quizData = [];
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body['success'] == true && body['quiz_data'] != null) {
          quizData = body['quiz_data'];
        }
      }

      if (quizData.isEmpty) {
        quizData = [
          {
            "question": "Scheduled Revision Quiz - Week $weekNumberStr",
            "options": ["Option A", "Option B", "Option C", "Option D"],
            "answer": "Option A",
            "hint": "Review course materials for this week."
          }
        ];
      }

      final navState = navigatorKey.currentState;
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              quizData: quizData,
              notebookId: notebookId,
              weekNumber: int.tryParse(weekNumberStr),
            ),
          ),
        );
      } else {
        debugPrint("⚠️ [DeepLink] NavigatorState not ready yet.");
      }
    } catch (e) {
      debugPrint("⚠️ [DeepLink] Error fetching revision quiz: $e");
    }
  }
}
