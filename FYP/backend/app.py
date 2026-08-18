import os
import sys
import json
import uuid
import datetime
import time
import re
import random   
import string   
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from pypdf import PdfReader
from pptx import Presentation
from youtube_transcript_api import YouTubeTranscriptApi

# --- CONFIGURATION ---
print("🔍 --- STARTING BACKEND ---")
current_dir = os.path.dirname(os.path.abspath(__file__))
GEMINI_API_KEY = None

# Secure Key Loading
try:
    sys.path.append(current_dir)
    from api_secrets import GEMINI_API_KEY
    print("✅ Successfully imported API Key.")
except:
    pass

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# --- DATABASE CONNECTION ---
USING_MONGO = False
try:
    client = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=2000)
    db = client["note2quiz_db"]
    notebooks_col = db["notebooks"]
    feedback_col = db["feedback"]
    users_col = db["users"]  
    logs_col = db["activity_logs"] # ✅ NEW: Dedicated folder for tracking actions!
    study_plans_col = db["study_plans"] # ✅ NEW: Active AI Study Roadmap collection!
    
    client.server_info()
    print("✅ Connected to MongoDB")
    USING_MONGO = True
except:
    print("⚠️ MongoDB not found. Falling back to memory storage.")
    memory_notebooks = []
    memory_feedback = []
    memory_study_plans = []
    
# Active Games Memory
active_games = {}

# --- AI CONFIGURATION ---
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

MODEL_PRIORITY = [
    'gemini-2.5-flash',
    'models/gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-2.0-flash',
]

def generate_with_fallback(prompt):
    last_error = None
    for model_name in MODEL_PRIORITY:
        try:
            print(f"🤖 Trying AI Model: {model_name}...")
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            print(f"✅ Success with {model_name}")
            return response.text
        except Exception as e:
            print(f"⚠️ Failed with {model_name}: {e}")
            last_error = e
            if "400" in str(e) or "API_KEY" in str(e): break
            time.sleep(1)
    
    return f"AI Error: All models failed. Last error: {str(last_error)}"

# ✅ NEW: HELPER FUNCTION FOR TRACKING ACTIVITY
def log_activity(email, action, details=""):
    if USING_MONGO:
        try:
            log_entry = {
                "email": email,
                "action": action,
                "details": details,
                "timestamp": str(datetime.datetime.now())
            }
            logs_col.insert_one(log_entry)
            print(f"📝 LOGGED: {email} -> {action}")
        except Exception as e:
            print(f"⚠️ Failed to log activity: {e}")

# --- HELPER FUNCTIONS ---
def get_notebook(notebook_id):
    if USING_MONGO:
        return notebooks_col.find_one({"id": notebook_id})
    else:
        return next((n for n in memory_notebooks if n["id"] == notebook_id), None)

def save_notebook(notebook):
    if USING_MONGO:
        notebooks_col.replace_one({"id": notebook["id"]}, notebook, upsert=True)
    else:
        for i, n in enumerate(memory_notebooks):
            if n["id"] == notebook["id"]:
                memory_notebooks[i] = notebook
                return
        memory_notebooks.append(notebook)

def save_feedback(feedback_entry):
    if USING_MONGO:
        feedback_col.insert_one(feedback_entry)
    else:
        memory_feedback.append(feedback_entry)

def get_study_plan(plan_id=None, user_email=None):
    if USING_MONGO:
        if plan_id:
            return study_plans_col.find_one({"id": plan_id})
        elif user_email:
            return study_plans_col.find_one({"user_email": user_email}, sort=[("updated_at", -1)])
    else:
        if plan_id:
            return next((p for p in memory_study_plans if p.get("id") == plan_id), None)
        elif user_email:
            user_plans = [p for p in memory_study_plans if p.get("user_email") == user_email]
            return user_plans[-1] if user_plans else None
    return None

def save_study_plan(plan):
    plan["updated_at"] = str(datetime.datetime.now())
    if USING_MONGO:
        study_plans_col.replace_one({"id": plan["id"]}, plan, upsert=True)
    else:
        for i, p in enumerate(memory_study_plans):
            if p["id"] == plan["id"]:
                memory_study_plans[i] = plan
                return
        memory_study_plans.append(plan)

def get_context(notebook_id):
    nb = get_notebook(notebook_id)
    if not nb: return ""
    context = ""
    for source in nb.get("sources", []):
        context += f"\n--- SOURCE: {source['title']} ({source['type']}) ---\n{source['content']}\n"
    return context

