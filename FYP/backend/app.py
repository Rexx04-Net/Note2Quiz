# note2Quiz Backend - DIAGNOSTIC VERSION
# Run with: python app.py

import os
import sys
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
from pypdf import PdfReader
from pptx import Presentation
from youtube_transcript_api import YouTubeTranscriptApi

# --- CONFIGURATION & DIAGNOSTICS ---
print("🔍 --- STARTING DIAGNOSTICS ---")
current_dir = os.path.dirname(os.path.abspath(__file__))
print(f"📂 Script Directory: {current_dir}")

# Check what files Python actually sees
try:
    files = os.listdir(current_dir)
    if "api_secrets.py" in files:
        print("✅ Found 'api_secrets.py' in directory.")
    else:
        print("❌ 'api_secrets.py' is NOT in the directory. Did you name it correctly?")
        print(f"   Files found: {files}")
except Exception as e:
    print(f"⚠️ Could not list files: {e}")

# Attempt Import with detailed error reporting
GEMINI_API_KEY = None
try:
    # We force Python to look in the current directory
    sys.path.append(current_dir)
    from api_secrets import GEMINI_API_KEY
    print("✅ Successfully imported API Key via Python Import.")
except Exception as e:
    print(f"\n❌ IMPORT FAILED. Real Error Message: {e}")
    print("⚠️ Attempting Manual File Read as backup...")
    
    # MANUAL FALLBACK: Read the file like a text file
    try:
        secret_path = os.path.join(current_dir, "api_secrets.py")
        with open(secret_path, "r", encoding="utf-8") as f:
            for line in f:
                if "GEMINI_API_KEY" in line and "=" in line:
                    # Extract content between quotes or after equals sign
                    parts = line.split("=", 1)[1].strip().strip('"').strip("'")
                    GEMINI_API_KEY = parts
                    print(f"✅ Manual Read Successful! Key starts with: {GEMINI_API_KEY[:5]}...")
                    break
    except Exception as e2:
        print(f"❌ Manual Read Failed: {e2}")

print("--------------------------------\n")

app = Flask(__name__)
CORS(app) 

# --- IN-MEMORY STORAGE ---
active_games = {}

# --- AI SETUP ---
try:
    if not GEMINI_API_KEY:
        print("❌ AI Setup Skipped: No API Key found.")
        model = None
    else:
        genai.configure(api_key=GEMINI_API_KEY)
        chosen_model = 'models/gemini-1.5-flash'
        try:
            for m in genai.list_models():
                if 'generateContent' in m.supported_generation_methods:
                    if 'flash' in m.name:
                        chosen_model = m.name
                        break
                    elif 'pro' in m.name:
                        chosen_model = m.name
        except: pass
        print(f"✅ AI Ready: {chosen_model}")
        model = genai.GenerativeModel(chosen_model)
except Exception as e:
    print(f"❌ Connection Error: {e}")
    model = None

# --- HELPER FUNCTIONS ---
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
    except: return None

def process_content(req):
    notes = req.form.get('notes', '')
    yt_url = req.form.get('youtube_url', '')
    if yt_url:
        yt_text = extract_youtube_transcript(yt_url)
        if yt_text: notes += f"\n\n[YOUTUBE]: {yt_text}"
    if 'file' in req.files:
        f = req.files['file']
        if f.filename.endswith('.pdf'): notes += f"\n[PDF]: {extract_text_from_pdf(f)}"
        elif f.filename.endswith('.pptx'): notes += f"\n[PPTX]: {extract_text_from_pptx(f)}"
    return notes

# --- ENDPOINTS ---

@app.route('/', methods=['GET'])
def home(): return "Note2Quiz Server Running! 🚀"

@app.route('/generate-notes', methods=['POST'])
def generate_notes():
    content = process_content(request)
    if len(content) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"Create comprehensive study notes (Markdown format) for:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        return jsonify({"notes": resp.text})
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/generate-flashcards', methods=['POST'])
def generate_flashcards():
    content = process_content(request)
    try:
        prompt = f"Create 10 flashcards. JSON format: [{{'front': 'Question', 'back': 'Answer'}}]. Content:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/generate-quiz', methods=['POST'])
def generate_quiz():
    content = process_content(request)
    try:
        prompt = f"""
        Create a Quiz. 
        IMPORTANT: The 'answer' field MUST match exactly one of the strings in 'options'.
        JSON format: [ {{ "question": "...", "options": ["A", "B", "C", "D"], "answer": "A", "damage": 20 }} ]
        Content: {content[:30000]}
        """
        resp = model.generate_content(prompt)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: return jsonify({"error": str(e)}), 500

# --- MULTIPLAYER ---

@app.route('/host-game', methods=['POST'])
def host_game():
    content = process_content(request)
    if len(content) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"""
        Create a Multiplayer Quiz.
        IMPORTANT: 'answer' must be the exact text string from 'options'.
        JSON format: [ {{ "question": "...", "options": ["A", "B", "C", "D"], "answer": "A", "damage": 20 }} ]
        Content: {content[:30000]}
        """
        resp = model.generate_content(prompt)
        quiz_data = json.loads(resp.text.replace("```json", "").replace("```", "").strip())
        
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
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