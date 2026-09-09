## Figure 4.1.1 — High-Level 3-Tier System Architecture

### Purpose
Show the three logical application tiers and the actual service boundaries.

### Orientation
Landscape.

### Must Include
- Flutter Web/Mobile Client: Authentication UI, Notebook Dashboard, AI Studio, Timetable/Automation UI, Mistakes/Analytics UI, Multiplayer UI.
- Flask: REST routes, extraction, AI orchestration, SSE text streaming, weakness drills, retention/mastery, timetable/calendar, APScheduler/notifier, in-memory active_games.
- MongoDB; local JSON fallback where applicable; Gemini API; Firebase Authentication; Gmail SMTP; Google Calendar API.

### Exact Relationships / Flow
1. Flutter UI → Flask over REST; Flask SSE route → Flutter progressive text.
2. Authentication UI ↔ Firebase Authentication directly; Flutter → Flask /login email/profile request, annotated “No Firebase ID-token verification”.
3. Flask ↔ MongoDB; applicable persistence paths ↔ local JSON fallback.
4. AI orchestration/timetable extraction ↔ Gemini API; calendar service → Google Calendar API.
5. APScheduler → notifier → Gmail SMTP → student email; in-memory active_games stays within Flask.

### Must NOT Include
- Resend, HMAC service, vector database or general OCR service.
- Independent microservices, backend token verification or production security/scalability guarantees.

### Image-Generation Prompt
Create a landscape diagram of High-Level 3-Tier System Architecture. Show the three logical application tiers and the actual service boundaries. Include: Flutter Web/Mobile Client: Authentication UI, Notebook Dashboard, AI Studio, Timetable/Automation UI, Mistakes/Analytics UI, Multiplayer UI. Flask: REST routes, extraction, AI orchestration, SSE text streaming, weakness drills, retention/mastery, timetable/calendar, APScheduler/notifier, in-memory active_games. MongoDB; local JSON fallback where applicable; Gemini API; Firebase Authentication; Gmail SMTP; Google Calendar API. Exact flow and relationships: 1. Flutter UI → Flask over REST; Flask SSE route → Flutter progressive text. 2. Authentication UI ↔ Firebase Authentication directly; Flutter → Flask /login email/profile request, annotated “No Firebase ID-token verification”. 3. Flask ↔ MongoDB; applicable persistence paths ↔ local JSON fallback. 4. AI orchestration/timetable extraction ↔ Gemini API; calendar service → Google Calendar API. 5. APScheduler → notifier → Gmail SMTP → student email; in-memory active_games stays within Flask. Exclude: Resend, HMAC service, vector database or general OCR service. Independent microservices, backend token verification or production security/scalability guarantees. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.2.1 — Top-Down Module Hierarchy and Component Decomposition

### Purpose
Show implemented feature ownership in a top-down module tree.

### Orientation
Landscape.

### Must Include
- Root: Note2Quiz.
- Authentication & User Session: Firebase email/password sign-in, client session, email/profile registration.
- Notebook & Source Management: notebooks, supported file text extraction, YouTube captions.
- AI Study Studio: quizzes, flashcards, mind maps, briefing/study text, JSON generation and SSE text.
- Quiz & Mistakes Remediation: solo quiz, embedded distinct mistakes, first-six drill selection.
- Retention & Analytics: project-specific estimate, course summaries.
- Timetable / Calendar / Automation: Gemini extraction, .ics export, outbound Google Calendar sync, configured primary/evening reminders.
- Multiplayer Arena: host/join, REST polling, shared start, client-paced quiz, submitted scores, sorted leaderboard.

### Exact Relationships / Flow
1. Root → seven major modules using decomposition connectors.
2. Each major module → its listed implemented subfeatures.
3. Use hierarchy connectors only; do not imply separate deployments or execution order.

### Must NOT Include
- Audio synthesis, persisted XP/streaks, lecture-image OCR, bidirectional calendar sync.
- Frequency/recency mistake weighting or production fault tolerance.