def clean_ai_response(text):
    try: return json.loads(text)
    except:
        match = re.search(r'(\[.*\]|\{.*\})', text, re.DOTALL)
        if match:
            try: return json.loads(match.group(0))
            except: pass
    return None

def extract_text_from_pdf(file_stream):
    try:
        reader = PdfReader(file_stream)
        return "\n".join([page.extract_text() for page in reader.pages if page.extract_text()])
    except: return ""

def extract_text_from_pptx(file_stream):
    try:
        prs = Presentation(file_stream)
        text = []
        for slide in prs.slides:
            for shape in slide.shapes:
                if hasattr(shape, "text"): text.append(shape.text)
        return "\n".join(text)
    except: return ""

# --- ENDPOINTS ---
@app.route('/', methods=['GET'])
def home(): return "Note2Quiz Backend is Running! 🚀"

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email', '').strip().lower()
    
    if not email:
        return jsonify({"error": "Email is required"}), 400

    if USING_MONGO:
        existing_user = users_col.find_one({"email": email})
        
        if not existing_user:
            new_user = {
                "email": email,
                "created_at": str(datetime.datetime.now()),
                "role": "student" 
            }
            users_col.insert_one(new_user)
            log_activity(email, "Registered Account", "First time user sign-in") # ✅ Logging Registration
        else:
            log_activity(email, "Logged In", "User signed in successfully") # ✅ Logging normal Login

    return jsonify({"success": True, "email": email, "message": "Login successful"})

@app.route('/create-notebook', methods=['POST'])
def create_notebook():
    data = request.json
    email = data.get('email', 'guest')
    title = data.get('title', 'Untitled Notebook')
    
    new_nb = {
        "id": str(uuid.uuid4()),
        "user_email": email,
        "title": title,
        "sources": [],
        "created_at": str(datetime.datetime.now())
    }
    save_notebook(new_nb)
    
    # ✅ Logging Notebook Creation
    log_activity(email, "Created Notebook", f"Created notebook titled: {title}")
    
    if USING_MONGO: new_nb.pop('_id', None)
    return jsonify(new_nb)

@app.route('/get-notebooks', methods=['POST'])
def get_notebooks():
    email = request.json.get('email', 'guest')
    if USING_MONGO:
        notebooks = list(notebooks_col.find({"user_email": email}, {"_id": 0}))
    else:
        notebooks = [n for n in memory_notebooks if n['user_email'] == email]
    return jsonify(notebooks)

@app.route('/add-source', methods=['POST'])
def add_source():
    notebook_id = request.form.get('notebook_id')
    source_type = request.form.get('type', 'text')
    content = ""
    title = "New Source"

    if 'file' in request.files:
        f = request.files['file']
        title = f.filename
        if f.filename.endswith('.pdf'): content = extract_text_from_pdf(f)
        elif f.filename.endswith('.pptx'): content = extract_text_from_pptx(f)
    else:
        content = request.form.get('content', '')

    if not content.strip(): return jsonify({"error": "No text extracted"}), 400

    new_source = {
        "id": str(uuid.uuid4()),
        "title": title,
        "content": content,
        "type": source_type,
        "date": str(datetime.datetime.now())
    }
    
    nb = get_notebook(notebook_id)
    if nb:
        nb.setdefault('sources', []).append(new_source)
        save_notebook(nb)
        
        # ✅ Logging Source Upload
        user_email = nb.get('user_email', 'unknown')
        log_activity(user_email, "Added Source", f"Added {source_type} source: {title}")
        
        return jsonify(new_source)
    return jsonify({"error": "Notebook not found"}), 404

