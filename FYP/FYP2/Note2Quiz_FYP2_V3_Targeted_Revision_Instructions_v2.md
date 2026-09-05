# Note2Quiz FYP2 V2 — Targeted DOCX Revision Instructions

## Scope
Modify **only** `FYP2_Final_Report_Note2Quiz_V2_Reviewed.docx`.

Do not modify source-code files.  
Do not re-audit the whole repository.  
Do not use web search unless absolutely necessary.  
Use the current V2 report and already-established source-code findings as the source of truth.

Save as:
`FYP2_Final_Report_Note2Quiz_V3_FinalReview.docx`

Keep V2 unchanged.

---

## 1. Chapter 1 — Objective 4
Current Objective 4 still overstates the sophistication of the weakness-remediation logic.

Replace it with wording close to:

> **Objective 4 (Mistakes Remediation and Learning Analytics):** Construct a persistent Mistakes Bank and weakness-drill generator that records distinct quiz errors and uses stored mistakes to generate targeted remedial practice. Provide course-level analytics using the implemented retention estimate and mistake records. Evaluate the implemented error-storage workflow, drill-generation path, and analytics calculations against the available technical evidence.

Do not claim frequency weighting, recency weighting, Softmax sampling, or a separate adaptive misconception-priority model.

---

## 2. Chapter 2 — Table 2.5
Where competitor capabilities are not positively confirmed by the reviewed sources, change absolute `No` entries to:

`Not established`

Keep supported `Yes` / `Partial` values.

Do not claim market-wide feature absence.

---

## 3. Chapter 3 — SDLC wording
Replace:

> Selecting an appropriate System Development Life Cycle (SDLC) model is critical to ensuring architectural stability, user satisfaction, and timely milestone completion.

with:

> Selecting an appropriate System Development Life Cycle (SDLC) model supports structured development, iterative refinement, and milestone management.

Replace wording similar to:

> Waterfall's fundamental inability to accommodate evolving user feedback or AI prompt tuning...

with:

> Waterfall provides limited flexibility for frequent requirement changes and iterative AI prompt refinement...

Avoid `fundamental inability`, `guarantees`, and unmeasured `user satisfaction`.

---

## 4. Chapter 3 — Evolutionary Prototyping
The generic prototyping explanation mentions end-user feedback, while Note2Quiz had no formal user study.

Use wording close to:

> The prototype is iteratively reviewed and refined based on implementation findings, stakeholder feedback, and evolving requirements.

In the Note2Quiz-specific justification, keep:
- no undergraduate test cohort;
- no usability questionnaire;
- no formal user evaluation.

Optionally add:

> For Note2Quiz, iterations were primarily developer-led and informed by implementation findings and project supervision rather than a formal end-user study.

Do not invent participants or feedback.

---

## 5. Chapter 3 — Project II milestones
Change wording similar to:

> integrated an AI-powered personalised study roadmap generator to optimise revision efficiency

to:

> integrated an AI-assisted personalised study roadmap generator for structured revision planning

Change wording similar to:

> Engineered mathematical SM-2 stability scaling and Ebbinghaus forgetting decay calculations

to:

> Implemented a project-specific SM-2-inspired stability factor and exponential retention estimate (`mastery_engine.py`).

---

## 6. Chapter 4 — Architecture opening
Remove unsupported claims such as `high availability` and `low-latency user interaction`.

Use wording close to:

> Note2Quiz was architected as a modular three-tier client-server system separating the presentation layer, application and business-logic layer, and data-persistence/external-services layer.

Do not alter the architecture diagram in this pass.

---

## 7. Chapter 4 — Do not undo corrected algorithms
Keep the current Section 4.6 corrections:
- stability factor is project-specific and SM-2-inspired;
- `0.65` is an implementation choice;
- `R(t) = R0 * exp(-t / (7S))`;
- `7S` is a decay **time constant**;
- implied half-life is `7S ln(2)`;
- retention labels are heuristic display states;
- weakness drill selects up to the first six stored distinct mistakes;
- no frequency weighting, recency decay, Softmax sampling, or Shannon-entropy claim;
- RAG scoring is project-specific.

Only edit for consistency.

---

## 8. Chapter 5 — Make tone thesis-like, not audit-like
Preserve technical truth, but avoid reviewer/audit phrasing.

For revision-link security, prefer:

> The implemented revision link used notebook, syllabus-week, and user-email parameters to select revision context. Signed and expiring revision links were not implemented in the current prototype and are identified as future security work in Section 7.3.

For weakness drill, prefer:

> The current implementation used deterministic selection of up to six distinct stored mistakes. Frequency- and recency-weighted prioritisation was reserved for future work.

Prefer:
- `the current prototype did not implement...`
- `this remains future work`
- `the implementation used...`

Avoid repeated phrases like:
- `the code does not...`
- `no evidence exists...`
- `the report incorrectly claimed...`

---

## 9. Chapter 5 — Timetable terminology
Where appropriate, replace broad `OCR` wording with:
- `vision-based timetable extraction`
- `AI-assisted timetable extraction`
- `Gemini multimodal image/PDF extraction`

If renaming FR-15 would break cross-references, keep the requirement ID/name but clarify that the implementation uses Gemini multimodal image/PDF processing rather than a traditional OCR engine.

Do not change code identifiers.

---

## 10. Chapter 5 — Screenshot placeholders
Keep all screenshot placeholders for now.

Do not generate fake screenshots.  
Do not remove placeholders yet.

