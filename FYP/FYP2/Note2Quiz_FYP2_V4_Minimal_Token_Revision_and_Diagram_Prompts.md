# Note2Quiz FYP2 V3 → V4 — Minimal-Token Revision + Diagram Prompt Extraction

## Goal

Use the **minimum possible Codex usage**.

Work from:

`FYP2_Final_Report_Note2Quiz_V3_FinalReview.docx`

Do **not** restart a full repository audit.

Do **not** web-search.

Do **not** regenerate Chapter 4 diagrams inside Codex.

Instead:

1. make only the targeted DOCX corrections listed below;
2. generate a separate Markdown file containing accurate prompts for the Chapter 4 diagrams that must be regenerated externally.

---

# OUTPUT FILES

Create:

`FYP2_Final_Report_Note2Quiz_V4_PendingDiagrams.docx`

and:

`Note2Quiz_Chapter4_Final_Diagram_Prompts.md`

and a short:

`FYP2_V4_CHANGELOG.md`

Keep V3 unchanged.

Do not modify any source-code files.

---

# SOURCE-OF-TRUTH FACTS

Use these facts directly. Do not re-check the full repository unless one specific detail cannot be resolved.

- Frontend: Flutter.
- Backend: Flask.
- Main persistence: MongoDB.
- Local JSON fallback is used where applicable.
- Firebase Authentication is used on the client.
- Flask `/login` accepts an email/profile request but does **not** verify a Firebase ID token.
- Gmail SMTP is the implemented email channel.
- SMTP defaults: `smtp.gmail.com`, port `587`, `STARTTLS`.
- Google App Password is used for SMTP account setup.
- Power Automate / Teams forwarding is external to the Note2Quiz backend.
- Revision links are parameterised.
- HMAC signing, expiry and signature validation are **not** implemented.
- Notebook ingestion supports PDF, PPTX, best-effort legacy PPT, DOCX, TXT and available YouTube captions.
- General OCR of lecture images is not implemented.
- Timetable extraction uses Gemini multimodal image/PDF processing.
- Source context ranking uses a project-specific keyword/list-marker heuristic.
- Request caching uses SHA-256.
- No TF-IDF pipeline is implemented.
- No MD5 caching is implemented.
- No vector embedding store is implemented.
- Structured quizzes, flashcards and mind maps use the structured JSON generation route.
- Briefing/study text can use the SSE streaming route.
- Weakness drill selects up to six distinct stored mistakes.
- `mistakes_bank` is embedded inside notebook records.
- Multiplayer rooms use in-memory `active_games`.
- Multiplayer uses REST polling for room/game state.
- Questions are client-paced after shared start status.
- Clients submit scores; backend sorts leaderboard values.
- Multiplayer room state is not persistent across server restarts.
- Backend does not authoritatively recompute all quiz answers/scores.
- No XP award is implemented in the multiplayer backend.
- XP/streak persistence is not implemented.
- 50 participants is a design target only.
- Five-player multiplayer functionality was manually verified.
- All implemented functions were manually verified by the developer.
- No formal user study, SUS questionnaire or participant experiment was conducted.
- The retention model is project-specific and SM-2-inspired, not standard SM-2.
- Retention formula:
  `R(t) = R0 * exp(-t / (7S))`
- Stability factor:
  `S = 1 + 0.65(n - 1)`
- `7S` is a decay time constant, not a seven-day half-life.

---

# PART A — TARGETED DOCX FIXES ONLY

## A1. Authentication wording

In Table 3.2 or equivalent authentication technology description:

Replace wording similar to:

`OAuth token handling and email/password user auth`

with:

`Client-side email/password authentication and session management`

In FR-01, replace wording similar to:

`sign in and log out securely using Firebase email/password credentials`

with:

`sign in and log out using Firebase email/password authentication`

Keep the limitation that backend Firebase ID-token verification is not implemented.

---