@app.route('/generate-studio-item', methods=['POST'])
def generate_studio_item():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    tool_type = data.get('tool_type')
    difficulty = data.get('difficulty', 'Standard')
    output_language = data.get('output_language', 'English')
    num_questions = 5 if difficulty == "Easy" else 20 if difficulty == "Hard" else 10

    # ✅ Logging AI Generation Start
    nb = get_notebook(notebook_id)
    user_email = nb.get('user_email', 'unknown') if nb else 'unknown'
    log_activity(user_email, f"Generated {tool_type.capitalize()}", f"Triggered Gemini AI for {difficulty} {tool_type}")

    context = get_context(notebook_id)
    if len(context) < 50: return jsonify({"type": "text", "data": "Not enough content. Add sources first."})

    prompt = ""
    if tool_type == "quiz":
        prompt = f"""Generate a {difficulty} Quiz with exactly {num_questions} questions.
        Write all user-facing content in {output_language}.
        Return valid JSON only.
        STRICT JSON FORMAT:
        [
            {{
                "question": "Question text here?",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "answer": "Option A",
                "hint": "A short, helpful clue without giving the answer away.",
                "explanation": "A short explanation of why the answer is correct."
            }}
        ]
        IMPORTANT:
        - Keep the JSON keys exactly as shown in English.
        - Translate the values, not the keys.
        - Make sure "answer" matches one of the options exactly.
        Context: {context[:35000]}"""

    elif tool_type == "flashcard":
        prompt = f"""Generate 10 flashcards in {output_language}.
        Return valid JSON only in this format:
        [{{ "front": "Term", "back": "Definition" }}]
        Keep the keys "front" and "back" exactly as written in English.
        Context: {context[:35000]}"""

    elif tool_type == "mindmap":
        prompt = f"""Create a hierarchical mind map in {output_language}.
        Use emojis where helpful, keep it readable, and do not use Markdown code blocks.
        Context: {context[:35000]}"""

    elif tool_type == "report":
        prompt = f"""Write an executive briefing document in {output_language}.
        Use clear section headings and concise bullet points where useful.
        Context: {context[:35000]}"""

    try:
        text = generate_with_fallback(prompt)
        if text.startswith("AI Error:"): return jsonify({"type": "text", "data": text})

        if tool_type in ["quiz", "flashcard"]:
            json_data = clean_ai_response(text)
            if json_data: return jsonify({"type": "json", "data": json_data})
            else: return jsonify({"type": "text", "data": "Error: AI response was not valid JSON."})
            
        return jsonify({"type": "text", "data": text})
    except Exception as e:
        return jsonify({"type": "text", "data": f"Backend Error: {str(e)}"})


@app.route('/delete-notebook', methods=['POST'])
def delete_notebook():
    notebook_id = request.json.get('id')
    
    nb = get_notebook(notebook_id)
    user_email = nb.get('user_email', 'unknown') if nb else 'unknown'
    title = nb.get('title', 'Unknown Notebook') if nb else 'Unknown Notebook'

    if USING_MONGO:
        notebooks_col.delete_one({"id": notebook_id})
    else:
        global memory_notebooks
        memory_notebooks = [n for n in memory_notebooks if n["id"] != notebook_id]
        
    # ✅ Logging Deletion
    log_activity(user_email, "Deleted Notebook", f"Deleted notebook titled: {title}")
        
    return jsonify({"success": True})

@app.route('/submit-feedback', methods=['POST'])
def submit_feedback():
    data = request.json or {}
    email = data.get('email', 'guest')
    message = data.get('message', '').strip()
    language = data.get('language', 'English')
    theme_mode = data.get('theme_mode', 'dark')

    if not message:
        return jsonify({"error": "Feedback message is required"}), 400

    feedback_entry = {
        "id": str(uuid.uuid4()),
        "email": email,
        "message": message,
        "language": language,
        "theme_mode": theme_mode,
        "timestamp": str(datetime.datetime.now())
    }

    save_feedback(feedback_entry)
    log_activity(email, "Submitted Feedback", message[:120])

    return jsonify({"success": True, "feedback_id": feedback_entry["id"]})

