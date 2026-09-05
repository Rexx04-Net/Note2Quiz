# Figure 4.3.1: Comprehensive System Use Case Diagram - Specifications & Prompts

This document provides multi-format specifications (Content-Driven AI Prompts, Mermaid.js, PlantUML, and Thesis Context) for **Figure 4.3.1: Comprehensive System Use Case Diagram** in Chapter 4 of the FYP2 report.

---

## 1. Content-Focused AI Generation Prompt (Unconstrained & Creative)
*(Feed directly into **Napkin AI**, **Eraser.io**, **Whimsical AI**, **Claude Artifacts**, **ChatGPT Plus**, **Miro AI**, or **Midjourney**)*

```text
Create a clean, professional, publication-ready UML Use Case diagram for a university computer science thesis.

Title: Figure 4.3.1: Comprehensive System Use Case Diagram
System Boundary: Note2Quiz Intelligent Platform (AI-Powered Active Recall & Automated Study Assistant)

Actors (Left & Right of System Boundary):
1. Primary User Actors:
   - Student (Primary Learner)
   - Educator / Room Host (Secondary User)
2. System & Automated Actors:
   - External Cloud Services (Google Gemini AI, Firebase Auth, Google Calendar, Resend API)
   - Background Scheduler Worker (APScheduler Daemon)

Core Use Cases inside System Boundary:
[Authentication & User Profile]
- UC-01: Authenticate & Manage Profile (Student, Host -> Firebase Auth)
- UC-02: Track Daily Study Streak & XP Gamification (Student)

[Notebooks & Multi-Modal Ingestion]
- UC-03: Create & Organize Subject Notebooks (Student)
- UC-04: Upload Lecture Sources (PDF, PPTX, DOCX, TXT, YouTube, Camera OCR) (Student -> Ingestion Engine)

[Generative AI Studio]
- UC-05: Generate Interactive Solo Quiz (Student -> Gemini Flash LLM)
- UC-06: Generate 3D Flip Flashcard Decks (Student -> Gemini Flash LLM)
- UC-07: Synthesize Interactive Visual Mind Maps (Student -> Gemini Flash LLM)

[Self-Assessment & Remediation]
- UC-08: Take Solo Quiz & Review Deep Explanations (Student)
- UC-09: Capture Errors & Practice Mistakes Bank Remedial Drills (Student)

[Automations & Timetables]
- UC-10: Scan & Parse Semester Timetable Image (Student -> Gemini Vision OCR)
- UC-11: Sync Syllabus Schedule with Google Calendar & Export .ics (Student -> Google Calendar API)
- UC-12: Dispatch Dual-Trigger Spaced Revision Emails (Background Scheduler -> Resend API -> Student)
- UC-13: Deep-Link Direct Revision Completion (Student)

[Real-Time Multiplayer Arena]
- UC-14: Host Live Classroom Quiz Game Room (Educator / Host)
- UC-15: Join Game Room with 6-Char Pin & Select Avatar (Student)
- UC-16: Live Synchronous Question Broadcast & Podium Leaderboard (Host, Student)

Design Preferences:
- High readability, balanced compact layout without excessive whitespace.
- Clean standard UML oval use cases grouped logically with subtle dashed package boundaries.
- Clean association lines connecting actors to relevant use cases.
- Professional academic aesthetic on pure white background (#FFFFFF).
```

---

