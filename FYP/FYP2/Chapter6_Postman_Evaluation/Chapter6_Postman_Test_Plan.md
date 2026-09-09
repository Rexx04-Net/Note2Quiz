# Note2Quiz Chapter 6 Postman Test Plan

## Confirmed runtime and request boundary

- Flask starts with `app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)` in `backend/app.py`; the local Postman base URL is therefore `http://127.0.0.1:5000`.
- The tested Flask routes do not implement backend session authentication or Firebase ID-token verification. No `Authorization` header is required by the selected requests.
- JSON endpoints use `Content-Type: application/json`. Timetable upload and automation creation use `multipart/form-data`, which Postman generates from their form-data bodies.
- Notebook, timetable and automation routes use MongoDB when available and their implemented local fallback otherwise. Multiplayer rooms use only the process-memory `active_games` dictionary.
- No API key, password, Gmail credential, OAuth token or Firebase token is stored in either Postman export.

## Route-to-test mapping

| Test ID | Objective supported | Endpoint / source function | Test purpose | Input / test data | Expected behaviour from implementation | Planned runs | Metric collected | Evidence to preserve |
|---|---|---|---|---|---|---:|---|---|
| C6-CORE-01 | Setup only | `GET /` — `app.home()` | Confirm that the local Flask server is reachable before any write or quota use | None | HTTP 200; response contains `Note2Quiz Backend is Running` | 1 first-safe run; later 25 if selected for timing | Status, success/failure, mean/min/max/P95 response time | Postman result and console metric |
| C6-CORE-02 | Setup for O1/O3 | `POST /create-notebook` — `app.create_notebook()` | Create an isolated evaluation notebook | Generated `.invalid` email and UUID-labelled title | HTTP 200; string `id`; empty `sources` array | 1 per setup | Functional pass/fail | Raw response containing notebook id |
| C6-CORE-03 | O1 | `POST /add-source` — `app.add_source()` | Store controlled source text for later generation | Notebook id, email, type `text`, controlled data-structures text | HTTP 200; source `id`, `type=text`, and stored content | 1 per setup | Functional pass/fail | Raw request/response and source id |
| C6-CORE-04 | O1 | `POST /get-notebooks` — `app.get_notebooks()` | Verify notebook retrieval and measure an ordinary non-AI API | Evaluation email | HTTP 200; array contains the generated notebook id | 25 | Runs, successes, failures, success rate, mean/min/max/P95 ms | Runner export and `metric_get_notebooks` console/collection value |
| C6-CORE-05 | O1/O3 | `POST /get-notebook-history` — `app.get_notebook_history()` | Verify generation/quiz history response and ordinary API timing | Evaluation notebook id | HTTP 200; `history` and `quiz_results` arrays | 25 | Runs, successes, failures, success rate, mean/min/max/P95 ms | Runner export and `metric_get_history` |
| C6-CORE-06 | O3 | `GET /get-notebook-mistakes` — `app.get_notebook_mistakes()` | Verify the embedded mistake-bank response and ordinary API timing | `notebook_id` query parameter | HTTP 200; numeric `mistakes_count`; `mistakes` array | 25 | Runs, successes, failures, success rate, mean/min/max/P95 ms | Runner export and `metric_get_mistakes` |
| C6-CORE-07 | O3 | `POST /save-quiz-result` — `app.save_quiz_result()` | Store one controlled quiz attempt and one distinct incorrect question | One-question quiz and breakdown with `is_correct=false` | HTTP 200; `success=true`; stored result object and id | 1 | Functional pass/fail | Raw request/response and generated question marker |
| C6-CORE-08 | O3 | `GET /get-notebook-mistakes` — `app.get_notebook_mistakes()` | Confirm the exact controlled mistake was persisted inside the notebook | Evaluation notebook id and generated question marker | HTTP 200; returned mistakes contain the exact question | 1 | Functional pass/fail | Raw response showing the controlled mistake |
| C6-AI-00/01 | Setup for O1 | `POST /create-notebook`, `POST /add-source` | Force a new content fingerprint for every AI iteration | New UUID-labelled notebook and source | Unique notebook/source ids for the iteration | 5 setup iterations | Setup pass/fail | Runner export showing unique ids |
| C6-AI-02 | O1 | `POST /generate-studio-item` — `app.generate_studio_item()` with `tool_type=quiz` | Evaluate fresh structured quiz generation | Standard difficulty, English, one selected controlled source | HTTP 200; `type=json`; non-empty array; every question has question/options/answer/explanation and answer is one option | 5 fresh runs | Success rate and end-to-end mean/min/max ms; P95 retained only as a descriptive five-run value | Runner export, raw responses and `metric_ai_quiz_fresh` |
| C6-AI-03 | O1 | Same route with `tool_type=flashcard` | Evaluate fresh flashcard generation | Same unique per-iteration source | HTTP 200; non-cached JSON array; each card has non-empty `front` and `back` | 5 fresh runs | Success rate and end-to-end mean/min/max ms | Runner export, raw responses and `metric_ai_flashcard_fresh` |
| C6-AI-04 | O1 | Same route with `tool_type=mindmap` | Evaluate fresh mind-map generation | Same unique per-iteration source | HTTP 200; non-cached JSON object with string `title` and array `children` | 5 fresh runs | Success rate and end-to-end mean/min/max ms | Runner export, raw responses and `metric_ai_mindmap_fresh` |
| C6-AI-05 | O1 | `POST /stream-studio-item` — `app.stream_studio_item()` with `tool_type=report` | Evaluate fresh briefing SSE completion | Same unique per-iteration source | HTTP 200; `text/event-stream`; at least one `chunk`, no error event and a non-cached `done=true` event | 5 fresh runs | Success rate and end-to-end completion mean/min/max ms; **not TTFT** | Runner export, saved raw SSE body and `metric_ai_briefing_fresh` |
| C6-AI-06 | Cache diagnostic only | `POST /generate-studio-item` with repeated flashcard fingerprint | Prove cached output is distinguishable from a fresh Gemini call | Exact same notebook/source/tool/difficulty/language as C6-AI-03 | HTTP 200; top-level and history `cached=true` | 1 per AI iteration; excluded from fresh metrics | Diagnostic response time only | Raw response and console line `CACHE_HIT_DIAGNOSTIC_MS` |
| C6-SCHED-01 | O2 | `POST /api/timetable/export-ics` — `timetable.export_ics()` / `export_ics_logic()` | Verify deterministic 14-week calendar export without Gemini or Google OAuth | Inline one-course/one-class timetable, Monday semester start | HTTP 200; `text/calendar`; `BEGIN:VCALENDAR`; exactly 14 `VEVENT` blocks containing UCCD1024 | 25 | Runs, successes, failures, success rate, mean/min/max/P95 ms | Runner export, saved `.ics` response and `metric_export_ics` |
| C6-SCHED-02 | O2 | `POST /api/timetable/upload` — `timetable.upload_timetable()` / `parse_timetable_with_gemini()` | Validate multimodal timetable response structure and collect output for later accuracy scoring | Five manually labelled timetable image/PDF samples, one request per sample | HTTP 200; `success=true`; timetable/courses/classes use the implemented fields and normalised values | 5 labelled samples, 1 fresh run each | Request success and end-to-end response time; accuracy calculated separately | Every original input file, its ground-truth record, raw JSON response and Runner export |
| C6-SCHED-03 | O2 | `GET /api/timetable` — `timetable.get_user_timetable()` | Confirm the upload was stored through MongoDB or the implemented fallback | Evaluation email | HTTP 200; `success=true`; non-null timetable and courses array | 1 after each successful upload | Functional pass/fail | Raw stored-timetable response |
| C6-SCHED-04 | O2 | `POST /api/automations` — `automation.create_or_update_automation()` | Verify construction of a 14-week revision schedule from form data and a syllabus PDF | Valid notebook/email/day/times/date/week settings plus manually selected PDF | HTTP 201; `success=true`; automation id; 14 weekly schedule entries; response records `syllabus_source` and warnings | 1 | Functional pass/fail and end-to-end response time | Input PDF, raw response, `syllabus_source`, warnings and schedule |
| C6-SCHED-05 | O2 | `GET /api/automations/<notebook_id>` — `automation.get_automation_history()` | Confirm persisted/memory-fallback automation and calculated status fields | Notebook id and evaluation email | HTTP 200; automation, 14-entry history and stats with `total_weeks=14` | 1 | Functional pass/fail | Raw response |
| C6-MP-01–09 | Supplementary system functionality | `POST /host-game`, `/join-game`, `/get-game-status`, `/start-game`, `/update-score`, `/get-leaderboard` in `app.py` | Verify the implemented in-memory multiplayer workflow in order | Generated room code, two generated player names, submitted scores 700 and 900 | Six-character code; both players join waiting state; state becomes playing; leaderboard returns player B before player A | 1 ordered workflow | Functional pass/fail only | Complete Runner result and final leaderboard response |