# --- ACTIVE AI STUDY ROADMAP ENDPOINTS ---
@app.route('/generate-active-plan', methods=['POST'])
def generate_active_plan():
    data = request.json or {}
    email = data.get('email', 'guest')
    notebook_ids = data.get('notebook_ids', [])
    duration_option = data.get('duration_option', '3 Days')  # 1 Day, 3 Days, 7 Days, AI Automated
    try:
        daily_hours = float(data.get('daily_hours', 2.0))
    except:
        daily_hours = 2.0

    if not notebook_ids:
        return jsonify({"error": "At least one notebook must be selected."}), 400

    combined_context = ""
    notebook_titles = []
    
    for n_id in notebook_ids:
        nb = get_notebook(n_id)
        if nb:
            notebook_titles.append(nb.get("title", "Untitled Subject"))
            for source in nb.get("sources", []):
                combined_context += f"\n--- SUBJECT: {nb.get('title')} | SOURCE: {source.get('title')} ({source.get('type')}) ---\n{source.get('content', '')}\n"

    if len(combined_context.strip()) < 30:
        return jsonify({"error": "Selected notebooks do not have enough lecture content. Please upload sources first."}), 400

    total_daily_minutes = int(daily_hours * 60)
    
    # --- GEMINI SYSTEM PROMPT FOR ACTIVE AI ROADMAP ---
    prompt = f"""You are an expert Educational AI Curator and Learning Path Architect for Note2Quiz.
Your task is to analyze the lecture materials across the selected subjects ({', '.join(notebook_titles)}) and generate an actionable, trackable day-by-day active study roadmap.

USER PARAMETERS:
- Requested Duration: {duration_option} (Options: '1 Day', '3 Days', '7 Days', 'AI Automated'). If 'AI Automated', intelligently select the optimal duration (1 to 7 days) based on material volume/complexity.
- Available Daily Time: {daily_hours} hours/day ({total_daily_minutes} minutes/day).

USP INSTRUCTIONS & TASK TYPE RULES:
1. Structure the roadmap into daily sessions.
2. Every day MUST contain actionable tasks that integrate our 3 core active study modules:
   - "note": Comprehensive reading of synthesized key concept summary.
   - "flashcard": Reviewing term-definition pairs for active recall.
   - "quiz": Taking diagnostic multiple-choice quizzes to test retention.
3. Intelligently assign and scale tasks based on text volume and daily study capacity.
4. Provide immediate working content inside the 'payload' field for each task so the user can interact right away.
5. Return ONLY a strict JSON object following this EXACT schema (do NOT wrap in ```json markdown formatting):

{{
  "roadmap_title": "Active Roadmap: {', '.join(notebook_titles)}",
  "recommended_days": 3,
  "days": [
    {{
      "day_number": 1,
      "title": "Day 1: Key Foundations & Diagnostics",
      "estimated_minutes": {total_daily_minutes},
      "tasks": [
        {{
          "title": "Read AI Note: Core Concepts Overview",
          "action_type": "note",
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "summary_text": "Detailed structured study note covering foundational topics..."
          }}
        }},
        {{
          "title": "Review 10 Flashcards: Fundamental Terms",
          "action_type": "flashcard",
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "flashcards": [
              {{"front": "Key Term 1", "back": "Definition 1"}},
              {{"front": "Key Term 2", "back": "Definition 2"}}
            ]
          }}
        }},
        {{
          "title": "Take Quiz 1: Checkpoint Test",
          "action_type": "quiz",
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "quiz_data": [
              {{
                "question": "Diagnostic question text?",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "answer": "Option A",
                "hint": "Helpful clue",
                "explanation": "Detailed explanation of answer"
              }}
            ]
          }}
        }}
      ]
    }}
  ]
}}

CONTEXT MATERIAL:
{combined_context[:35000]}"""

    log_activity(email, "Requested AI Roadmap", f"Notebooks: {notebook_titles}, Duration: {duration_option}")

    try:
        raw_text = generate_with_fallback(prompt)
        parsed_data = clean_ai_response(raw_text)

        if not parsed_data or "days" not in parsed_data:
            return jsonify({"error": "Failed to generate valid roadmap JSON from Gemini API."}), 500

        # Post-process tasks to assign unique task_ids and completion state
        processed_days = []
        total_tasks_count = 0

        for day in parsed_data.get("days", []):
            day_tasks = []
            for task in day.get("tasks", []):
                total_tasks_count += 1
                day_tasks.append({
                    "task_id": str(uuid.uuid4()),
                    "notebook_id": task.get("notebook_id", notebook_ids[0]),
                    "notebook_title": task.get("notebook_title", notebook_titles[0] if notebook_titles else "Subject"),
                    "title": task.get("title", "Study Task"),
                    "action_type": task.get("action_type", "note"),
                    "completed": False,
                    "completed_at": None,
                    "payload": task.get("payload", {})
                })

            processed_days.append({
                "day_number": day.get("day_number", 1),
                "title": day.get("title", f"Day {day.get('day_number', 1)} Plan"),
                "estimated_minutes": day.get("estimated_minutes", total_daily_minutes),
                "tasks": day_tasks
            })

        plan_id = str(uuid.uuid4())
        plan_doc = {
            "id": plan_id,
            "user_email": email,
            "title": parsed_data.get("roadmap_title", f"Active Roadmap: {', '.join(notebook_titles)}"),
            "notebook_ids": notebook_ids,
            "notebook_titles": notebook_titles,
            "duration_option": duration_option,
            "daily_hours": daily_hours,
            "total_tasks": total_tasks_count,
            "completed_tasks": 0,
            "progress_percentage": 0.0,
            "created_at": str(datetime.datetime.now()),
            "updated_at": str(datetime.datetime.now()),
            "days": processed_days
        }

        save_study_plan(plan_doc)
        if USING_MONGO: plan_doc.pop('_id', None)

        log_activity(email, "Created Active Roadmap", f"Plan ID {plan_id} created with {total_tasks_count} tasks")
        return jsonify(plan_doc)

    except Exception as e:
        print(f"❌ Roadmap Generation Error: {e}")
        return jsonify({"error": f"Backend Error: {str(e)}"}), 500