When real screenshots are later inserted, the final structure should contain only:
1. screenshot
2. one figure caption

Avoid duplicate captions.

Do not perform a large re-layout unless there is a clear pagination problem.

---

## 11. Chapter 6 — Functional verification status
**Important context from the project author:** all implemented application functions have already been manually tested and confirmed working by the developer during development.

Therefore, do **not** use `Not verified` merely because there is no formal user-study record or separate retained execution log.

### TC-01 to TC-16
For functions that are implemented and were manually tested by the developer, use status wording such as:

- `PASS — Manual Functional Verification`
- `PASS — Developer Functional Verification`
- `Functionally Verified`

Choose one wording and apply it consistently.

In the evidence column, use concise wording such as:

> Manually executed by the developer during system verification; observed behaviour matched the expected result.

Do **not** invent:
- participant studies;
- SUS scores;
- questionnaire results;
- statistical results;
- performance numbers;
- concurrency results beyond what was actually tested.

### Automated tests
You may run the already-existing automated tests **without modifying source code** if this can be done directly.

If they are genuinely executed successfully:
- record the real number of tests run and passed;
- e.g. `9/9 automated test methods passed`, only if true.

If the automated test suite is not executed during this revision, do not label it `Not verified` if the corresponding functionality was already manually verified. Instead distinguish:

- manual functional verification, and
- automated test execution status.

Example:

> Functional behaviour was manually verified; automated test definitions were present but were not re-executed during this revision.

Do not call any result `100% code coverage` unless an actual coverage report exists.

### TC-15 / TC-16
Keep the distinction:
- five-player multiplayer functionality was manually verified;
- 50 participants remains a design target only;
- do not claim verified 50-player capacity unless a real 50-client load test was performed.

---

## 12. Chapter 6 — Objective Evaluation
Use cautious status labels such as:
- `IMPLEMENTED; validation limited`
- `IMPLEMENTED; technical evidence limited`
- `PARTIALLY VALIDATED`

Do not restore:
- `FULLY ACHIEVED (100% Success)`
- `100% verified`
- `complete validation`

unless directly supported.

---

## 13. Chapter 6 — No formal user study is required
The project did **not** include a formal user study, and none should be added.

Keep the distinction between:

- **developer/system functional verification** — this was performed for the implemented functions; and
- **formal user evaluation** — this was not part of the project.

Do not add:
- 30-participant studies;
- SUS questionnaires;
- usability surveys;
- participant demographics;
- user-study statistics.

The absence of a formal user study must **not** cause implemented functions to be labelled `Not verified`.

Educational effectiveness, memory improvement, and academic-performance improvement were not experimentally evaluated and should not be claimed.

---

## 14. Chapter 7 — Keep conservative conclusion
Keep:
- no latency guarantee;
- no complete code-coverage claim;
- no verified 50-player capacity;
- no experimentally established educational effectiveness;
- retention is a project-specific heuristic;
- signed/expiring revision links remain future work;
- backend identity verification remains a limitation.

Only improve readability.

---

## 15. Security consistency
Keep these facts consistent throughout Chapters 1–7:
- Firebase Authentication is used on the client;
- backend `/login` does not verify a Firebase ID token;
- backend identity verification is a limitation/future improvement;
- Gmail SMTP is the implemented notification method;
- SMTP uses port 587 and STARTTLS;
- Google App Password is used for SMTP setup;
- Power Automate / Teams forwarding is external to the backend;
- revision links are parameterised;
- HMAC signing, expiry, and signature validation are not implemented.

Do not reintroduce:
- Resend as the final notification service;
- HMAC-secured deep links;
- full backend-authentication claims;
- production security guarantees.

---

## 16. References
Do not perform a full bibliography rewrite unless directly affected by these edits.

Preserve current IEEE numbering if already consistent.

Only:
- remove a reference if it becomes completely unused;
- renumber only if removal requires it;
- preserve URLs and access dates;
- do not add references unless required.

---

## 17. Language/style
Maintain:
- British English;
- third-person academic writing;
- past tense for completed implementation where appropriate;
- normal prose without unnecessary bold;
- concise technical wording.

Reduce repeated promotional words such as:
`comprehensive`, `sophisticated`, `seamless`, `significant`, `critical`, `guaranteed`, `optimised`, `fully validated`.

Do not rewrite already-good technical sections merely for style.

---

## 18. Do not rework already-corrected areas
Avoid spending tokens re-analysing these unless a direct inconsistency appears:
- Gmail SMTP vs Resend;
- HMAC removal;
- 50-player design-target clarification;
- no SUS/user-study clarification;
- no 100% code-coverage claim;
- retention-equation terminology;
- weakness-drill algorithm;
- project-specific RAG scoring;
- Chapter 7 security/evaluation limitations.

---

## 19. Targeted final validation
After editing, check only changed sections plus document integrity.

Confirm:
- Chapters 1–7 remain;
- References remain;
- equations remain intact;
- tables and figures remain;
- Chapter 5 placeholders remain;
- implemented functions manually verified by the developer are not incorrectly labelled `Not verified`;
- no formal user-study results were invented;
- no unsupported quantitative performance/concurrency results were added;
- no source-code file was modified;
- DOCX opens successfully.

Do not perform another full repository audit unless a changed statement cannot be verified.

---

## 20. Output
Save:
`FYP2_Final_Report_Note2Quiz_V3_FinalReview.docx`

Also create:
`FYP2_V3_CHANGELOG.md`

Keep the changelog short.

Do not overwrite V2.