### Image-Generation Prompt
Create a landscape diagram of Top-Down Module Hierarchy and Component Decomposition. Show implemented feature ownership in a top-down module tree. Include: Root: Note2Quiz. Authentication & User Session: Firebase email/password sign-in, client session, email/profile registration. Notebook & Source Management: notebooks, supported file text extraction, YouTube captions. AI Study Studio: quizzes, flashcards, mind maps, briefing/study text, JSON generation and SSE text. Quiz & Mistakes Remediation: solo quiz, embedded distinct mistakes, first-six drill selection. Retention & Analytics: project-specific estimate, course summaries. Timetable / Calendar / Automation: Gemini extraction, .ics export, outbound Google Calendar sync, configured primary/evening reminders. Multiplayer Arena: host/join, REST polling, shared start, client-paced quiz, submitted scores, sorted leaderboard. Exact flow and relationships: 1. Root → seven major modules using decomposition connectors. 2. Each major module → its listed implemented subfeatures. 3. Use hierarchy connectors only; do not imply separate deployments or execution order. Exclude: Audio synthesis, persisted XP/streaks, lecture-image OCR, bidirectional calendar sync. Frequency/recency mistake weighting or production fault tolerance. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.3.1 — System Use Case Diagram

### Purpose
Show user goals and their supporting external actors without implying backend token verification.

### Orientation
Landscape.

### Must Include
- Actors: Student; Host / Teacher (secondary multiplayer role); Firebase Authentication; Gemini API; Google Calendar API; Gmail SMTP; Background Scheduler.
- Student goals: Register / Sign In; Manage Notebooks; Upload Sources; Generate Quiz / Flashcards / Mind Map / Briefing Text; Take Solo Quiz; Review Mistakes; Generate Weakness Drill; View Retention / Analytics; Upload Timetable; Export .ics; Sync to Google Calendar; Configure Revision Reminders; Join Multiplayer Room.
- Host goals: Host Multiplayer Room; Start Game; View Leaderboard.
- Internal supporting use case: Dispatch Revision Reminder.

### Exact Relationships / Flow
1. Place user goals inside Note2Quiz system boundary; Student and Host/Teacher outside. Connect each role to its listed goals.
2. Register / Sign In ↔ Firebase; generation, drill and timetable extraction ↔ Gemini.
3. Sync to Google Calendar → Google Calendar API; Export .ics → local file, independent of the API.
4. Background Scheduler → Dispatch Revision Reminder → Gmail SMTP; configuration belongs to Student.
5. Use association lines, with arrow direction only for external invocation; do not invent include/extend relationships.

### Must NOT Include
- Resend, backend Firebase token verification, audio generation, HMAC generation.
- Automatic cognitive-state scheduling or formal user-study actors.

### Image-Generation Prompt
Create a landscape diagram of System Use Case Diagram. Show user goals and their supporting external actors without implying backend token verification. Include: Actors: Student; Host / Teacher (secondary multiplayer role); Firebase Authentication; Gemini API; Google Calendar API; Gmail SMTP; Background Scheduler. Student goals: Register / Sign In; Manage Notebooks; Upload Sources; Generate Quiz / Flashcards / Mind Map / Briefing Text; Take Solo Quiz; Review Mistakes; Generate Weakness Drill; View Retention / Analytics; Upload Timetable; Export .ics; Sync to Google Calendar; Configure Revision Reminders; Join Multiplayer Room. Host goals: Host Multiplayer Room; Start Game; View Leaderboard. Internal supporting use case: Dispatch Revision Reminder. Exact flow and relationships: 1. Place user goals inside Note2Quiz system boundary; Student and Host/Teacher outside. Connect each role to its listed goals. 2. Register / Sign In ↔ Firebase; generation, drill and timetable extraction ↔ Gemini. 3. Sync to Google Calendar → Google Calendar API; Export .ics → local file, independent of the API. 4. Background Scheduler → Dispatch Revision Reminder → Gmail SMTP; configuration belongs to Student. 5. Use association lines, with arrow direction only for external invocation; do not invent include/extend relationships. Exclude: Resend, backend Firebase token verification, audio generation, HMAC generation. Automatic cognitive-state scheduling or formal user-study actors. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.4.1 — Multi-Modal Document Ingestion and Semantic RAG Activity Diagram

### Purpose
Show source extraction and request-time context selection without unsupported search infrastructure.

### Orientation
Portrait.

### Must Include
- Source-type decision: PDF/pypdf; PPTX/python-pptx; legacy PPT/best-effort printable text; DOCX/python-docx; TXT/plain text; YouTube/available captions.
- Sanitisation; notebook source text/metadata; paragraph/sentence chunks; keyword/list-marker ranking; prompt budget; SHA-256 cache; Gemini.

### Exact Relationships / Flow
1. User selects source → type decision → appropriate extractor; merge successful text paths.
2. Extracted text → control-character cleanup → notebook source text/metadata storage.
3. Generation request reads stored text → paragraph/sentence chunks → keyword/list-marker scoring.
4. Ranked chunks → selection within prompt budget → generation request.
5. Compute SHA-256 request cache key → hit/miss decision; hit → return cached output.
6. Miss → Gemini with selected context → response → cache where applicable → caller.