## Metric interpretation

For the four 25-run candidates, each test script records the run count, successful and failed requests, success rate, all response times, mean, minimum, maximum and nearest-rank P95 in a collection variable and the Postman Console. These are local functional/response-time observations, not scalability or production-load evidence. No new pass/fail latency threshold was added.

For AI generation, run the entire `02 - AI Generation Evaluation` folder with exactly five iterations. Its setup creates a new content fingerprint per iteration. Quiz requests already bypass cache retrieval in the source. Flashcard, mind-map and briefing tests fail their fresh classification if the response is marked cached. C6-AI-06 deliberately checks a cache hit and its timing must stay separate from fresh AI results.

Postman's total SSE request duration may be retained as end-to-end completion time. **SSE first-chunk timing requires separate Chrome DevTools or backend instrumentation.** Postman HTTP response time or TTFB must not be relabelled as Gemini time to first token.

## Timetable ground-truth evidence

HTTP 200 and valid JSON do not establish timetable extraction accuracy. For each of the five samples, preserve:

1. The unchanged source image/PDF and a stable sample id.
2. A manually checked ground-truth table containing `course_id`, `course_name`, `type`, `day`, `start_time`, `end_time`, `venue` and `group` for every class.
3. The complete raw JSON returned by C6-SCHED-02.
4. A field-by-field comparison sheet that counts correct, incorrect, missing and extra values under a stated matching rule.
5. The Postman Runner export with request status and end-to-end response time.

