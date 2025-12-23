# note2Quiz Backend - UPDATED WITH USER LOGIN & SAVED RECORDS
# Run with: python app.py

import os
import sys
import re
import json
import random
import string
import time
import uuid
from datetime import datetime
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
from pypdf import PdfReader
from pptx import Presentation
from youtube_transcript_api import YouTubeTranscriptApi

# --- CONFIGURATION ---
print("🔍 --- STARTING BACKEND ---")
current_dir = os.path.dirname(os.path.abspath(__file__))
GEMINI_API_KEY = None
DATA_FILE = os.path.join(current_dir, "users_data.json")

# Secure Key Loading
try:
    sys.path.append(current_dir)
    from api_secrets import GEMINI_API_KEY
    print("✅ Successfully imported API Key.")
except:
    try:
        with open(os.path.join(current_dir, "api_secrets.py"), "r", encoding="utf-8") as f:
            for line in f:
                if "GEMINI_API_KEY" in line and "=" in line:
                    GEMINI_API_KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    except: pass

app = Flask(__name__)
CORS(app) 

# --- PERSISTENCE LAYER ---
def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_data(data):
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=4)

# Load data on startup
users_db = load_data()
active_games = {}
generation_progress = {} 

# --- AI CONFIG ---
CHOSEN_MODEL_NAME = 'models/gemini-1.5-flash'
try:
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel(CHOSEN_MODEL_NAME)
    else:
        model = None
except:
    model = None

# --- HELPER FUNCTIONS ---
def update_progress(task_id, value):
    if task_id:
        generation_progress[task_id] = value

def extract_text_from_pdf(file_stream):
    try:
        reader = PdfReader(file_stream)
        text = ""
        for page in reader.pages:
            if page.extract_text(): text += page.extract_text() + "\n"
        return text
    except: return ""

def extract_text_from_pptx(file_stream):
    try:
        prs = Presentation(file_stream)
        text = ""
        for slide in prs.slides:
            for shape in slide.shapes:
                if hasattr(shape, "text"): text += shape.text + "\n"
        return text
    except: return ""

def extract_youtube_transcript(url):
    print(f"📺 Fetching YouTube: {url}")
    try:
        match = re.search(r"(?:v=|\/)([0-9A-Za-z_-]{11})", url)
        if not match: return None
        video_id = match.group(1)
        try:
            transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
            try:
                transcript = transcript_list.find_transcript(['en', 'en-US'])
            except:
                transcript = next(iter(transcript_list))
            data = transcript.fetch()
        except:
            data = YouTubeTranscriptApi.get_transcript(video_id)
        return " ".join([t['text'] for t in data])
    except Exception as e:
        print(f"❌ YouTube Error: {e}")
        return None

def process_content(req):
    notes = req.form.get('notes', '')
    yt_url = req.form.get('youtube_url', '')
    
    if yt_url:
        yt_text = extract_youtube_transcript(yt_url)
        if yt_text: notes += f"\n\n[YOUTUBE TRANSCRIPT]:\n{yt_text}"

    if 'file' in req.files:
        f = req.files['file']
        if f.filename.endswith('.pdf'): 
            text = extract_text_from_pdf(f)
            if text: notes += f"\n[PDF]: {text}"
        elif f.filename.endswith('.pptx'): 
            text = extract_text_from_pptx(f)
            if text: notes += f"\n[PPTX]: {text}"
            
    return notes

# --- AUTH & RECORDS ENDPOINTS ---

@app.route('/login', methods=['POST'])
def login():
    """Simple email login. Creates user if not exists."""
    email = request.json.get('email')
    if not email: return jsonify({"error": "Email required"}), 400
    
    if email not in users_db:
        users_db[email] = {"records": []}
        save_data(users_db)
    
    return jsonify({"message": "Login successful", "email": email})

@app.route('/get-records', methods=['POST'])
def get_records():
    email = request.json.get('email')
    if not email or email not in users_db:
        return jsonify([])
    
    # Sort: Pinned first, then by date
    records = users_db[email]["records"]
    records.sort(key=lambda x: (not x.get('isPinned', False), x.get('timestamp', 0)), reverse=True)
    return jsonify(records)

@app.route('/save-record', methods=['POST'])
def save_record():
    data = request.json
    email = data.get('email')
    if not email or email not in users_db:
        return jsonify({"error": "User not found"}), 404

    record_id = data.get('id')
    
    new_record = {
        "id": record_id if record_id else str(uuid.uuid4()),
        "title": data.get('title', 'Untitled Note'),
        "content": data.get('content', ''),
        "type": data.get('type', 'text'), # text or video
        "youtubeUrl": data.get('youtubeUrl', ''),
        "isPinned": data.get('isPinned', False),
        "timestamp": time.time(),
        "dateStr": datetime.now().strftime("%Y-%m-%d %H:%M")
    }

    # If ID exists, update. Else append.
    records = users_db[email]["records"]
    existing_index = next((index for (index, d) in enumerate(records) if d["id"] == new_record["id"]), None)
    
    if existing_index is not None:
        # Preserve pinned state if not explicitly sent, though usually it is
        if 'isPinned' not in data:
            new_record['isPinned'] = records[existing_index].get('isPinned', False)
        records[existing_index] = new_record
    else:
        records.insert(0, new_record)
    
    save_data(users_db)
    return jsonify({"message": "Saved", "record": new_record})