## A2. Chapter 4.2 overclaim

Replace wording similar to:

> ensure high maintainability, fault tolerance, and independent scalability

with:

> support separation of concerns, maintainability, and independent module development.

Do not claim fault tolerance or independently verified scalability.

---

## A3. Chapter 4 Data Dictionary cleanup

For actual persisted-schema tables:

- remove XP/streak fields from the main persisted-field list if they are explicitly marked design-only;
- do not describe `mistakes_bank` as a separate persisted MongoDB collection;
- keep `mistakes_bank` as an embedded notebook field.

If design-only fields are worth retaining, place them in a short note:

> Planned / design-only attributes not persisted in the current prototype.

Do not redesign Figure 4.5.1 in Codex during this pass. Its replacement prompt will be generated in Part B.

---

## A4. Chapter 6 benchmark section

Delete the two old numerical benchmark illustrations:

- Figure 6.1.1 — Retained Latency Illustration
- Figure 6.1.2 — Retained Processing Illustration

Do not regenerate them.

Keep Table 6.1 as a future/performance measurement plan.

Rewrite the beginning of Section 6.1 concisely:

> Quantitative latency benchmarking was not included in the completed evaluation; therefore, no numerical latency results are reported. Table 6.1 identifies the core operations and metrics that could be measured in future performance testing.

Remove wording such as:

- `previously associated with these operations`
- `retained illustration`
- `not validated benchmark evidence`

Update surrounding cross-references after deleting the two figures.

---

## A5. Replace TC-09

Remove the unimplemented Audio Overview acceptance test.

Replace it with:

### TC-09 — Briefing Report / Streamed Study Text Generation

Suggested content:

**Scenario:**  
Generate a briefing report / streamed study text from an uploaded notebook source.

**Input / Preconditions:**  
A notebook contains valid extracted source material; user selects briefing/study-text generation.

**Expected Output:**  
Generated study text is returned through the implemented generation/SSE workflow and rendered successfully by the client.

**Recorded Evidence:**  
Manually executed by the developer; observed behaviour matched the expected result.

**Status:**  
`Functionally Verified`

Keep the total number of acceptance scenarios at 16.

Do not invent latency values or participant data.

---

## A6. Automated tests

If the existing environment is already ready, run the existing automated tests **once only**, without modifying source code.

Relevant test files:

- `backend/tests/test_automation_engine.py`
- `backend/tests/test_timetable_feature.py`

If nine tests genuinely pass, update Chapter 6 with the exact real result, for example:

> All nine defined automated test methods passed during final system verification.

Do not claim `100% code coverage`.

If the tests cannot be executed quickly, do not spend time debugging the environment. Keep conservative wording and replace:

`not re-executed during this revision`

with:

`automated execution results were not included in the final evaluation.`

---

## A7. Remove audit/change-history voice

Search only Chapters 4–7 for these phrases:

- `during this revision`
- `previously associated`
- `retained illustration`

Rewrite them in normal thesis language.

### Important exception

Do **not** remove the temporary Chapter 4 statements explaining that the current diagrams are earlier designs **until those diagrams are actually replaced**.

The Chapter 4 diagram replacements will be generated externally from the prompts in Part B.

---

## A8. Chapter 5 Audio placeholder

Audio synthesis is not implemented.

Do not generate a fake screenshot.

If Figure 5.3.9 still presents Audio Overview as part of the implemented walkthrough:

- remove it from the implemented walkthrough; or
- clearly move it to a planned/future-work note.

Prefer removing the screenshot placeholder from the implemented walkthrough.

Renumber later Chapter 5 figures only if necessary and update cross-references consistently.

Do not alter other Chapter 5 screenshot placeholders.

---

## A9. British English — targeted pass only

Fix remaining normal-prose/caption spellings such as:

- Centralized → Centralised
- Synchronization → Synchronisation
- Synchronized → Synchronised
- visualization → visualisation
- color → colour
- colored → coloured