Report field-level accuracy only after the ground truth and scoring rule are fixed. Keep course/session detection counts separate from exact field-value accuracy.

## Routes intentionally excluded

- Google OAuth callback and Calendar sync routes require external authorisation and may create real calendar events; they are outside this local Postman evidence run.
- Notification dispatch is a background SMTP workflow rather than a suitable secret-free Postman request.
- `generate-active-plan` and weakness-drill generation would add further Gemini calls beyond the minimal objective evidence selected here.
- `api/analytics/overview` is not selected as evaluation evidence because its response includes fallback/default presentation data when records are absent; mistake persistence is tested directly instead.
- Delete routes are omitted so the generated ids and responses remain available for evidence review.

## Run order and evidence handling

1. Import the environment and collection, select `Note2Quiz Local`, and run only C6-CORE-01 first.
2. After confirming the base URL, run C6-CORE-02 and C6-CORE-03 once.
3. Run each labelled 25-run candidate separately in Collection Runner and export the result after each run.
4. Run C6-CORE-07 and C6-CORE-08 once in order.
5. Only when Gemini quota use is intended, run the entire AI folder with exactly five iterations and export the Runner result.
6. Run C6-SCHED-01 separately. Select real files immediately before C6-SCHED-02 and C6-SCHED-04; never save credentials in the collection.
7. Run the complete multiplayer folder once, in its existing order.

A collection definition is preparation, not evidence that a route passed. Only the saved results from execution against the running local backend may be used in Chapter 6.