### Must NOT Include
- TF-IDF, embeddings, vector databases, MD5, Shannon entropy, general image OCR or semantic-search infrastructure.

### Image-Generation Prompt
Create a portrait diagram of Multi-Modal Document Ingestion and Semantic RAG Activity Diagram. Show source extraction and request-time context selection without unsupported search infrastructure. Include: Source-type decision: PDF/pypdf; PPTX/python-pptx; legacy PPT/best-effort printable text; DOCX/python-docx; TXT/plain text; YouTube/available captions. Sanitisation; notebook source text/metadata; paragraph/sentence chunks; keyword/list-marker ranking; prompt budget; SHA-256 cache; Gemini. Exact flow and relationships: 1. User selects source → type decision → appropriate extractor; merge successful text paths. 2. Extracted text → control-character cleanup → notebook source text/metadata storage. 3. Generation request reads stored text → paragraph/sentence chunks → keyword/list-marker scoring. 4. Ranked chunks → selection within prompt budget → generation request. 5. Compute SHA-256 request cache key → hit/miss decision; hit → return cached output. 6. Miss → Gemini with selected context → response → cache where applicable → caller. Exclude: TF-IDF, embeddings, vector databases, MD5, Shannon entropy, general image OCR or semantic-search infrastructure. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.4.2 — AI Studio Structured Generation and SSE Streaming Sequence Diagram

### Purpose
Separate structured JSON generation from progressively streamed study text.

### Orientation
Landscape.

### Must Include
- Lifelines: Flutter Client; Flask structured route; Flask SSE route; source/context preparation; Gemini API; notebook storage.
- Separate alternatives: A Structured Studio Items; B Streaming Study Text.
- clean_ai_response() and parsing only on structured branch; incremental SSE events on text branch.

### Exact Relationships / Flow
1. A: Flutter → structured request → Flask structured route → source context → Gemini.
2. A: Gemini → structured JSON → clean_ai_response()/parsing → quiz/flashcard/mind-map object → store/render.
3. B: Flutter → SSE request → Flask SSE route → source context → Gemini text generation.
4. B: Gemini incremental chunks → Flask SSE events → Flutter progressive rendering.
5. Keep branches visibly separate; no structured JSON parser on the SSE chunk arrow.

### Must NOT Include
- A merged JSON/SSE pipeline, audio generation or latency guarantees.

### Image-Generation Prompt
Create a landscape diagram of AI Studio Structured Generation and SSE Streaming Sequence Diagram. Separate structured JSON generation from progressively streamed study text. Include: Lifelines: Flutter Client; Flask structured route; Flask SSE route; source/context preparation; Gemini API; notebook storage. Separate alternatives: A Structured Studio Items; B Streaming Study Text. clean_ai_response() and parsing only on structured branch; incremental SSE events on text branch. Exact flow and relationships: 1. A: Flutter → structured request → Flask structured route → source context → Gemini. 2. A: Gemini → structured JSON → clean_ai_response()/parsing → quiz/flashcard/mind-map object → store/render. 3. B: Flutter → SSE request → Flask SSE route → source context → Gemini text generation. 4. B: Gemini incremental chunks → Flask SSE events → Flutter progressive rendering. 5. Keep branches visibly separate; no structured JSON parser on the SSE chunk arrow. Exclude: A merged JSON/SSE pipeline, audio generation or latency guarantees. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.4.3 — Dual-Trigger Automated Revision Notification Sequence Diagram

### Purpose
Show schedule-driven primary and optional evening email reminders and revision navigation.

### Orientation
Landscape.

### Must Include
- APScheduler; jobs/notifier.py; automation record/MongoDB; Gmail SMTP; Student email/client; revision web route.
- Primary delivery state; optional evening follow-up guard; notebook/week/user-email parameters.
- smtp.gmail.com:587; STARTTLS; configured Google App Password credentials.

### Exact Relationships / Flow
1. APScheduler periodically → notifier → query due MongoDB automation entries.
2. Primary: notifier → conditional claim/update due state → build HTML with parameterised revision link.
3. Notifier → Gmail SMTP using STARTTLS and configured credentials → Student email; notifier → record delivery state.
4. Optional evening branch: configured AND primary reminder sent AND revision incomplete → follow-up dispatch.
5. Student opens web link → revision web route → select context from notebook/week/user-email parameters.

### Must NOT Include
- Resend, HMAC, signed tokens, expiry or signature validation.
- Pre-generated AI quiz before dispatch or retention-score-triggered reminders.
- Power Automate/Teams as a backend module.

