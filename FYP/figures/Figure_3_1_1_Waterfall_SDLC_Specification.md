# Figure 3.1.1: Waterfall SDLC Model Architecture - Design & Diagram Prompts

This document provides multi-format diagram specifications (Mermaid, PlantUML, Draw.io / SVG prompts, LaTeX TikZ, and AI Visual Prompts) to generate **Figure 3.1.1: Waterfall SDLC Model Architecture** for your Final Year Project (FYP) report.

---

## 1. Professional Mermaid.js Code
> *You can paste this directly into [Mermaid Live Editor (mermaid.live)](https://mermaid.live), GitHub, Notion, or Obsidian.*

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'Arial, sans-serif', 'primaryColor': '#EFF6FF', 'primaryBorderColor': '#2563EB', 'lineColor': '#1D4ED8', 'secondaryColor': '#FEF3C7', 'tertiaryColor': '#F0FDF4' }}}%%
graph TD
    %% Phase Nodes
    P1["<b>Phase 1: Requirements Analysis</b><br/>• Elicit functional & non-functional requirements<br/>• Formulate Software Requirements Specification (SRS)<br/>• Feasibility study & baseline milestone scoping"]
    
    P2["<b>Phase 2: System Design</b><br/>• Architectural design & system topology specification<br/>• Relational database schema & RESTful API contracts<br/>• UI/UX wireframes & component hierarchy"]
    
    P3["<b>Phase 3: Implementation (Coding)</b><br/>• Frontend Flutter UI & Riverpod state management<br/>• Backend Flask REST API & AI prompt orchestrator<br/>• Isolated module unit tests & code verification"]
    
    P4["<b>Phase 4: Integration & System Testing</b><br/>• Mobile client & backend server integration<br/>• Black-box, usability & end-to-end evaluation<br/>• Defect tracking, bug remediation & performance tuning"]
    
    P5["<b>Phase 5: Deployment & Maintenance</b><br/>• Production build release & server deployment<br/>• Operational telemetry, error monitoring & logging<br/>• Long-term patching, hotfixes & maintenance"]

    %% Downstream Stage-Gate Flow
    P1 -->|<b>Gate 1:</b> SRS Baseline Approved| P2
    P2 -->|<b>Gate 2:</b> Architecture Design Approved| P3
    P3 -->|<b>Gate 3:</b> Code Complete & Unit Tests Passed| P4
    P4 -->|<b>Gate 4:</b> QA & UAT System Verified| P5

    %% Upstream Defect Feedback Loops
    P2 -.->|⮌ Req Clarification| P1
    P3 -.->|⮌ Architecture Revision| P2
    P4 -.->|⮌ Defect Remediation| P3
    P5 -.->|⮌ Post-Release Hotfix| P4

    %% Custom Styles
    style P1 fill:#EFF6FF,stroke:#2563EB,stroke-width:2px,rx:8px,ry:8px
    style P2 fill:#F0FDFA,stroke:#0D9488,stroke-width:2px,rx:8px,ry:8px
    style P3 fill:#EEF2FF,stroke:#6366F1,stroke-width:2px,rx:8px,ry:8px
    style P4 fill:#FFFBEB,stroke:#D97706,stroke-width:2px,rx:8px,ry:8px
    style P5 fill:#ECFDF5,stroke:#059669,stroke-width:2px,rx:8px,ry:8px
    linkStyle 0,1,2,3 stroke:#1D4ED8,stroke-width:2.5px
    linkStyle 4,5,6,7 stroke:#DC2626,stroke-width:1.5px,stroke-dasharray: 5 5
```

---

## 2. PlantUML Architecture Code
> *Paste into [PlantText (planttext.com)](https://www.planttext.com/) or IntelliJ / VS Code PlantUML plugin.*

```plantuml
@startuml
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundCorner 12
skinparam defaultFontName Arial
skinparam defaultFontSize 11

skinparam activity {
  BackgroundColor #F8FAFC
  BorderColor #2563EB
  BorderThickness 1.5
  FontColor #0F172A
}

skinparam arrow {
  Color #1D4ED8
  Thickness 2
  FontColor #1E40AF
  FontSize 10
}