## 2. Professional Mermaid.js Code
> *Paste directly into [Mermaid Live Editor (mermaid.live)](https://mermaid.live), GitHub, Notion, or Obsidian.*

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'Arial, sans-serif' }}}%%
graph LR
    %% Actors
    subgraph Users ["User Actors"]
        Student["👤 Student<br/>(Primary Learner)"]
        Host["👨‍🏫 Educator / Host<br/>(Secondary Actor)"]
    end

    subgraph SystemBoundary ["System Boundary: Note2Quiz Platform"]
        UC1(["UC-01: Authenticate & OAuth Login"])
        UC2(["UC-02: Manage Subject Notebooks"])
        UC3(["UC-03: Upload Multi-Modal Sources (PDF/PPTX/YT)"])
        UC4(["UC-04: Generate Quizzes, Flashcards & Mind Maps"])
        UC5(["UC-05: Take Solo Quiz & Explanatory Review"])
        UC6(["UC-06: Practice Mistakes Bank Remedial Drills"])
        UC7(["UC-07: Scan Timetable & Sync Google Calendar"])
        UC8(["UC-08: Automated Spaced Revision Notification"])
        UC9(["UC-09: Host Live Multiplayer Game Room"])
        UC10(["UC-10: Join Game & Live Podium Leaderboard"])
    end

    subgraph SystemActors ["System & Background Actors"]
        Cloud["☁️ External Cloud Services<br/>(Gemini, Firebase, Calendar, Resend)"]
        Daemon["⚙️ APScheduler Daemon<br/>(Background Worker)"]
    end

    %% User Connections
    Student --> UC1
    Student --> UC2
    Student --> UC3
    Student --> UC4
    Student --> UC5
    Student --> UC6
    Student --> UC7
    Student --> UC8
    Student --> UC10

    Host --> UC1
    Host --> UC9
    Host --> UC10

    %% System Connections
    UC1 -.-> Cloud
    UC3 -.-> Cloud
    UC4 -.-> Cloud
    UC7 -.-> Cloud
    Daemon --> UC8
    UC8 -.-> Cloud

    %% Styles
    style Student fill:#EFF6FF,stroke:#2563EB,stroke-width:2px
    style Host fill:#FAF5FF,stroke:#9333EA,stroke-width:2px
    style Cloud fill:#ECFDF5,stroke:#059669,stroke-width:2px
    style Daemon fill:#FFFBEB,stroke:#D97706,stroke-width:2px
    style SystemBoundary fill:#F8FAFC,stroke:#64748B,stroke-width:2px,stroke-dasharray: 4 4
```

---

## 3. PlantUML Use Case Code
> *Paste into [PlantText (planttext.com)](https://www.planttext.com/)*

```plantuml
@startuml
left to right direction
skinparam backgroundColor #FFFFFF
skinparam packageStyle rectangle
skinparam roundCorner 8
skinparam defaultFontName Arial

actor "Student\n(Primary Learner)" as Student #EFF6FF
actor "Educator / Host" as Host #FAF5FF
actor "Background Scheduler\n(APScheduler)" as Scheduler #FFFBEB
actor "External Cloud Services\n(Gemini, Firebase, Resend, Calendar)" as Cloud #ECFDF5

rectangle "Note2Quiz Intelligent Platform" {
  usecase "UC-01: Authenticate & OAuth Identity" as UC1
  usecase "UC-02: Manage Subject Notebooks" as UC2
  usecase "UC-03: Upload Multi-Modal Sources (PDF/PPTX/YT)" as UC3
  usecase "UC-04: Generate AI Quizzes & Flashcards" as UC4
  usecase "UC-05: Take Solo Quiz & Explanations" as UC5
  usecase "UC-06: Mistakes Bank Remedial Drills" as UC6
  usecase "UC-07: Scan Timetable & Sync Calendar" as UC7
  usecase "UC-08: Spaced Revision Email Alerts" as UC8
  usecase "UC-09: Host Live Multiplayer Room" as UC9
  usecase "UC-10: Join Game & Live Podium" as UC10
}

Student --> UC1
Student --> UC2
Student --> UC3
Student --> UC4
Student --> UC5
Student --> UC6
Student --> UC7
Student --> UC8
Student --> UC10

Host --> UC1
Host --> UC9
Host --> UC10

UC1 ..> Cloud : <<include>>
UC4 ..> Cloud : <<include>>
UC7 ..> Cloud : <<include>>
Scheduler --> UC8
UC8 ..> Cloud : <<include>>
@enduml
```

---

## 4. Formal Thesis Caption (Chapter 4, Section 4.3)
**Figure 4.3.1: Comprehensive System Use Case Diagram**  
*Figure 4.3.1 depicts the comprehensive UML Use Case diagram for the Note2Quiz platform. It defines the operational boundaries and interactions between primary human actors (Student, Educator/Host) and automated system actors (APScheduler Daemon, Google Cloud / Firebase / Resend APIs) across account authentication, multi-modal content ingestion, Generative AI studio synthesis, adaptive mistake remediation, automated spaced retention triggers, and live multiplayer synchronization.*