@app.route('/get-study-plan', methods=['GET', 'POST'])
def get_study_plan_endpoint():
    data = request.json or {} if request.method == 'POST' else request.args
    plan_id = data.get('plan_id')
    email = data.get('email')

    plan = get_study_plan(plan_id=plan_id, user_email=email)
    if plan:
        if USING_MONGO: plan.pop('_id', None)
        return jsonify(plan)
    return jsonify({"error": "No active study plan found for user."}), 404


@app.route('/update-task-status', methods=['POST'])
def update_task_status():
    data = request.json or {}
    plan_id = data.get('plan_id')
    task_id = data.get('task_id')
    completed = data.get('completed', True)

    if not plan_id or not task_id:
        return jsonify({"error": "plan_id and task_id are required"}), 400

    plan = get_study_plan(plan_id=plan_id)
    if not plan:
        return jsonify({"error": "Study plan not found"}), 404

    completed_count = 0
    total_count = 0

    for day in plan.get('days', []):
        for task in day.get('tasks', []):
            total_count += 1
            if task.get('task_id') == task_id:
                task['completed'] = completed
                task['completed_at'] = str(datetime.datetime.now()) if completed else None
            if task.get('completed'):
                completed_count += 1

    plan['total_tasks'] = total_count
    plan['completed_tasks'] = completed_count
    plan['progress_percentage'] = round((completed_count / total_count * 100), 1) if total_count > 0 else 0.0

    save_study_plan(plan)
    if USING_MONGO: plan.pop('_id', None)

    user_email = plan.get('user_email', 'unknown')
    log_activity(user_email, "Updated Roadmap Task", f"Task {task_id} marked completed: {completed}. Progress: {plan['progress_percentage']}%")

    return jsonify(plan)

# --- MULTIPLAYER KAHOOT-STYLE ENDPOINTS REMAIN UNCHANGED BELOW ---
@app.route('/host-game', methods=['POST'])
def host_game():
    data = request.json
    code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    email = data.get('email', 'guest')
    
    active_games[code] = {
        "host_email": email,
        "quiz_data": data.get('quiz_data', []),
        "players": {},
        "status": "waiting"
    }
    
    log_activity(email, "Hosted Live Game", f"Created game room with code: {code}")
    return jsonify({"code": code})

@app.route('/join-game', methods=['POST'])
def join_game():
    data = request.json
    code = data.get('code', '').upper()
    name = data.get('name', 'Anonymous')
    
    if code in active_games:
        if active_games[code]['status'] != 'waiting':
            return jsonify({"error": "Game already started! Too late to join."}), 400
            
        active_games[code]['players'][name] = 0
        log_activity("player_join", "Joined Game", f"Player '{name}' joined room {code}")
        return jsonify({
            "success": True, 
            "quiz_data": active_games[code]['quiz_data']
        })
    return jsonify({"error": "Invalid Game Code"}), 404

@app.route('/start-game', methods=['POST'])
def start_game():
    code = request.json.get('code', '').upper()
    if code in active_games:
        active_games[code]['status'] = 'playing'
        return jsonify({"success": True})
    return jsonify({"error": "Game not found"}), 404

@app.route('/get-game-status', methods=['POST'])
def get_game_status():
    code = request.json.get('code', '').upper()
    if code in active_games:
        players = list(active_games[code]['players'].keys())
        return jsonify({
            "status": active_games[code]['status'],
            "players": players
        })
    return jsonify({"error": "Game not found"}), 404

@app.route('/update-score', methods=['POST'])
def update_score():
    data = request.json
    code = data.get('code', '').upper()
    name = data.get('name')
    score = data.get('score', 0)
    
    if code in active_games and name in active_games[code]['players']:
        active_games[code]['players'][name] = score
        return jsonify({"success": True})
    return jsonify({"error": "Game or player not found"}), 404

@app.route('/get-leaderboard', methods=['POST'])
def get_leaderboard():
    code = request.json.get('code', '').upper()
    if code in active_games:
        players = active_games[code]['players']
        sorted_players = sorted(players.items(), key=lambda x: x[1], reverse=True)
        leaderboard = [{"name": k, "score": v} for k, v in sorted_players]
        return jsonify({"leaderboard": leaderboard, "status": active_games[code]['status']})
    return jsonify({"error": "Game not found"}), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
