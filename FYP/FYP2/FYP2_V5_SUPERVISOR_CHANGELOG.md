# Note2Quiz FYP2 V5 Supervisor Revision Changelog

## Revision basis

- Base report: `FYP2_Final_Report_Note2Quiz_V4 Commented.docx`.
- Chapters 1–3: revised from the supervisor comments originally attached to V1; no V1 report content was copied into V5.
- Chapters 4–7: revised from the supervisor comments attached to V4.
- Existing technically corrected V4 facts were retained unless a supervisor comment required clarification or stronger evidence boundaries.

## Chapters 1–3

- Rewrote the project background into three focused paragraphs and removed unsupported claims about measured learning improvement.
- Aligned three problem statements, three objectives and three contributions on a one-to-one basis: material generation, revision scheduling and mistake-based targeted practice.
- Clarified the project scope, supported input formats, optional multiplayer role and the limitation that the Flask backend does not verify Firebase ID tokens.
- Reorganised the literature review around the three objectives, added scoped discussions of RAG, model selection and learning analytics, and removed claims of unique or universally superior product capabilities.
- Replaced the SDLC figures and justified evolutionary prototyping for an individual development project without claiming a formal user study.
- Reframed hardware specifications as indicative development/client configurations and removed the unsupported 2K dual-display requirement.
- Revised the FYP2 timeline as planned prototype iterations rather than presenting it as a measured completion log.

## Chapter 4

- Replaced the architecture, module, use-case, activity, sequence and persistence diagrams with readable versions aligned to the implemented system.
- Corrected the generation flow so a usable cache hit returns the stored output without a Gemini request; context and prompt construction occur on a cache miss.
- Separated ordinary document text ingestion from the Gemini multimodal timetable image/PDF extraction workflow.
- Corrected the notification design to Gmail SMTP and labelled the Power Automate/Teams workflow as an external forwarding configuration.
- Corrected multiplayer routes to the implemented POST endpoints: `/host-game`, `/join-game`, `/start-game`, `/get-game-status`, `/update-score` and `/get-leaderboard`; removed placeholder `/api/rooms/<code>` assumptions.
- Corrected persistence descriptions: `mistakes_bank` is embedded in notebook documents, XP/streak fields are not persisted, and multiplayer `active_games` state is in memory.
- Added use-case specifications, document-schema tables, native Word equations and explicit explanations of project-specific retention and selection heuristics.

## Chapter 5

- Reorganised implementation content into REST/API handling and subsystem-specific sections.
- Corrected ingestion, caching, JSON/SSE generation, quiz/mistake storage, weakness drill, reminder, timetable/calendar, multiplayer and analytics descriptions to match the verified implementation boundary.
- Expanded Table 5.1 to include all six implemented multiplayer POST routes, including game-status polling and leaderboard retrieval.
- Reorganised the operation walkthrough around the three core objectives, with multiplayer retained as an additional workflow.
- Preserved the existing notification screenshots and replaced missing application captures with 20 clearly labelled screenshot placeholders; every placeholder is paired with its own caption and explanatory paragraph.

## Chapter 6

- Replaced unsupported evaluation claims with reproducible evidence and explicit limits.
- Recorded controlled PDF/PPTX extraction-and-chunking fixtures, eight retention calculation cases and four mistake-storage/selection checks.
- Recorded the existing automated-test result exactly as executed on 7 September 2026:
  - Working directory: `C:/src/FYP/backend`
  - Command: `C:/src/FYP/.venv/Scripts/python.exe -B -m unittest tests.test_automation_engine tests.test_timetable_feature`
  - Result: 9 tests passed in 1.010 seconds; no coverage report was generated.
- Retained developer functional verification as manual evidence and distinguished it from automated tests, measured performance and a formal learner study.
- Added requirement traceability for FR-01 to FR-21 and evidence boundaries for NFR-01 to NFR-06.
- Added clearly labelled placeholders for unavailable live AI latency/success, timetable extraction accuracy, SSE time to first token, and API/database response-time measurements.
- Evaluated achievement against the three functional objectives without claiming learning gains, verified 50-player capacity or unmeasured service performance.

## Chapter 7

- Consolidated the conclusion around the three objectives and their supporting evidence.
- Separated implemented contributions from limitations and future extensions.
- Retained explicit limits concerning AI output review, backend token verification, unsigned revision links, in-memory multiplayer rooms and unavailable quantitative/live-service measurements.

## Final consistency and layout validation

- Removed supervisor comments and comment relationships from the clean V5 DOCX.
- Renumbered Chapter 5 figures, Chapter 6 tables and IEEE references after structural edits.
- Verified the Chapter 5 roadmap, analytics and multiplayer placeholders are in the correct order and that placeholder rows do not split across pages.
- Exported and visually inspected all 81 pages for clipping, table overflow, blank pages, orphaned figure captions and unreadable diagrams.
- Remaining placeholders are deliberate: 20 application screenshots and four quantitative evaluation result fields require genuine captures or measurements before submission.
