# Figure 4.4.2: Real-Time AI Studio Generation and SSE Streaming Sequence Diagram - Specifications & Prompts

This document provides multi-format specifications (Content-Driven AI Prompts, Mermaid.js, PlantUML, and Thesis Context) for **Figure 4.4.2: Real-Time AI Studio Generation and SSE Streaming Sequence Diagram** in Chapter 4 of the FYP2 report.

---

## 1. Lecturer-Friendly Content-Focused AI Generation Prompt (Clean & Minimalist)
*(Feed directly into **Napkin AI**, **Eraser.io**, **Whimsical AI**, **Claude Artifacts**, **ChatGPT Plus**, or **Miro AI**)*

```text
Create a clean, uncluttered, publication-ready UML Sequence Diagram for a university computer science thesis.
Title: Figure 4.4.2: Real-Time AI Studio Generation and SSE Streaming Sequence Diagram

Please use exactly 4 clear participants (from left to right):
1. Flutter Client (Student UI)
2. Flask Backend (REST & SSE Router)
3. Google Gemini 1.5 Flash (Cloud Generative AI)
4. MongoDB Atlas (Document Database)

Structure the sequence into 3 distinct, color-coded phases:

[PHASE 1: Request & Context Assembly]
1. Flutter Client -> Flask Backend: POST /stream-studio-item (type='quiz', diff='medium', count=5)
2. Flask Backend -> MongoDB Atlas: Query notebook text sources
3. MongoDB Atlas --> Flask Backend: Return sanitized text chunks & RAG context

[PHASE 2: Real-Time Token Streaming (Server-Sent Events / SSE)]
4. Flask Backend -> Google Gemini 1.5 Flash: Call generate_content_stream(prompt)
5. Flask Backend --> Flutter Client: Establish HTTP 200 SSE Connection (text/event-stream)
Loop [While Tokens Stream from Gemini]:
  6a. Google Gemini 1.5 Flash --> Flask Backend: Stream token chunk
  6b. Flask Backend --> Flutter Client: SSE "data: {chunk}" -> Typewriter UI animation

[PHASE 3: JSON Schema Validation & Persistence]
7. Google Gemini 1.5 Flash --> Flask Backend: Stream Finished (EOF)
8. Flask Backend: Validate JSON Schema Syntax & Completeness (self-call)
9. Flask Backend -> MongoDB Atlas: Persist item to notebooks.studio_items
10. Flask Backend --> Flutter Client: SSE "event: done, data: {item_id}" -> Launch Interactive Quiz

Design Requirements:
- Maximum clarity for academic examiners: Do not crowd with internal sub-services.
- No detached floating numbers or cluttered left margins.
- Message descriptions placed directly on arrow lines.
- Pure white background (#FFFFFF) with high contrast.
```

---

## 2. Professional Mermaid.js Code
> *Paste directly into [Mermaid Live Editor (mermaid.live)](https://mermaid.live), GitHub, Notion, or Obsidian.*

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontFamily': 'Arial, sans-serif' }}}%%
sequenceDiagram
    autonumber
    actor Client as 📱 Flutter Client
    participant Server as ⚡ Flask Backend
    participant Gemini as ☁️ Gemini 1.5 Flash
    participant DB as 🗄️ MongoDB Atlas

    rect rgb(248, 250, 252)
    Note over Client, DB: Phase 1: Request & Context Assembly
    Client->>Server: POST /stream-studio-item (type, count, diff)
    Server->>DB: Query notebook text sources
    DB-->>Server: Return sanitized text chunks & RAG context
    end

    rect rgb(240, 253, 244)
    Note over Client, DB: Phase 2: Real-Time Streaming (SSE)
    Server->>Gemini: Call generate_content_stream(prompt)
    Server-->>Client: Establish HTTP 200 SSE Connection (text/event-stream)
    loop While Tokens Stream
        Gemini-->>Server: Stream token chunk
        Server-->>Client: SSE "data: {chunk}" (Typewriter UI Render)
    end
    end

    rect rgb(250, 245, 255)
    Note over Client, DB: Phase 3: Validation & Persistence
    Gemini-->>Server: Stream Finished (EOF)
    Note over Server: Validate JSON Schema Syntax
    Server->>DB: Persist item to notebooks.studio_items
    DB-->>Server: WriteResult OK
    Server-->>Client: SSE "event: done, data: {item_id}" -> Open Quiz View
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

actor "Flutter Client\n(Student UI)" as Client #EFF6FF
participant "Flask Backend\n(REST & SSE)" as Server #FAF5FF
participant "Gemini 1.5 Flash\n(Google AI)" as Gemini #ECFDF5
database "MongoDB Atlas\n(Database)" as DB #FFFBEB

== Phase 1: Request & Context Assembly ==
Client -> Server : POST /stream-studio-item (type='quiz', count=5)
activate Server
Server -> DB : Query notebook text sources
activate DB
DB --> Server : Return sanitized text chunks & RAG context
deactivate DB

== Phase 2: Real-Time Generative Streaming (SSE) ==
Server -> Gemini : Call generate_content_stream(prompt)
activate Gemini
Server --> Client : Establish HTTP 200 SSE Stream (text/event-stream)

loop While Tokens Stream from Gemini
  Gemini --> Server : Stream token chunk
  Server --> Client : SSE "data: {chunk}" -> Typewriter UI Render
end

Gemini --> Server : Stream Finished (EOF)
deactivate Gemini

== Phase 3: JSON Validation & Persistence ==
Server -> Server : Validate JSON Schema Syntax
Server -> DB : Persist item to notebooks.studio_items
activate DB
DB --> Server : WriteResult OK
deactivate DB
Server --> Client : SSE "event: done, data: {item_id}" -> Open Quiz View
deactivate Server
@enduml
```

---

## 4. Formal Thesis Caption (Chapter 4, Section 4.4.2)
**Figure 4.4.2: Real-Time AI Studio Generation and SSE Streaming Sequence Diagram**  
*Figure 4.4.2 details the sequence flow for low-latency Generative AI study material generation. The workflow is organized into three distinct phases: Phase 1 gathers and sanitizes notebook text sources for RAG prompt construction; Phase 2 establishes a Server-Sent Events (SSE) stream relaying Gemini 1.5 Flash token chunks to the Flutter client in real time; Phase 3 validates the completed JSON payload against strict schema rules, persists the verified study item into MongoDB, and notifies the client to render the interactive quiz interface.*