Do not change:

- source-code identifiers;
- class names;
- API names;
- filenames;
- package names;
- URLs.

---

## A10. Formatting — minimal pass only

Do not reformat the entire document.

Only correct obvious affected paragraphs/captions created by this revision.

Preserve:

- page breaks;
- tables;
- equations;
- headers/footers;
- existing Chapter 5 placeholders.

Do not spend time rebuilding Word styles across the full document in this pass.

---

# PART B — GENERATE PROMPTS ONLY FOR CHAPTER 4 DIAGRAMS

Do **not** regenerate, redraw, edit or replace these images inside the DOCX.

Create:

`Note2Quiz_Chapter4_Final_Diagram_Prompts.md`

with exactly these nine figures:

1. Figure 4.1.1 — High-Level 3-Tier System Architecture
2. Figure 4.2.1 — Top-Down Module Hierarchy and Component Decomposition
3. Figure 4.3.1 — System Use Case Diagram
4. Figure 4.4.1 — Multi-Modal Document Ingestion and Semantic RAG Activity Diagram
5. Figure 4.4.2 — AI Studio Structured Generation and SSE Streaming Sequence Diagram
6. Figure 4.4.3 — Dual-Trigger Automated Revision Notification Sequence Diagram
7. Figure 4.4.4 — Multiplayer Quiz Arena Lifecycle Sequence Diagram
8. Figure 4.5.1 — MongoDB Document Schema / Conceptual Relationship Diagram
9. Figure 4.6.1 — Illustrative Project-Specific Retention Estimate

Do not inspect every diagram in the report.

Do not regenerate Chapter 3 diagrams.

Do not generate Chapter 5 screenshots.

Do not generate Chapter 6 performance charts.

---

# REQUIRED FORMAT FOR EACH DIAGRAM PROMPT

For each figure output exactly:

## Figure X.X.X — [Title]

### Purpose
One short paragraph.

### Orientation
Landscape or portrait.

### Must Include
Short bullet list of exact components/actors/data.

### Exact Relationships / Flow
Short ordered list describing arrows and direction.

### Must NOT Include
Short bullet list.

### Image-Generation Prompt
One complete, self-contained prompt ready to paste into an image-generation model.

---

# COMMON VISUAL STYLE FOR ALL 9 PROMPTS

Every image-generation prompt must request:

- clean university thesis / scientific diagram;
- 2D vector appearance;
- white background;
- black/dark-grey readable text;
- restrained blue/teal/green accent colours only;
- consistent visual language across all nine figures;
- flat shapes;
- thin professional connectors/arrows;
- no decorative artwork;
- no unnecessary icons;
- no 3D;
- no heavy gradients;
- high contrast;
- readable at A4 thesis size;
- Times-New-Roman-like academic typography where possible;
- high resolution;
- no embedded figure number;
- no embedded figure caption;
- no watermark.

The DOCX will provide the actual figure caption.

---

# FIGURE-SPECIFIC TECHNICAL REQUIREMENTS

## Figure 4.1.1 — High-Level 3-Tier Architecture

Must show three logical tiers:

### Tier 1 — Presentation Layer
Include:
- Flutter Web/Mobile Client
- Authentication UI
- Notebook Dashboard
- AI Studio
- Timetable/Automation UI
- Mistakes/Analytics UI
- Multiplayer UI

### Tier 2 — Flask Application / Business Logic
Include:
- REST API routes
- Document extraction
- Generative AI orchestration
- SSE text streaming
- Weakness drill logic
- Retention/mastery calculation
- Timetable/calendar service
- APScheduler / notifier
- Multiplayer `active_games`

### Tier 3 — Data / External Services
Include:
- MongoDB
- local JSON fallback where applicable
- Gemini API
- Firebase Authentication
- Gmail SMTP
- Google Calendar API

Do NOT show:
- Resend
- HMAC token service
- vector database
- general OCR service
- independently deployed microservices