partition "Waterfall SDLC Architecture" {
  (*) --> "<b>Phase 1: Requirements Analysis</b>\n---\n• Elicit functional & non-functional requirements\n• Formulate SRS documentation\n• Feasibility assessment & milestone scoping" as P1
  
  --> "<b>Phase 2: System Design</b>\n---\n• Architectural topology specification\n• DB schema & RESTful API contracts\n• UI/UX wireframes & component tree" as P2
  note right: **Gate 1:** SRS Baseline Approved
  
  --> "<b>Phase 3: Implementation (Coding)</b>\n---\n• Flutter frontend & Riverpod state\n• Flask REST backend & AI prompt engine\n• Unit tests & code verification" as P3
  note right: **Gate 2:** Architecture Approved
  
  --> "<b>Phase 4: Integration & System Testing</b>\n---\n• End-to-end client-server integration\n• System, usability & performance testing\n• Bug fixing & compliance validation" as P4
  note right: **Gate 3:** Code & Tests Passed
  
  --> "<b>Phase 5: Deployment & Maintenance</b>\n---\n• Production release & environment deployment\n• Telemetry & operational error logging\n• Long-term patches & maintenance" as P5
  note right: **Gate 4:** QA / UAT Verification
  
  --> (*)
}

P2 ..> P1 : <color:#DC2626>Requirement Clarification</color>
P3 ..> P2 : <color:#DC2626>Architecture Revision</color>
P4 ..> P3 : <color:#DC2626>Bug Remediation</color>
P5 ..> P4 : <color:#DC2626>Hotfix Validation</color>
@enduml
```

---

## 3. Structured Prompt for AI Diagram Generators
*(Copy-paste this prompt into Eraser.io, Napkin AI, Claude, ChatGPT Plus, Midjourney, or DALL-E 3)*

```text
Generate a clean, modern, publication-ready academic software engineering diagram titled "Figure 3.1.1: Waterfall SDLC Model Architecture" for a computer science university thesis.

Layout Requirements:
- A clean diagonal stepped staircase layout (from top-left to bottom-right) containing exactly 5 sequential stages.
- Each stage is rendered in a modern rounded card with a distinct dark header band, subtle drop shadow, and clean bulleted text.

The 5 Phases & Content:
1. [Phase 1: Requirements Analysis] (Theme: Royal Blue)
   - Elicit functional & non-functional requirements
   - Formulate Software Requirements Specification (SRS)
   - Feasibility assessment & milestone scoping
2. [Phase 2: System Design] (Theme: Ocean Teal)
   - Architectural design & system topology specification
   - Relational database schema & RESTful API contracts
   - UI/UX wireframes & component hierarchy
3. [Phase 3: Implementation (Coding)] (Theme: Indigo)
   - Frontend Flutter UI & Riverpod state management
   - Backend Flask REST API & AI prompt orchestrator
   - Module-level unit tests & code verification
4. [Phase 4: Integration & System Testing] (Theme: Amber Brown)
   - Subsystem integration (Mobile Client + Backend Server)
   - Functional, usability & end-to-end system testing
   - Defect logging, bug remediation & performance tuning
5. [Phase 5: Deployment & Maintenance] (Theme: Emerald Green)
   - Production environment deployment & client release
   - Operational telemetry, error monitoring & logging
   - Long-term patching, hotfixes & maintenance

Connector Lines:
- Forward Flow: Crisp bold blue cascading arrows stepping from the bottom of Phase N to the top of Phase N+1.
- Gate Check Badges: Clean badge pills above each transition labeled "Gate 1: SRS Approved", "Gate 2: Architecture Approved", "Gate 3: Code Complete", "Gate 4: QA Verified".
- Feedback Loops: Subtle red dashed curved return arcs on the left side indicating upstream defect feedback loops ("Requirement Clarification", "Design Revision", "Bug Remediation").

Aesthetic Style: Minimalist, crisp vector graphics, high contrast, clean sans-serif typography, pure white background, professional academic look.
```

---

## 4. LaTeX TikZ Code (For Overleaf / LaTeX Thesis)

```latex
\documentclass[border=10pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes.multipart, positioning, arrows.meta, calc, fit}

