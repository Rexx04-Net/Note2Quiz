# note2Quiz Backend - Final Polish (YouTube Auto-Caption Fix)
# Run with: python app.py

import os
import json
import re
import random
import string
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
from pypdf import PdfReader
from pptx import Presentation
from youtube_transcript_api import YouTubeTranscriptApi

# --- CONFIGURATION ---
# ✅ Your REAL key:
gemini_api_key = "AIzaSyDufIGbbd3q7wrhrUBuCazHGnJPLLPsDCY"

app = Flask(__name__)
CORS(app) 

# --- IN-MEMORY STORAGE ---
active_games = {}

# --- AI SETUP ---
try:
    if not gemini_api_key:
        print("❌ ERROR: API Key is empty.")
        model = None
    else:
        genai.configure(api_key=gemini_api_key)
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
except: model = None

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
    """
    Robust YouTube Extraction (Fixed for older libraries):
    1. Tries standard English
    2. Tries Auto-Generated English
    3. Fallback to basic get_transcript if list_transcripts fails
    """
    try:
        # Extract Video ID using Regex (Handles youtube.com and youtu.be)
        match = re.search(r"(?:v=|\/)([0-9A-Za-z_-]{11})", url)
        if not match: 
            print("❌ Invalid YouTube URL format")
            return None
        video_id = match.group(1)
        print(f"📺 Processing Video ID: {video_id}")

        transcript_data = []

        # ATTEMPT 1: Advanced Method (Supports selecting language)
        try:
            if hasattr(YouTubeTranscriptApi, 'list_transcripts'):
                transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
                try:
                    # Try finding English (Manual or Auto)
                    transcript = transcript_list.find_transcript(['en', 'en-US', 'en-GB'])
                except:
                    # If no English specific found, take the first available
                    print("⚠️ No explicit English tag found, using fallback...")
                    transcript = next(iter(transcript_list))
                
                transcript_data = transcript.fetch()
            else:
                # Force fallback if method doesn't exist
                raise AttributeError("list_transcripts not found")
                
        except (AttributeError, Exception) as e:
            # ATTEMPT 2: Legacy Method (Works on older library versions)
            print(f"⚠️ Advanced mode failed ({e}), switching to legacy mode...")
            try:
                transcript_data = YouTubeTranscriptApi.get_transcript(video_id)
            except Exception as e2:
                print(f"❌ Legacy mode also failed: {e2}")
                return None

        full_text = " ".join([t['text'] for t in transcript_data])
        
        print(f"✅ Extracted {len(full_text)} characters from YouTube.")
        return full_text

    except Exception as e:
        print(f"❌ YouTube Error: {e}")
        return None

def process_content(req):
    notes = req.form.get('notes', '')
    yt_url = req.form.get('youtube_url', '')
    
    if yt_url:
        yt_text = extract_youtube_transcript(yt_url)
        if yt_text: 
            notes += f"\n\n[YOUTUBE TRANSCRIPT]:\n{yt_text}"
        else:
            # If YouTube fails, we don't crash, we just log it. 
            pass

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
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content found. YouTube video might not have captions."}), 400
    try:
        prompt = f"Create comprehensive study notes (Markdown format) for:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        return jsonify({"notes": resp.text})
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/generate-flashcards', methods=['POST'])
def generate_flashcards():
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"Create 10 flashcards. JSON format: [{{'front': 'Question', 'back': 'Answer'}}]. Content:\n{content[:30000]}"
        resp = model.generate_content(prompt)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/generate-quiz', methods=['POST'])
def generate_quiz():
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
    try:
        prompt = f"""
        Create a Quiz. 
        IMPORTANT: The 'answer' field MUST match exactly one of the strings in 'options'.
        JSON format: [ {{ "question": "...", "options": ["Option A", "Option B", "Option C", "Option D"], "answer": "Option A", "damage": 20 }} ]
        Content: {content[:30000]}
        """
        resp = model.generate_content(prompt)
        return jsonify(json.loads(resp.text.replace("```json", "").replace("```", "").strip()))
    except Exception as e: return jsonify({"error": str(e)}), 500

# --- MULTIPLAYER ---

@app.route('/host-game', methods=['POST'])
def host_game():
    content = process_content(request)
    if len(content.strip()) < 50: return jsonify({"error": "Not enough content."}), 400
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