### Image-Generation Prompt
Create a landscape diagram of Dual-Trigger Automated Revision Notification Sequence Diagram. Show schedule-driven primary and optional evening email reminders and revision navigation. Include: APScheduler; jobs/notifier.py; automation record/MongoDB; Gmail SMTP; Student email/client; revision web route. Primary delivery state; optional evening follow-up guard; notebook/week/user-email parameters. smtp.gmail.com:587; STARTTLS; configured Google App Password credentials. Exact flow and relationships: 1. APScheduler periodically → notifier → query due MongoDB automation entries. 2. Primary: notifier → conditional claim/update due state → build HTML with parameterised revision link. 3. Notifier → Gmail SMTP using STARTTLS and configured credentials → Student email; notifier → record delivery state. 4. Optional evening branch: configured AND primary reminder sent AND revision incomplete → follow-up dispatch. 5. Student opens web link → revision web route → select context from notebook/week/user-email parameters. Exclude: Resend, HMAC, signed tokens, expiry or signature validation. Pre-generated AI quiz before dispatch or retention-score-triggered reminders. Power Automate/Teams as a backend module. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.4.4 — Multiplayer Quiz Arena Lifecycle Sequence Diagram

### Purpose
Show REST-polled multiplayer state and client-paced scoring.

### Orientation
Landscape.

### Must Include
- Host Client; Student Client(s); Flask Backend; in-memory active_games.
- Six-character room code; REST polling; shared game-start state; client questions and scores; sorted leaderboard.

### Exact Relationships / Flow
1. Host → Flask: create room; Flask → active_games: generated six-character code and room state.
2. Students → Flask: join by code → active_games player entries.
3. Clients → Flask: recurring REST state polling; Host → Flask: start → active_games shared start status.
4. Polling response → clients: shared start; each client advances questions locally.
5. Client → Flask: submitted client-calculated score → active_games.
6. Leaderboard request → Flask sorts submitted values → host/student leaderboard or podium.

### Must NOT Include
- MongoDB room persistence, server question broadcasts or authoritative answer validation.
- Speed bonuses, XP awards or persistent reconnect/restart recovery.
- Verified 50-player capacity; only five-player functionality was manually verified.

### Image-Generation Prompt
Create a landscape diagram of Multiplayer Quiz Arena Lifecycle Sequence Diagram. Show REST-polled multiplayer state and client-paced scoring. Include: Host Client; Student Client(s); Flask Backend; in-memory active_games. Six-character room code; REST polling; shared game-start state; client questions and scores; sorted leaderboard. Exact flow and relationships: 1. Host → Flask: create room; Flask → active_games: generated six-character code and room state. 2. Students → Flask: join by code → active_games player entries. 3. Clients → Flask: recurring REST state polling; Host → Flask: start → active_games shared start status. 4. Polling response → clients: shared start; each client advances questions locally. 5. Client → Flask: submitted client-calculated score → active_games. 6. Leaderboard request → Flask sorts submitted values → host/student leaderboard or podium. Exclude: MongoDB room persistence, server question broadcasts or authoritative answer validation. Speed bonuses, XP awards or persistent reconnect/restart recovery. Verified 50-player capacity; only five-player functionality was manually verified. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.5.1 — MongoDB Document Schema / Conceptual Relationship Diagram

### Purpose
Show MongoDB document containment and logical references without relational constraints.

### Orientation
Landscape.

### Must Include
- users: _id, email, created_at, role.
- notebooks: _id, user_email, title, created_at, sources[], history[], mistakes_bank[].
- Embed mistake entries with id, question, user_answer, correct_answer, explanation, recorded_at; embed sources with id, title, content, type and date.
- course_automations: _id, notebook_id, user_email, course_name, class_day, class_start_time, class_end_time, semester_start_date, total_weeks, weekly_schedule[].
- timetables: _id, user_email, semester_start_date, courses[], created_at, updated_at.
- Note: Multiplayer active_games state is in-memory and is not persisted in MongoDB.

### Exact Relationships / Flow
1. users.email → notebooks.user_email, course_automations.user_email and timetables.user_email as logical ownership references.
2. course_automations.notebook_id → notebooks._id as application reference, not relational foreign-key enforcement.
3. Contain sources[], history[] and mistakes_bank[] inside the notebook box.
4. Contain weekly_schedule[] inside course_automations and courses[] inside timetables.
5. Place in-memory multiplayer note outside the persisted document boxes; no game-room collection.

### Must NOT Include
- Persisted XP/streaks, a separate Mistakes Bank collection, multiplayer-room collection.
- Unsupported relational foreign keys, client-only settings as persisted user fields or vector collections.