\begin{document}
\begin{tikzpicture}[
    phase/.style={
        rectangle split,
        rectangle split parts=2,
        rectangle split part fill={#1!90!black, #1!8!white},
        rounded corners=4pt,
        draw=#1!80!black,
        line width=1.2pt,
        text width=6.2cm,
        minimum height=2.0cm,
        inner sep=6pt,
        font=\sffamily\footnotesize
    },
    downlink/.style={-{Stealth[scale=1.2]}, line width=1.8pt, draw=blue!70!black},
    feedback/.style={-{Stealth[scale=1.0]}, dashed, line width=1.0pt, draw=red!70!black}
]

% Nodes
\node[phase=blue] (p1) at (0, 8.0) {
    \textbf{\textcolor{white}{Phase 1: Requirements Analysis}}
    \nodepart{two}
    $\bullet$ Elicit functional \& non-functional specs\\
    $\bullet$ Formulate SRS document\\
    $\bullet$ Feasibility assessment \& scope baseline
};

\node[phase=teal] (p2) at (3.2, 5.8) {
    \textbf{\textcolor{white}{Phase 2: System Design}}
    \nodepart{two}
    $\bullet$ Architectural topology specification\\
    $\bullet$ Relational DB schema \& API contracts\\
    $\bullet$ UI/UX wireframes \& component hierarchy
};

\node[phase=indigo] (p3) at (6.4, 3.6) {
    \textbf{\textcolor{white}{Phase 3: Implementation (Coding)}}
    \nodepart{two}
    $\bullet$ Flutter frontend UI \& Riverpod state\\
    $\bullet$ Flask REST API \& AI prompt orchestrator\\
    $\bullet$ Unit tests \& code verification
};

\node[phase=orange] (p4) at (9.6, 1.4) {
    \textbf{\textcolor{white}{Phase 4: Integration \& Testing}}
    \nodepart{two}
    $\bullet$ Mobile client \& backend integration\\
    $\bullet$ System, usability \& evaluation testing\\
    $\bullet$ Defect tracking \& bug remediation
};

\node[phase=green] (p5) at (12.8, -0.8) {
    \textbf{\textcolor{white}{Phase 5: Deployment \& Maintenance}}
    \nodepart{two}
    $\bullet$ Production deployment \& client release\\
    $\bullet$ Operational telemetry \& error logging\\
    $\bullet$ Long-term patches \& maintenance
};

% Downward Arrows with Gate Badges
\draw[downlink] (p1.south) |- (p2.north west) node[pos=0.5, above=2pt, font=\sffamily\tiny\bfseries, color=blue!80!black, fill=blue!5, rounded corners=2pt, draw=blue!30] {Gate 1: SRS Approved};
\draw[downlink] (p2.south) |- (p3.north west) node[pos=0.5, above=2pt, font=\sffamily\tiny\bfseries, color=blue!80!black, fill=blue!5, rounded corners=2pt, draw=blue!30] {Gate 2: Design Approved};
\draw[downlink] (p3.south) |- (p4.north west) node[pos=0.5, above=2pt, font=\sffamily\tiny\bfseries, color=blue!80!black, fill=blue!5, rounded corners=2pt, draw=blue!30] {Gate 3: Code Complete};
\draw[downlink] (p4.south) |- (p5.north west) node[pos=0.5, above=2pt, font=\sffamily\tiny\bfseries, color=blue!80!black, fill=blue!5, rounded corners=2pt, draw=blue!30] {Gate 4: QA Verified};

% Upstream Feedback Loops
\draw[feedback] (p2.west) to[bend left=45] node[left, font=\sffamily\tiny\itshape, color=red!70!black] {Req Clarification} (p1.west);
\draw[feedback] (p3.west) to[bend left=45] node[left, font=\sffamily\tiny\itshape, color=red!70!black] {Design Revision} (p2.west);
\draw[feedback] (p4.west) to[bend left=45] node[left, font=\sffamily\tiny\itshape, color=red!70!black] {Bug Remediation} (p3.west);
\draw[feedback] (p5.west) to[bend left=45] node[left, font=\sffamily\tiny\itshape, color=red!70!black] {Hotfix Validation} (p4.west);

\end{tikzpicture}
\end{document}
```

---

## 5. Formal Thesis Caption & Description

**Figure 3.1.1: Waterfall SDLC Model Architecture**  
*Figure 3.1.1 illustrates the classical sequential Waterfall SDLC architecture executed in strict chronological order across five discrete phases: Requirements Analysis, System Design, Implementation (Coding), Integration & System Testing, and Deployment & Maintenance. Each phase is governed by formal stage-gate approval criteria (Gates 1 through 4) preventing downstream advancement until prerequisite documentation and testing baselines are fully validated. Upstream feedback loops allow controlled defect remediation and requirements clarification.*
