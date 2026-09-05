# Figure 4.4.3: Dual-Trigger Automated Spaced Revision Notification Sequence Diagram - Specifications & Prompts

This document provides multi-format specifications (Content-Driven AI Prompts, Mermaid.js, PlantUML, and Thesis Context) for **Figure 4.4.3: Dual-Trigger Automated Spaced Revision Notification Sequence Diagram** in Chapter 4 of the FYP2 report.

---

## 1. Lecturer-Friendly Content-Focused AI Generation Prompt (Clean & Minimalist)
*(Feed directly into **Napkin AI**, **Eraser.io**, **Whimsical AI**, **Claude Artifacts**, **ChatGPT Plus**, or **Miro AI**)*

```text
Create a clean, uncluttered, publication-ready UML Sequence Diagram for a university computer science thesis.
Title: Figure 4.4.3: Dual-Trigger Automated Spaced Revision Notification Sequence Diagram

Please use exactly 4 clear participants (from left to right):
1. APScheduler Daemon (Background Worker)
2. Flask Backend (automation.py)
3. MongoDB Atlas (automations & quiz)
4. Student Client (Email & Flutter App)

Structure the sequence into 2 distinct, color-coded phases:

[PHASE 1: Automated Background Schedule Evaluation & Email Dispatch]
1. APScheduler Daemon -> Flask Backend: Cron Trigger (Interval Check Every 5 Mins)
2. Flask Backend -> MongoDB Atlas: Query due automations (trigger_timestamp <= now)
3. MongoDB Atlas --> Flask Backend: Return due topic & 5 curated quiz questions
4. Flask Backend -> Student Client: Dispatch Revision Email via Resend API (Encrypted HMAC Deep-Link Token)
5. Flask Backend -> MongoDB Atlas: Update schedule status: 'sent', sent_at: ISODate()

[PHASE 2: One-Click Deep-Link Redemption & SM-2 Memory Recalculation]
6. Student Client -> Flask Backend: Student clicks email link (note2quiz://quiz?token=xyz) -> GET /redeem-token
7. Flask Backend --> Student Client: Return 5 quiz questions -> Student completes 3-min quiz directly in App
8. Student Client -> Flask Backend: POST /submit-revision (score, time_spent, answers)
9. Flask Backend: Recalculate SM-2 Stability (S) & Ebbinghaus Retention (self-call)
10. Flask Backend -> MongoDB Atlas: Update topic retention: 'Fresh / Mastered' (Green)

Design Requirements:
- Maximum clarity for academic examiners: 4 clear lifelines without overcrowding.
- No floating numbers or messy left margins.
- Clean return arrows (dashed lines) for data responses.
- Pure white background (#FFFFFF) with high contrast.
```

---

## 2. Professional Mermaid.js Code
> *Paste directly into [Mermaid Live Editor (mermaid.live)](https://mermaid.live), GitHub, Notion, or Obsidian.*

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'Arial, sans-serif' }}}%%
sequenceDiagram
    autonumber
    participant Cron as ⚙️ APScheduler
    participant Server as ⚡ Flask Backend
    participant DB as 🗄️ MongoDB Atlas
    actor Student as 👤 Student (Email & App)

    rect rgb(248, 250, 252)
    Note over Cron, Student: Phase 1: Background Evaluation & Email Dispatch
    Cron->>Server: Cron Trigger (Interval Check Every 5 Mins)
    Server->>DB: Query due automations (trigger <= now)
    DB-->>Server: Return due topic & 5 curated quiz questions
    Server->>Student: Dispatch Email with HMAC Deep-Link Token (Resend API)
    Server->>DB: Update schedule status to 'sent'
    end

    rect rgb(240, 253, 244)
    Note over Cron, Student: Phase 2: One-Click Deep-Link Redemption & SM-2 Update
    Student->>Server: Click Email Link (note2quiz://quiz?token=xyz) -> GET /redeem-token
    Server-->>Student: Return 5 quiz questions -> Student completes 3-min quiz
    Student->>Server: POST /submit-revision (score, answers)
    Note over Server: Recalculate SM-2 Stability & Retention Decay
    Server->>DB: Update topic status to 'Fresh / Mastered' (Green)
    end
```

---

## 3. PlantUML Sequence Diagram Code
> *Paste into [PlantText (planttext.com)](https://www.planttext.com/)*

```plantuml
@startuml
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundCorner 8
skinparam defaultFontName Arial
skinparam defaultFontSize 11
autonumber

participant "APScheduler Daemon\n(Background Worker)" as Cron #FFFBEB
participant "Flask Backend\n(automation.py)" as Server #FAF5FF
database "MongoDB Atlas\n(Database)" as DB #ECFDF5
actor "Student Client\n(Email & Flutter App)" as Student #EFF6FF

== Phase 1: Automated Background Evaluation & Email Dispatch ==
Cron -> Server : Cron Trigger (Interval Check Every 5 Mins)
activate Server
Server -> DB : Query due automations (trigger_timestamp <= now)
activate DB
DB --> Server : Return due topic & 5 curated quiz questions
deactivate DB

Server -> Student : Dispatch Revision Email with Encrypted HMAC Deep Link
Server -> DB : Update schedule status='sent'
deactivate Server

== Phase 2: One-Click Deep-Link Redemption & SM-2 Recalculation ==
Student -> Server : Click Link (note2quiz://quiz?token=xyz) -> GET /redeem-token
activate Server
Server --> Student : Return 5 questions -> Student completes 3-min quiz in App

Student -> Server : POST /submit-revision (score, time_spent, answers)
Server -> Server : Recalculate SM-2 Stability (S) & Ebbinghaus Retention
Server -> DB : Update topic retention: 'Fresh / Mastered' (Green)
activate DB
DB --> Server : WriteResult OK
deactivate DB
deactivate Server
@enduml
```

---

## 4. Formal Thesis Caption (Chapter 4, Section 4.4.3)
**Figure 4.4.3: Dual-Trigger Automated Spaced Revision Notification Sequence Diagram**  
*Figure 4.4.3 details the dual-phase operational lifecycle of automated spaced revision reminders. In Phase 1, the APScheduler background daemon periodically evaluates MongoDB for pending syllabus triggers and dispatches contextual HTML emails with secure HMAC deep links via the Resend API. In Phase 2, the student executes zero-friction revision by launching directly into the quiz from their email client, with the backend dynamically recalculating SM-2 memory stability parameters upon completion.*