---

## Figure 4.2.1 — Module Hierarchy

Top node:
`Note2Quiz`

Recommended major modules:
1. Authentication & User Session
2. Notebook & Source Management
3. AI Study Studio
4. Quiz & Mistakes Remediation
5. Retention & Analytics
6. Timetable / Calendar / Automation
7. Multiplayer Arena

Under each module, include only implemented subfeatures.

Do NOT include:
- audio synthesis
- persisted XP/streak system
- general lecture-image OCR
- bidirectional calendar synchronisation
- adaptive frequency/recency mistake weighting
- production fault-tolerance claims

---

## Figure 4.3.1 — Use Case Diagram

Actors:
- Student
- Host / Teacher (secondary multiplayer role)
- Firebase Authentication
- Gemini API
- Google Calendar API
- Gmail SMTP
- Background Scheduler

Student use cases should include:
- Register / Sign In
- Manage Notebooks
- Upload Sources
- Generate Quiz / Flashcards / Mind Map / Briefing Text
- Take Solo Quiz
- Review Mistakes
- Generate Weakness Drill
- View Retention / Analytics
- Upload Timetable
- Export `.ics`
- Sync to Google Calendar
- Configure Revision Reminders
- Join Multiplayer Room

Host/Teacher use cases:
- Host Multiplayer Room
- Start Game
- View Leaderboard

Do NOT show:
- Resend
- backend Firebase token verification
- audio generation
- HMAC token generation
- automatic cognitive-state scheduling

---

## Figure 4.4.1 — Ingestion / Context Selection Activity Diagram

Flow:

1. User selects a source.
2. Route by source type:
   - PDF → pypdf
   - PPTX → python-pptx
   - legacy PPT → best-effort printable-text extraction
   - DOCX → python-docx
   - TXT → plain-text handling
   - YouTube URL → available captions/transcript
3. Sanitise/control-character cleanup.
4. Store extracted source text/metadata in notebook.
5. Split source into paragraphs/sentences/chunks.
6. Score candidate chunks using project-specific keyword and list-marker heuristic.
7. Select context within the prompt budget.
8. Construct generation request.
9. Use SHA-256 request cache where applicable.
10. Send selected context to Gemini.

Do NOT show:
- TF-IDF
- embeddings
- vector database
- MD5
- Shannon entropy
- general image OCR
- unsupported semantic-search infrastructure

---

## Figure 4.4.2 — Structured Generation vs SSE Streaming

Clearly show two separate branches.

### Branch A — Structured Studio Items
Flutter Client
→ structured generation request
→ Flask structured generation route
→ select source context
→ Gemini
→ structured JSON response
→ `clean_ai_response()` / parsing
→ quiz / flashcard / mind-map object
→ store/render item

### Branch B — Streaming Study Text
Flutter Client
→ SSE generation request
→ Flask SSE route
→ select source context
→ Gemini generation
→ incremental chunks
→ SSE events
→ progressive client rendering

Do NOT merge the two branches into one JSON/SSE pipeline.

Do NOT claim latency guarantees.

---

## Figure 4.4.3 — Revision Notification Sequence

Actors/components:
- APScheduler
- `jobs/notifier.py`
- automation record / MongoDB
- Gmail SMTP
- Student email/client
- revision web route

Flow:
1. Scheduler invokes notifier periodically.
2. Notifier checks due automation entries.
3. Primary reminder:
   - claim/update due state;
   - build HTML email;
   - include parameterised revision link;
   - send through Gmail SMTP;
   - record delivery state.
4. Optional evening follow-up:
   - only when configured;
   - primary reminder already sent;
   - revision remains incomplete.
5. User opens revision link.
6. Backend selects revision context using notebook/week/user parameters.

Do NOT show:
- Resend
- HMAC
- signed tokens
- token expiry
- pre-generated AI quiz before dispatch
- retention-score-triggered dispatch