@app.route('/delete-record', methods=['POST'])
def delete_record():
    data = request.json
    email = data.get('email')
    record_id = data.get('id')
    
    if email in users_db:
        users_db[email]["records"] = [r for r in users_db[email]["records"] if r["id"] != record_id]
        save_data(users_db)
        return jsonify({"success": True})
    return jsonify({"error": "User not found"}), 404

@app.route('/toggle-pin', methods=['POST'])
def toggle_pin():
    data = request.json
    email = data.get('email')
    record_id = data.get('id')
    
    if email in users_db:
        for r in users_db[email]["records"]:
            if r["id"] == record_id:
                r["isPinned"] = not r.get("isPinned", False)
                break
        save_data(users_db)
        return jsonify({"success": True})
    return jsonify({"error": "User not found"}), 404

@app.route('/rename-record', methods=['POST'])
def rename_record():
    data = request.json
    email = data.get('email')
    record_id = data.get('id')
    new_title = data.get('title')
    
    if email in users_db:
        for r in users_db[email]["records"]:
            if r["id"] == record_id:
                r["title"] = new_title
                break
        save_data(users_db)
        return jsonify({"success": True})
    return jsonify({"error": "User not found"}), 404

# --- CONTENT GENERATION ENDPOINTS ---

@app.route('/', methods=['GET'])
def home(): return "Note2Quiz Server Running! 🚀"

@app.route('/get-transcript', methods=['POST'])
def get_transcript_endpoint():
    data = request.json
    url = data.get('url')
    if not url: return jsonify({"error": "No URL provided"}), 400
    
    print(f"📥 Fetching transcript for: {url}")
    text = extract_youtube_transcript(url)
    
    if text: return jsonify({"transcript": text})
    else: return jsonify({"error": "Could not fetch transcript."}), 404

@app.route('/generate-notes', methods=['POST'])
def generate_notes():
    task_id = request.form.get('task_id')
    update_progress(task_id, 10)

    content = process_content(request)
    if len(content.strip()) < 50: 
        update_progress(task_id, 100)
        return jsonify({"error": "Not enough content."}), 400
    
    try:
        update_progress(task_id, 40)
        print(f"🤖 Generating Notes using {CHOSEN_MODEL_NAME}...")
        prompt = f"Create comprehensive study notes (Markdown format) for:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        update_progress(task_id, 90)
        return jsonify({"notes": resp.text})
    except Exception as e: 
        update_progress(task_id, 100)
        return jsonify({"error": str(e)}), 500

@app.route('/generate-quiz', methods=['POST'])
def generate_quiz():
    task_id = request.form.get('task_id')
    update_progress(task_id, 10)
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
    
    try:
        update_progress(task_id, 30)
        prompt = f"""
        Create a Quiz. JSON format: [ {{ "question": "...", "options": ["A", "B", "C", "D"], "answer": "A", "damage": 20 }} ]
        Content: {content[:30000]}
        """
        resp = model.generate_content(prompt)
        update_progress(task_id, 90)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: 
        return jsonify({"error": str(e)}), 500

@app.route('/generate-flashcards', methods=['POST'])
def generate_flashcards():
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"Create 10 flashcards. JSON format: [{{'front': 'Question', 'back': 'Answer'}}]. Content:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: return jsonify({"error": str(e)}), 500

# --- MULTIPLAYER ENDPOINTS ---
# (Keeping basic multiplayer logic for compatibility)

@app.route('/host-game', methods=['POST'])
def host_game():
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"""Create a Multiplayer Quiz. JSON format: [ {{ "question": "...", "options": ["A", "B", "C", "D"], "answer": "A", "damage": 20 }} ] Content: {content[:30000]}"""
        resp = model.generate_content(prompt)
        quiz_data = json.loads(resp.text.replace("```json", "").replace("```", "").strip())
        while True:
            code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
            if code not in active_games: break
        active_games[code] = { "quiz": quiz_data, "players": {} }
        return jsonify({"code": code, "quiz": quiz_data})
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/join-game', methods=['POST'])
def join_game():
    data = request.json
    code = data.get('code', '').upper()
    name = data.get('name', 'Unknown')
    if code in active_games:
        if name not in active_games[code]['players']: active_games[code]['players'][name] = 0
        return jsonify({"quiz": active_games[code]['quiz']})
    return jsonify({"error": "Invalid Game Code"}), 404

@app.route('/update-score', methods=['POST'])
def update_score():
    data = request.json
    code = data.get('code', '').upper()
    if code in active_games:
        active_games[code]['players'][data.get('name')] = data.get('score')
        return jsonify({"status": "ok"})
    return jsonify({"error": "Game not found"}), 404

@app.route('/get-leaderboard/<code_id>', methods=['GET'])
def get_leaderboard(code_id):
    code_id = code_id.upper()
    if code_id in active_games:
        return jsonify(sorted(active_games[code_id]['players'].items(), key=lambda x: x[1], reverse=True))
    return jsonify([]), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)