### Image-Generation Prompt
Create a landscape diagram of MongoDB Document Schema / Conceptual Relationship Diagram. Show MongoDB document containment and logical references without relational constraints. Include: users: _id, email, created_at, role. notebooks: _id, user_email, title, created_at, sources[], history[], mistakes_bank[]. Embed mistake entries with id, question, user_answer, correct_answer, explanation, recorded_at; embed sources with id, title, content, type and date. course_automations: _id, notebook_id, user_email, course_name, class_day, class_start_time, class_end_time, semester_start_date, total_weeks, weekly_schedule[]. timetables: _id, user_email, semester_start_date, courses[], created_at, updated_at. Note: Multiplayer active_games state is in-memory and is not persisted in MongoDB. Exact flow and relationships: 1. users.email → notebooks.user_email, course_automations.user_email and timetables.user_email as logical ownership references. 2. course_automations.notebook_id → notebooks._id as application reference, not relational foreign-key enforcement. 3. Contain sources[], history[] and mistakes_bank[] inside the notebook box. 4. Contain weekly_schedule[] inside course_automations and courses[] inside timetables. 5. Place in-memory multiplayer note outside the persisted document boxes; no game-room collection. Exclude: Persisted XP/streaks, a separate Mistakes Bank collection, multiplayer-room collection. Unsupported relational foreign keys, client-only settings as persisted user fields or vector collections. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.

## Figure 4.6.1 — Illustrative Project-Specific Retention Estimate

### Purpose
Illustrate the implemented retention heuristic and display thresholds without claiming measured memory.

### Orientation
Landscape.

### Must Include
- Descriptive internal title: Illustrative Project-Specific Retention Estimate.
- S = 1 + 0.65(n - 1); R(t) = R0 × exp(-t / (7S)); 7S = decay time constant.
- Axes: elapsed days since example review; estimated retention score (0–100).
- UI zones: Fresh / Mastered R >= 80; Fading 50 <= R < 80; At Risk R < 50.
- Example curves from R0 = 100 at t = 0 with n = 1 and n = 4, giving S = 1 and S = 2.95. Label values and review points illustrative, not observed results.

### Exact Relationships / Flow
1. Example review origin at t = 0 → supplied n determines S → each curve decays with the displayed equation.
2. Plot two labelled example curves for n = 1 and n = 4 across 0–21 elapsed days; do not draw an automatic review schedule.
3. Place horizontal zone boundaries at 80 and 50.
4. Annotate “Illustrative review points; intervals are not generated by standard SM-2” and “Not a calibrated cognitive-memory measurement”.

### Must NOT Include
- “Modified SM-2”, a standard SM-2 model label, a seven-day half-life or scientifically calibrated prediction.
- Measured participant data, an automatic review schedule or educational-effectiveness claims.

### Image-Generation Prompt
Create a landscape diagram of Illustrative Project-Specific Retention Estimate. Illustrate the implemented retention heuristic and display thresholds without claiming measured memory. Include: Descriptive internal title: Illustrative Project-Specific Retention Estimate. S = 1 + 0.65(n - 1); R(t) = R0 × exp(-t / (7S)); 7S = decay time constant. Axes: elapsed days since example review; estimated retention score (0–100). UI zones: Fresh / Mastered R >= 80; Fading 50 <= R < 80; At Risk R < 50. Example curves from R0 = 100 at t = 0 with n = 1 and n = 4, giving S = 1 and S = 2.95. Label values and review points illustrative, not observed results. Exact flow and relationships: 1. Example review origin at t = 0 → supplied n determines S → each curve decays with the displayed equation. 2. Plot two labelled example curves for n = 1 and n = 4 across 0–21 elapsed days; do not draw an automatic review schedule. 3. Place horizontal zone boundaries at 80 and 50. 4. Annotate “Illustrative review points; intervals are not generated by standard SM-2” and “Not a calibrated cognitive-memory measurement”. Exclude: “Modified SM-2”, a standard SM-2 model label, a seven-day half-life or scientifically calibrated prediction. Measured participant data, an automatic review schedule or educational-effectiveness claims. Use a clean university thesis/scientific diagram with a 2D vector appearance, white background, black/dark-grey readable text, restrained blue/teal/green accent colours only, and a consistent visual language across all nine figures. Use flat shapes, thin professional connectors/arrows, high contrast, Times-New-Roman-like academic typography where possible, high resolution and text readable at A4 thesis size. No decorative artwork, unnecessary icons, 3D, heavy gradients, embedded figure number, embedded figure caption or watermark.