---

## Figure 4.4.4 — Multiplayer Sequence

Actors/components:
- Host Client
- Student Client(s)
- Flask Backend
- in-memory `active_games`

Flow:
1. Host creates room.
2. Backend generates 6-character room code and stores room in memory.
3. Students join using room code.
4. Clients poll room/start state.
5. Host starts game.
6. Shared start status becomes active.
7. Each client progresses through questions locally.
8. Client calculates/submits its score.
9. Backend stores submitted score in room state.
10. Leaderboard endpoint sorts scores.
11. Host/student retrieves final leaderboard/podium.

Do NOT show:
- MongoDB game-room persistence
- server broadcast of every question
- server-authoritative answer validation
- speed-bonus computation unless actually implemented
- XP award
- persistent reconnect/restart recovery

---

## Figure 4.5.1 — MongoDB Document Schema / Conceptual Relationships

Use a document-oriented conceptual model, not a misleading relational ERD.

Show:

### `users`
Core persisted fields only.

### `notebooks`
Include:
- owner/user email
- title
- sources[]
- history[]
- mistakes_bank[]

Show `mistakes_bank[]` visually as **embedded inside notebook**, not a separate collection.

### `course_automations`
Show automation/schedule ownership/reference fields used by the implemented scheduler.

### timetable/calendar-related stored data
Include only if actually persisted in the current schema.

Do NOT show as persisted:
- XP
- streak
- separate Mistakes Bank collection
- multiplayer room collection
- unsupported relational foreign-key constraints

Add a small diagram note:
`Multiplayer active_games state is in-memory and is not persisted in MongoDB.`

---

## Figure 4.6.1 — Project-Specific Retention Estimate

Title inside the diagram should be descriptive only, not a figure caption:

`Illustrative Project-Specific Retention Estimate`

Show:

`S = 1 + 0.65(n - 1)`

and:

`R(t) = R0 × exp(-t / (7S))`

State visually:

`7S = decay time constant`

Use illustrative example review points only.

Make clear:
- review points are examples;
- intervals are not automatically generated by standard SM-2;
- this is not a calibrated cognitive-memory measurement.

Include UI status zones:
- Fresh / Mastered: `R >= 80`
- Fading: `50 <= R < 80`
- At Risk: `R < 50`

Do NOT call it:
- Modified SM-2
- standard SM-2
- scientifically calibrated memory prediction

---

# PART C — DO NOT TOUCH THESE

Do not spend tokens re-checking or rewriting:

- Chapter 1 objectives unless a figure number changes;
- Chapter 2 comparison matrix;
- IEEE reference order;
- Gmail/Resend correction;
- HMAC correction;
- five-player vs 50-player clarification;
- manual functional verification wording;
- no-user-study clarification;
- retention equation;
- weakness-drill algorithm;
- RAG heuristic explanation;
- Chapter 3 SDLC diagrams.

---

# FINAL VALIDATION

Do only a short targeted check.

Confirm:

- V3 remains unchanged;
- V4 opens successfully;
- Chapters 1–7 remain;
- References remain;
- Tables/equations remain intact;
- Figure 6.1.1 and 6.1.2 are removed;
- TC-09 now covers Briefing Report / SSE;
- no fake benchmark or user-study data was added;
- Chapter 4 old diagrams remain untouched for now;
- `Note2Quiz_Chapter4_Final_Diagram_Prompts.md` contains exactly 9 complete prompts;
- no source-code file was modified.

Do not render/review the entire 76-page report again unless document integrity fails.

Two additional targeted wording fixes:

1. In Section 3.1.4, replace wording such as
"the engineering team constructed a robust baseline"
with
"the project established a functional baseline".

2. Replace wording such as
"mathematical spaced retention engine, optical timetable parser"
with
"project-specific retention estimator, vision-based timetable extraction module".

Do not re-audit Chapter 3.