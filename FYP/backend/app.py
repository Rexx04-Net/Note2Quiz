import os
import sys

# Configure UTF-8 encoding on Windows to avoid UnicodeEncodeError with emojis
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

import json
import uuid
import datetime
import time
import re
import random
import string
import hashlib
import google.generativeai as genai
from flask import Flask, request, jsonify, Response, stream_with_context
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

# Register Automation & Timetable Blueprints
try:
    from blueprints.automation import automation_bp
    from blueprints.timetable import timetable_bp
    from database.indexes import init_indexes
    from jobs.notifier import check_and_send_due_notifications
    from apscheduler.schedulers.background import BackgroundScheduler
    import atexit

    app.register_blueprint(automation_bp)
    app.register_blueprint(timetable_bp)
    init_indexes()

    # Initialize APScheduler for notification polling
    scheduler = BackgroundScheduler()
    scheduler.add_job(func=check_and_send_due_notifications, trigger="interval", seconds=10, id="notifier_job")
    scheduler.start()
    atexit.register(lambda: scheduler.shutdown(wait=False))
    print("✅ [Scheduler] APScheduler background worker started successfully (polling every 10s).")
except Exception as bp_err:
    print(f"⚠️ [Automation Blueprint] Initialization error: {bp_err}")


# --- FILE STORAGE FOR LOCAL PERSISTENCE ---
DATA_DIR = os.path.join(current_dir, "data_storage")
os.makedirs(DATA_DIR, exist_ok=True)

def _load_json_file(filename, default):
    filepath = os.path.join(DATA_DIR, filename)
    if os.path.exists(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ Error loading {filename}: {e}")
    return default

def _save_json_file(filename, data):
    filepath = os.path.join(DATA_DIR, filename)
    try:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️ Error saving {filename}: {e}")

# --- DATABASE CONNECTION ---
USING_MONGO = False
try:
    client = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=2000)
    db = client["note2quiz_db"]
    notebooks_col = db["notebooks"]
    feedback_col = db["feedback"]
    users_col = db["users"]  
    logs_col = db["activity_logs"] # Dedicated folder for tracking actions
    study_plans_col = db["study_plans"] # Active AI Study Roadmap collection
    ai_cache_col = db["ai_cache"] # Semantic content fingerprint caching
    
    client.server_info()
    print("✅ Connected to MongoDB")
    USING_MONGO = True
except:
    print("⚠️ MongoDB not found. Using persistent local JSON file storage.")
    memory_notebooks = _load_json_file("notebooks.json", [])
    memory_feedback = _load_json_file("feedback.json", [])
    memory_study_plans = _load_json_file("study_plans.json", [])
    memory_activity_logs = _load_json_file("activity_logs.json", [])
    memory_ai_cache = _load_json_file("ai_cache.json", {})
    
# Active Games Memory
active_games = {}

# --- HIERARCHICAL TASK-AWARE AI MODEL ROUTER (GEMINI 3.X & 2.X FAMILY) ---
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

TASK_MODEL_PROFILES = {
    # 1. Complex Structure & Deep Reasoning (Active AI Roadmaps, Timetable OCR & Parsing, Comprehensive Study Guides)
    "complex_structure": [
        "gemini-2.5-pro",          # Top Pro-tier reasoning & schema compliance on free tier
        "gemini-3.7-flash",        # Latest stable flagship with deep reasoning
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-2.5-flash",
        "gemini-3-flash-preview",
    ],
    # 2. Ultra-Fast Lightweight & Interactive (Flashcards, Mind Maps, Executive Briefings, Chat Stream, Instant Hints)
    "fast_interactive": [
        "gemini-3.5-flash-lite",   # Ultra-fast sub-second generation
        "gemini-3.1-flash-lite",   # Lightweight instant response
        "gemini-3.7-flash",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemma-4",                 # High-speed open model
        "gemini-2.5-flash",
    ],
    # 3. Balanced Standard (Quizzes, Diagnostic Checks, Adaptive Remediation Drills)
    "standard": [
        "gemini-3.7-flash",        # Fastest standard generation
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
    ]
}

def generate_with_fallback(prompt, task_type="standard"):
    """
    Dynamically routes prompt to optimal model queue based on task complexity (complex_structure, fast_interactive, standard).
    Provides automatic failover with exponential backoff if 429 quota is encountered.
    """
    models = TASK_MODEL_PROFILES.get(task_type, TASK_MODEL_PROFILES["standard"])
    last_error = None
    rate_limited = False

    for model_name in models:
        try:
            print(f"🤖 [Task: {task_type}] Trying AI Model: {model_name}...")
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            print(f"✅ Success with {model_name} ({task_type})")
            return response.text
        except Exception as e:
            err_str = str(e)
            print(f"⚠️ Failed with {model_name}: {err_str}")
            last_error = e
            if "429" in err_str or "ResourceExhausted" in err_str or "quota" in err_str.lower():
                rate_limited = True
            if "API_KEY_INVALID" in err_str or "API_KEY" in err_str:
                break
            time.sleep(0.5)

    if rate_limited:
        return "AI Error: Gemini Free Tier quota exceeded (Rate Limit 429). Please wait ~30-60 seconds before trying again, or add a fresh GEMINI_API_KEY in api_secrets.py."
    return f"AI Error: All models failed. Last error: {str(last_error)}"

def stream_with_fallback(prompt, task_type="fast_interactive"):
    """Generator that yields streaming text chunks from Gemini API in real-time with task-specific routing."""
    models = TASK_MODEL_PROFILES.get(task_type, TASK_MODEL_PROFILES["fast_interactive"])
    last_error = None
    rate_limited = False

    for model_name in models:
        try:
            print(f"🤖 [Stream: {task_type}] Trying AI Model: {model_name}...")
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt, stream=True)
            for chunk in response:
                if chunk and chunk.text:
                    yield chunk.text
            print(f"✅ [Stream: {task_type}] Completed successfully with {model_name}")
            return
        except Exception as e:
            err_str = str(e)
            print(f"⚠️ [Stream: {task_type}] Failed with {model_name}: {err_str}")
            last_error = e
            if "429" in err_str or "ResourceExhausted" in err_str or "quota" in err_str.lower():
                rate_limited = True
            if "API_KEY_INVALID" in err_str or "API_KEY" in err_str:
                break
            time.sleep(0.5)

    if rate_limited:
        yield "\n\n⚠️ *AI Quota Exceeded (Rate Limit 429). Please wait 30-60 seconds before generating again.*"
    else:
        yield f"\n\n⚠️ *AI Generation Error: {str(last_error)}*"

# Helper function for tracking activity
def log_activity(email, action, details=""):
    log_entry = {
        "email": email,
        "action": action,
        "details": details,
        "timestamp": str(datetime.datetime.now())
    }
    if USING_MONGO:
        try:
            logs_col.insert_one(log_entry)
            print(f"📝 LOGGED: {email} -> {action}")
        except Exception as e:
            print(f"⚠️ Failed to log activity: {e}")
    else:
        try:
            memory_activity_logs.append(log_entry)
            _save_json_file("activity_logs.json", memory_activity_logs)
            print(f"📝 LOGGED (File): {email} -> {action}")
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
                _save_json_file("notebooks.json", memory_notebooks)
                return
        memory_notebooks.append(notebook)
        _save_json_file("notebooks.json", memory_notebooks)

def save_feedback(feedback_entry):
    if USING_MONGO:
        feedback_col.insert_one(feedback_entry)
    else:
        memory_feedback.append(feedback_entry)
        _save_json_file("feedback.json", memory_feedback)

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
                _save_json_file("study_plans.json", memory_study_plans)
                return
        memory_study_plans.append(plan)
        _save_json_file("study_plans.json", memory_study_plans)

def get_user_study_plans(user_email):
    if USING_MONGO:
        return list(study_plans_col.find({"user_email": user_email}).sort("updated_at", -1))
    else:
        return [p for p in reversed(memory_study_plans) if p.get("user_email") == user_email]

def delete_study_plan(plan_id, user_email):
    if USING_MONGO:
        study_plans_col.delete_one({"id": plan_id, "user_email": user_email})
    else:
        global memory_study_plans
        memory_study_plans = [p for p in memory_study_plans if not (p.get("id") == plan_id and p.get("user_email") == user_email)]
        _save_json_file("study_plans.json", memory_study_plans)

# --- SEMANTIC CACHING & RAG CHUNKING ENGINE ---
def compute_content_hash(sources, tool_type, difficulty, output_language):
    """Computes a unique SHA-256 fingerprint for input sources and generation parameters."""
    hasher = hashlib.sha256()
    cache_version = "v4_no_hashes" if tool_type == "report" else "v1"
    hasher.update(f"{tool_type}:{difficulty}:{output_language}:{cache_version}".encode('utf-8'))
    if isinstance(sources, list):
        for s in sorted(sources, key=lambda x: str(x.get('id', x.get('title', '')))):
            c = s.get('content', '')
            t = s.get('title', '')
            hasher.update(f"{t}:{c[:10000]}".encode('utf-8'))
    return hasher.hexdigest()

def get_content_cache(cache_key):
    """Retrieves cached AI generation result by content fingerprint."""
    if not cache_key:
        return None
    if USING_MONGO:
        try:
            doc = ai_cache_col.find_one({"cache_key": cache_key})
            if doc:
                print(f"⚡ [CACHE HIT] Retrieved instant response for key {cache_key[:8]}...")
                return doc.get("data")
        except Exception as e:
            print(f"⚠️ Cache read error: {e}")
    else:
        if cache_key in memory_ai_cache:
            print(f"⚡ [CACHE HIT - Local] Retrieved response for key {cache_key[:8]}...")
            return memory_ai_cache.get(cache_key)
    return None

def set_content_cache(cache_key, tool_type, data):
    """Stores AI generation result into cache."""
    if not data or not cache_key:
        return
    cache_doc = {
        "cache_key": cache_key,
        "tool_type": tool_type,
        "data": data,
        "created_at": str(datetime.datetime.now())
    }
    if USING_MONGO:
        try:
            ai_cache_col.replace_one({"cache_key": cache_key}, cache_doc, upsert=True)
            print(f"💾 [CACHE STORED] Saved response for key {cache_key[:8]}...")
        except Exception as e:
            print(f"⚠️ Cache write error: {e}")
    else:
        memory_ai_cache[cache_key] = data
        _save_json_file("ai_cache.json", memory_ai_cache)

def extract_semantic_chunks(text, chunk_size=750, overlap=100):
    """Splits text into semantic chunks respecting paragraph and sentence boundaries."""
    if not text or len(text) <= chunk_size:
        return [text] if text else []
    
    paragraphs = [p.strip() for p in re.split(r'\n{2,}', text) if p.strip()]
    chunks = []
    current_chunk = ""
    
    for p in paragraphs:
        if len(current_chunk) + len(p) <= chunk_size:
            current_chunk = (current_chunk + "\n\n" + p).strip()
        else:
            if current_chunk:
                chunks.append(current_chunk)
            if len(p) > chunk_size:
                sentences = re.split(r'(?<=[.!?。！？\n])\s+', p)
                temp_sub = ""
                for s in sentences:
                    if len(temp_sub) + len(s) <= chunk_size:
                        temp_sub = (temp_sub + " " + s).strip()
                    else:
                        if temp_sub:
                            chunks.append(temp_sub)
                        temp_sub = s
                current_chunk = temp_sub
            else:
                current_chunk = p
    if current_chunk:
        chunks.append(current_chunk)
    return chunks

def score_chunk_density(chunk):
    """Heuristic scoring for academic conceptual density."""
    keywords = [
        "definition", "define", "concept", "principle", "algorithm", "formula",
        "advantage", "disadvantage", "difference", "comparison", "example",
        "step", "process", "framework", "architecture", "method", "theorem",
        "function", "component", "property", "classification", "key", "important"
    ]
    score = 0.0
    lower_chunk = chunk.lower()
    for kw in keywords:
        score += lower_chunk.count(kw) * 1.5
    score += len(re.findall(r'^\s*[-*•\d+.]\s+', chunk, re.M)) * 2.0
    length_factor = min(1.0, len(chunk) / 400.0)
    return score * length_factor

def rank_and_assemble_rag_context(sources, max_chars=12000):
    """Assembles a high-density, balanced RAG context across all sources."""
    if not sources:
        return ""
    
    all_source_chunks = []
    for source in sources:
        s_title = source.get('title', 'Document')
        s_content = source.get('content', '')
        chunks = extract_semantic_chunks(s_content)
        scored_chunks = [(score_chunk_density(c), s_title, c) for c in chunks]
        scored_chunks.sort(key=lambda x: x[0], reverse=True)
        all_source_chunks.append((s_title, scored_chunks))
    
    selected_chunks = []
    total_chars = 0
    max_rounds = max((len(sc[1]) for sc in all_source_chunks), default=0)
    
    for round_idx in range(max_rounds):
        for s_title, scored_chunks in all_source_chunks:
            if round_idx < len(scored_chunks):
                score, title, chunk_text = scored_chunks[round_idx]
                formatted_piece = f"\n--- [{title}] ---\n{chunk_text}\n"
                if total_chars + len(formatted_piece) <= max_chars:
                    selected_chunks.append(formatted_piece)
                    total_chars += len(formatted_piece)
                else:
                    break
        if total_chars >= max_chars:
            break
    
    if not selected_chunks:
        return "\n".join([f"--- {s.get('title')} ---\n{s.get('content', '')[:3000]}" for s in sources])
    
    print(f"⚡ [RAG Engine] Compacted context to {len(selected_chunks)} high-signal chunks ({total_chars} chars).")
    return "\n".join(selected_chunks)

def get_filtered_sources(notebook_id, selected_source_ids=None, fallback_sources=None):
    nb = get_notebook(notebook_id)
    sources = []
    if nb and nb.get("sources"):
        sources = nb.get("sources", [])
    elif fallback_sources and isinstance(fallback_sources, list):
        sources = fallback_sources
        if nb:
            nb["sources"] = fallback_sources
            save_notebook(nb)

    if not sources:
        return []

    if selected_source_ids and isinstance(selected_source_ids, list) and len(selected_source_ids) > 0:
        filtered = [s for s in sources if str(s.get('id', '')) in selected_source_ids or str(s.get('title', '')) in selected_source_ids]
        if filtered:
            sources = filtered
    return sources

def get_context(notebook_id, selected_source_ids=None, fallback_sources=None, use_rag=True, max_chars=12000):
    sources = get_filtered_sources(notebook_id, selected_source_ids, fallback_sources)
    if not sources:
        return ""
    if use_rag:
        return rank_and_assemble_rag_context(sources, max_chars=max_chars)
    
    context = ""
    for source in sources:
        context += f"\n--- SOURCE: {source.get('title', 'Document')} ({source.get('type', 'file')}) ---\n{source.get('content', '')}\n"
    return context

def clean_ai_response(text):
    if not text or not isinstance(text, str):
        return None
    cleaned = text.strip()

    # 1. Strip markdown fences if present
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:].strip()
    elif cleaned.startswith("```"):
        cleaned = cleaned[3:].strip()
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3].strip()

    # 2. Try direct parse (strict=False allows unescaped control chars / newlines in strings)
    try:
        return json.loads(cleaned, strict=False)
    except Exception:
        pass

    # 3. Try finding complete outermost JSON array or object
    match = re.search(r'(\[[\s\S]*\]|\{[\s\S]*\})', cleaned)
    if match:
        try:
            return json.loads(match.group(0), strict=False)
        except Exception:
            pass

    # 4. Resilient repair for truncated JSON arrays: [ { ... }, { ... } ... (cut off)
    array_match = re.search(r'\[\s*\{', cleaned)
    if array_match:
        start_idx = array_match.start()
        sub = cleaned[start_idx:]
        last_obj_end = sub.rfind('}')
        if last_obj_end != -1:
            candidate = sub[:last_obj_end + 1] + "]"
            try:
                parsed = json.loads(candidate, strict=False)
                if isinstance(parsed, list) and len(parsed) > 0:
                    print(f"🔧 [clean_ai_response] Successfully rescued truncated JSON array with {len(parsed)} questions.")
                    return parsed
            except Exception:
                pass

    # 4b. Resilient repair for truncated JSON objects: { ... "days": [ ... ] ... (cut off)
    if "{" in cleaned:
        start_idx = cleaned.find("{")
        sub = cleaned[start_idx:]
        last_brace = sub.rfind("}")
        if last_brace != -1:
            candidate = sub[:last_brace + 1]
            try:
                parsed = json.loads(candidate, strict=False)
                if isinstance(parsed, dict) and len(parsed) > 0:
                    return parsed
            except Exception:
                for suffix in ["}", "]}", "]}}", "]}}}"]:
                    try:
                        p = json.loads(candidate + suffix, strict=False)
                        if isinstance(p, dict):
                            print(f"🔧 [clean_ai_response] Repaired truncated JSON object with suffix '{suffix}'")
                            return p
                    except Exception:
                        pass

    # 5. Extract individual JSON objects via regex if outer array syntax broke
    try:
        obj_matches = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', cleaned)
        parsed_objects = []
        for om in obj_matches:
            try:
                obj = json.loads(om, strict=False)
                if isinstance(obj, dict):
                    parsed_objects.append(obj)
            except Exception:
                pass
        if parsed_objects:
            print(f"🔧 [clean_ai_response] Extracted {len(parsed_objects)} JSON objects via regex.")
            return parsed_objects
    except Exception:
        pass

    # 6. Fallback for single-quoted Python dict/list literals
    try:
        import ast
        eval_data = ast.literal_eval(cleaned)
        if isinstance(eval_data, (list, dict)):
            return eval_data
    except Exception:
        pass

    return None

def sanitize_text(text):
    if not isinstance(text, str):
        return ""
    # Strip null bytes and non-printable control characters that break UTF-8/fonts
    cleaned = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', text)
    return cleaned.strip()

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
                if hasattr(shape, "text") and shape.text:
                    text.append(shape.text)
        return "\n".join(text)
    except: return ""

def extract_text_from_ppt(file_stream):
    try:
        if hasattr(file_stream, 'read'):
            file_bytes = file_stream.read()
        else:
            file_bytes = bytes(file_stream)

        utf16_strings = re.findall(rb'(?:[\x20-\x7E\t\r\n]\x00){4,}', file_bytes)
        ascii_strings = re.findall(rb'[\x20-\x7E\t\r\n]{4,}', file_bytes)

        ignore_prefixes = (
            'Current User', 'PowerPoint Document', 'Microsoft', 'Times New Roman',
            'Arial', 'Calibri', 'Courier New', 'Symbol', 'Wingdings', 'Tahoma',
            'Segoe UI', 'SummaryInformation', 'DocumentSummaryInformation'
        )

        extracted_lines = []
        for s in utf16_strings:
            try:
                t = s.decode('utf-16-le', errors='ignore').strip()
                if t and len(t) >= 4 and not t.startswith(ignore_prefixes):
                    t_clean = sanitize_text(t)
                    if len(t_clean) >= 3:
                        extracted_lines.append(t_clean)
            except Exception:
                pass

        for s in ascii_strings:
            try:
                t = s.decode('ascii', errors='ignore').strip()
                if t and len(t) >= 4 and not t.startswith(ignore_prefixes):
                    t_clean = sanitize_text(t)
                    if len(t_clean) >= 3 and not re.match(r'^[0-9a-fA-F]{8,}$', t_clean):
                        extracted_lines.append(t_clean)
            except Exception:
                pass

        seen = set()
        cleaned = []
        for line in extracted_lines:
            if line not in seen:
                seen.add(line)
                cleaned.append(line)

        return "\n".join(cleaned)
    except Exception as e:
        print(f"⚠️ [extract_text_from_ppt] Error: {e}")
        return ""

def extract_youtube_transcript(url_or_id):
    try:
        video_id = None
        if "youtube.com/watch" in url_or_id:
            match = re.search(r'v=([a-zA-Z0-9_-]{11})', url_or_id)
            if match: video_id = match.group(1)
        elif "youtu.be/" in url_or_id:
            match = re.search(r'youtu\.be/([a-zA-Z0-9_-]{11})', url_or_id)
            if match: video_id = match.group(1)
        elif len(url_or_id.strip()) == 11:
            video_id = url_or_id.strip()

        if not video_id:
            return None, "Invalid YouTube URL format."

        try:
            transcript_list = YouTubeTranscriptApi.get_transcript(video_id, languages=['en', 'ms', 'id', 'zh-Hans', 'zh-Hant', 'es', 'fr'])
        except:
            transcripts = YouTubeTranscriptApi.list_transcripts(video_id)
            transcript_obj = next(iter(transcripts))
            transcript_list = transcript_obj.fetch()

        full_text = " ".join([item['text'] for item in transcript_list])
        title = f"YouTube Video ({video_id})"
        return full_text, title
    except Exception as e:
        return None, f"Could not extract YouTube transcript: {str(e)}"

def extract_web_article(url):
    try:
        import urllib.request
        from html.parser import HTMLParser

        class SimpleTextExtractor(HTMLParser):
            def __init__(self):
                super().__init__()
                self.text = []
                self.ignore = False

            def handle_starttag(self, tag, attrs):
                if tag in ['script', 'style', 'head', 'title', 'meta']:
                    self.ignore = True

            def handle_endtag(self, tag):
                if tag in ['script', 'style', 'head', 'title', 'meta']:
                    self.ignore = False

            def handle_data(self, data):
                if not self.ignore and data.strip():
                    self.text.append(data.strip())

        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        )
        html_bytes = urllib.request.urlopen(req, timeout=10).read()
        html_text = html_bytes.decode('utf-8', errors='ignore')

        parser = SimpleTextExtractor()
        parser.feed(html_text)
        extracted = "\n".join(parser.text)

        title_match = re.search(r'<title>(.*?)</title>', html_text, re.IGNORECASE)
        title = title_match.group(1).strip() if title_match else "Web Article"

        return extracted[:40000], title
    except Exception as e:
        return None, f"Could not scrape web article: {str(e)}"

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
            log_activity(email, "Registered Account", "First time user sign-in")
        else:
            log_activity(email, "Logged In", "User signed in successfully")

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
    data = request.get_json(silent=True) or {}

    notebook_id = request.form.get('notebook_id') or data.get('notebook_id')
    source_type = request.form.get('type') or data.get('type', 'text')
    content = ""
    title = "New Source"

    if 'file' in request.files:
        f = request.files['file']
        title = f.filename
        fname_lower = f.filename.lower()
        if fname_lower.endswith('.pdf'):
            content = extract_text_from_pdf(f)
        elif fname_lower.endswith('.pptx'):
            content = extract_text_from_pptx(f)
        elif fname_lower.endswith('.ppt'):
            content = extract_text_from_ppt(f)
        elif fname_lower.endswith('.docx'):
            try:
                import docx
                doc = docx.Document(f)
                content = "\n".join([p.text for p in doc.paragraphs if p.text])
            except Exception:
                try:
                    f.seek(0)
                    content = f.read().decode('utf-8', errors='ignore')
                except Exception:
                    content = ""
        else:
            try:
                content = f.read().decode('utf-8', errors='ignore')
            except:
                content = ""

        content = sanitize_text(content)
        if not content.strip():
            content = f"[Document Content: {f.filename}]"
    else:
        raw_input = (request.form.get('content') or data.get('content', '')).strip()
        custom_title = (request.form.get('title') or data.get('title', '')).strip()

        if "youtube.com" in raw_input or "youtu.be" in raw_input or source_type == 'youtube':
            extracted_text, vid_title = extract_youtube_transcript(raw_input)
            if extracted_text:
                content = extracted_text
                title = custom_title if custom_title else f"📹 {vid_title}"
                source_type = 'youtube'
            else:
                return jsonify({"error": vid_title}), 400

        elif raw_input.startswith("http://") or raw_input.startswith("https://") or source_type in ['link', 'url']:
            extracted_text, web_title = extract_web_article(raw_input)
            if extracted_text:
                content = extracted_text
                title = custom_title if custom_title else f"🌐 {web_title}"
                source_type = 'link'
            else:
                return jsonify({"error": web_title}), 400

        else:
            content = raw_input
            title = custom_title if custom_title else "📝 Text Note"

    if not content.strip(): 
        return jsonify({"error": "No content or text extracted from source."}), 400

    new_source = {
        "id": str(uuid.uuid4()),
        "title": title,
        "content": content,
        "type": source_type,
        "date": str(datetime.datetime.now())
    }
    
    nb = get_notebook(notebook_id)
    if not nb and notebook_id:
        nb = {
            "id": notebook_id,
            "user_email": request.form.get('email') or data.get('email') or 'guest',
            "title": "Notebook",
            "sources": [],
            "created_at": str(datetime.datetime.now())
        }

    if nb:
        nb.setdefault('sources', []).append(new_source)
        save_notebook(nb)
        
        user_email = nb.get('user_email', 'unknown')
        log_activity(user_email, "Added Source", f"Added {source_type} source: {title}")
        
        return jsonify(new_source)
    return jsonify({"error": "Notebook not found"}), 404


@app.route('/delete-source', methods=['POST'])
def delete_source():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    source_id = data.get('source_id')

    if not notebook_id or not source_id:
        return jsonify({"error": "notebook_id and source_id are required"}), 400

    nb = get_notebook(notebook_id)
    if not nb:
        return jsonify({"error": "Notebook not found"}), 404

    sources = nb.get('sources', [])
    updated_sources = [s for s in sources if s.get('id') != source_id]
    nb['sources'] = updated_sources

    save_notebook(nb)

    user_email = nb.get('user_email', 'unknown')
    log_activity(user_email, "Deleted Source", f"Deleted source {source_id} from notebook {notebook_id}")

    return jsonify({"success": True})

def build_briefing_prompt(filtered_sources, context, output_language):
    """Constructs a modular, topic-by-topic briefing document prompt when multiple sources are selected."""
    today_str = datetime.datetime.now().strftime("%B %d, %Y")

    def _topic_sort_key(s):
        title = s.get('title', '')
        match = re.search(r'topic[_\s\-]*(\d+)', title, re.IGNORECASE)
        if match:
            return (0, int(match.group(1)), title)
        return (1, 0, title)

    sorted_sources = sorted(filtered_sources, key=_topic_sort_key)

    if len(sorted_sources) > 1:
        topic_descriptions = []
        for idx, src in enumerate(sorted_sources, 1):
            raw_title = src.get('title', f'Topic {idx}')
            clean_t = re.sub(r'\.(pdf|docx|pptx|txt|md|html)$', '', raw_title, flags=re.IGNORECASE).replace('_', ' ').strip()
            topic_descriptions.append(f"{idx}. {clean_t}")

        topics_list_str = "\n".join(topic_descriptions)

        prompt = f"""Write an executive, highly structured study briefing document in {output_language}.
The user has specifically selected {len(sorted_sources)} distinct topics/sources:
{topics_list_str}

CRITICAL REQUIREMENT:
The user demands a clear TOPIC-BY-TOPIC briefing breakdown.
You MUST provide an individual, dedicated section for EACH of the {len(sorted_sources)} selected topics in the exact order listed above.
Do NOT merge them into one generic summary!
Every selected topic MUST have its own dedicated section header: `## 📘 Topic [N]: [Topic Title]`.

STRICT FORMATTING RULE:
Do NOT output any triple hashes '###' anywhere in your response. Only use '## ' for section titles.

Start with the header line: **Generated Date:** {today_str}
Do NOT include 'To:' or 'Subject:' metadata lines.

Structure the document exactly with these Markdown sections:

## 🎯 Core Objectives
- 3 to 4 cross-cutting learning goals synthesizing across all {len(sorted_sources)} selected topics.

## 📊 Executive Overview
- High-level executive synthesis summarizing how these {len(sorted_sources)} topics interconnect in the curriculum.

## 📚 Topic-by-Topic Briefing Breakdown
"""
        for idx, src in enumerate(sorted_sources, 1):
            raw_title = src.get('title', f'Topic {idx}')
            clean_t = re.sub(r'\.(pdf|docx|pptx|txt|md|html)$', '', raw_title, flags=re.IGNORECASE).replace('_', ' ').strip()
            prompt += f"""
## 📘 Topic {idx}: {clean_t}
- **Overview & Scope**: Core purpose, problem space, or domain addressed in this topic.
- **Key Concepts & Theoretical Foundations**: 3-4 essential terms, definitions, architectures, or frameworks from this topic.
- **Technical Mechanisms & Methods**: Key algorithms, workflows, design patterns, or tools discussed in this source.
- **Critical Exam Takeaways**: Essential points, common misconceptions, or formulas students must master.
"""

        prompt += f"""
## 💡 Cross-Topic Synthesis & Exam Mastery Takeaways
- **Interconnections & Comparisons**: Direct comparisons, dependencies, or trade-offs between the topics.
- **High-Yield Exam Focus**: Critical questions, probable exam topics, and essential takeaways.

Context:
{context}"""
    else:
        single_src = sorted_sources[0] if sorted_sources else {}
        raw_title = single_src.get('title', 'Study Material')
        clean_t = re.sub(r'\.(pdf|docx|pptx|txt|md|html)$', '', raw_title, flags=re.IGNORECASE).replace('_', ' ').strip()

        prompt = f"""Write a comprehensive study briefing document in {output_language} for "{clean_t}".
Start with the header line: **Generated Date:** {today_str}
Do NOT include 'To:' or 'Subject:' metadata lines.
Structure with clear section headings containing relevant emojis:

## 🎯 Core Objectives
- 3 to 4 clear educational objectives for this topic.

## 📊 Executive Summary
- Concise overview of this document and its central concepts.

## 📌 Key Concepts & Detailed Breakdown
- In-depth, structured explanation of core definitions, architectures, mechanisms, and frameworks with clear bullet points.

## 💡 Practical Takeaways & Exam Checklist
- High-yield summary, exam checklist points, and practical applications.

Context:
{context}"""

    return prompt

@app.route('/generate-studio-item', methods=['POST'])
def generate_studio_item():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    tool_type = data.get('tool_type')
    difficulty = data.get('difficulty', 'Standard')
    output_language = data.get('output_language', 'English')
    selected_source_ids = data.get('selected_source_ids')

    fallback_sources = data.get('sources')
    nb = get_notebook(notebook_id)
    if not nb and notebook_id:
        nb = {
            "id": notebook_id,
            "user_email": data.get('user_email', 'guest'),
            "title": data.get('notebook_title', 'Notebook'),
            "sources": fallback_sources or [],
            "created_at": str(datetime.datetime.now())
        }
        save_notebook(nb)

    user_email = nb.get('user_email', 'unknown') if nb else 'unknown'
    log_activity(user_email, f"Generated {tool_type.capitalize()}", f"Triggered Gemini AI for {difficulty} {tool_type}")

    filtered_sources = get_filtered_sources(notebook_id, selected_source_ids, fallback_sources)
    if not filtered_sources:
        return jsonify({"type": "text", "data": "Not enough content in the selected sources. Please select or add valid sources first."})

    # 1. Check Semantic Content Cache (For static study artifacts: flashcard, mindmap, report)
    cache_key = compute_content_hash(filtered_sources, tool_type, difficulty, output_language)
    cached_payload = get_content_cache(cache_key) if tool_type != "quiz" else None
    if cached_payload:
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        if isinstance(cached_payload, (list, dict)):
            if tool_type == "flashcard":
                item_title = f"Flashcard Deck ({len(cached_payload)} Cards) [⚡ Instant]"
            else:
                item_title = f"Mind Map [⚡ Instant]"

            history_item = {
                "id": str(uuid.uuid4()),
                "tool_type": tool_type,
                "title": item_title,
                "difficulty": difficulty,
                "data": cached_payload,
                "created_at": now_str,
                "cached": True
            }
            if nb:
                nb.setdefault('history', []).insert(0, history_item)
                save_notebook(nb)
            return jsonify({"type": "json", "data": cached_payload, "history_item": history_item, "cached": True})
        else:
            item_title = "Executive Report [⚡ Instant]"
            history_item = {
                "id": str(uuid.uuid4()),
                "tool_type": tool_type,
                "title": item_title,
                "difficulty": difficulty,
                "data": str(cached_payload),
                "created_at": now_str,
                "cached": True
            }
            if nb:
                nb.setdefault('history', []).insert(0, history_item)
                save_notebook(nb)
            return jsonify({"type": "text", "data": str(cached_payload), "history_item": history_item, "cached": True})

    # 2. Build High-Density RAG Context (Reduces tokens by 60%, accelerates LLM inference)
    context = rank_and_assemble_rag_context(filtered_sources, max_chars=12000)
    if len(context) < 50:
        return jsonify({"type": "text", "data": "Not enough content in the selected sources. Please select or add valid sources first."})

    num_selected = len(filtered_sources)
    num_selected = max(1, num_selected)

    prompt = ""
    if tool_type == "quiz":
        mistakes = nb.get('mistakes_bank', []) if nb else []
        remediation_directive = ""
        if mistakes:
            top_m = mistakes[:3]
            mistake_context = "\n".join([f"- Concept Mistake: '{m.get('question')}' (Student incorrectly answered '{m.get('user_answer')}'; Correct: '{m.get('correct_answer')}'). Rationale: {m.get('explanation')}" for m in top_m])
            remediation_directive = f"""
🎯 ADAPTIVE LEARNING & WEAKNESS REINFORCEMENT DIRECTIVE:
The student previously made mistakes on these concepts:
{mistake_context}

INSTRUCTIONS:
1. Generate 2 to 3 targeted 'Remediation Variant' questions that specifically re-test and solidify the concepts from their mistake history (set "is_remediation": true for these).
2. Generate the remaining questions as fresh, novel concept questions from the course notes (set "is_remediation": false for these).
"""

        if difficulty == "Hard":
            target_q_count = max(8, min(15, num_selected * 2))
            prompt = f"""You are a university professor creating an exhaustive, master-level Hard Mode Quiz covering all {num_selected} selected lectures and topics in {output_language}.
            
{remediation_directive}

CRITICAL HARD-MODE SPECIFICATIONS:
1. EXPLICIT QUESTION TARGET: Generate EXACTLY {target_q_count} comprehensive questions so that every selected lecture, algorithm, edge case, and topic is thoroughly tested.
2. HIGH-DIFFICULTY REASONING: Focus on deep conceptual understanding, algorithm analysis, complexity comparisons, scenario-based problem solving, edge cases, and code tracing.
3. Return valid JSON only with NO markdown formatting, NO backticks.
4. RANDOMIZE OPTION POSITIONS: The correct answer MUST be randomly distributed across positions (Option A, B, C, or D). Do NOT always make the first option the correct answer.

STRICT JSON FORMAT:
[
    {{
        "question": "Question text here?",
        "options": ["First Choice", "Second Choice", "Third Choice", "Fourth Choice"],
        "answer": "Third Choice",
        "hint": "A short, helpful clue without giving the answer away.",
        "explanation": "Detailed step-by-step rationale for the correct answer.",
        "is_remediation": false
    }}
]

IMPORTANT:
- Keep the JSON keys in English ("question", "options", "answer", "hint", "explanation", "is_remediation").
- Translate questions/options/hints/explanations into {output_language}.
- Make sure "answer" matches one of the options exactly.
Context: {context}"""
        elif difficulty == "Easy":
            prompt = f"""Generate an Easy Warmup Quiz with 5 to 8 questions in {output_language} covering key definitions.
            
{remediation_directive}

            Return valid JSON only.
            Randomize the correct answer position among the options (do NOT always place it in the first position).
            STRICT JSON FORMAT:
            [
                {{
                    "question": "Question text?",
                    "options": ["Choice 1", "Choice 2", "Choice 3", "Choice 4"],
                    "answer": "Choice 2",
                    "hint": "A short clue.",
                    "explanation": "Brief explanation.",
                    "is_remediation": false
                }}
            ]
            Context: {context}"""
        else: # Standard
            prompt = f"""Generate a crisp Standard Quiz with EXACTLY 10 questions in {output_language} covering key principles.
            
{remediation_directive}

            Return valid JSON only with NO markdown formatting, NO backticks.
            Keep explanations concise (1-2 sentences) for fast generation.
            Randomize the correct answer position among the options (do NOT always place it in the first position).
            STRICT JSON FORMAT:
            [
                {{
                    "question": "Question text?",
                    "options": ["Choice 1", "Choice 2", "Choice 3", "Choice 4"],
                    "answer": "Choice 3",
                    "hint": "A short clue.",
                    "explanation": "Concise 1-2 sentence explanation.",
                    "is_remediation": false
                }}
            ]
            Context: {context}"""

    elif tool_type == "flashcard":
        prompt = f"""Generate 10 flashcards in {output_language}.
        Return valid JSON only in this format:
        [{{ "front": "Term", "back": "Definition" }}]
        Keep the keys "front" and "back" exactly as written in English.
        Context: {context}"""

    elif tool_type == "mindmap":
        prompt = f"""Create a detailed hierarchical visual mind map in {output_language}.
        Return valid JSON only.
        STRICT JSON FORMAT:
        {{
            "title": "Central Topic Title",
            "icon": "🧠",
            "description": "Overview summary of the central topic",
            "children": [
                {{
                    "title": "Main Category 1",
                    "icon": "⚡",
                    "description": "Short description of category 1",
                    "children": [
                        {{
                            "title": "Sub-topic 1.1",
                            "icon": "📌",
                            "description": "Key point details",
                            "children": []
                        }}
                    ]
                }}
            ]
        }}
        Context: {context}"""

    elif tool_type == "report":
        prompt = build_briefing_prompt(filtered_sources, context, output_language)

    try:
        task_category = "fast_interactive" if tool_type in ["flashcard", "mindmap", "report"] else "standard"
        text = generate_with_fallback(prompt, task_type=task_category)
        if text.startswith("AI Error:"): return jsonify({"type": "text", "data": text})

        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

        if tool_type in ["quiz", "flashcard", "mindmap"]:
            json_data = clean_ai_response(text)
            if json_data:
                if tool_type == "quiz":
                    if isinstance(json_data, list):
                        import random
                        for q in json_data:
                            if isinstance(q, dict) and "options" in q and isinstance(q["options"], list):
                                random.shuffle(q["options"])
                    item_title = f"{difficulty} Quiz ({len(json_data)} Qs)"
                elif tool_type == "flashcard": item_title = f"Flashcard Deck ({len(json_data)} Cards)"
                else: item_title = f"Mind Map: {json_data.get('title', 'Concept Tree')}"

                # Cache successful structured JSON
                set_content_cache(cache_key, tool_type, json_data)

                history_item = {
                    "id": str(uuid.uuid4()),
                    "tool_type": tool_type,
                    "title": item_title,
                    "difficulty": difficulty,
                    "data": json_data,
                    "created_at": now_str
                }
                if nb:
                    nb.setdefault('history', []).insert(0, history_item)
                    save_notebook(nb)
                return jsonify({"type": "json", "data": json_data, "history_item": history_item})
            elif tool_type == "mindmap":
                # Fallback to raw text parsing for legacy mindmaps
                pass
            else:
                print(f"⚠️ [clean_ai_response Failed] Tool: {tool_type}. Raw response:\n{text[:400]}")
                return jsonify({"type": "text", "data": "Error: AI response was not valid JSON."})

        if tool_type == "report":
            text = text.replace('### ', '## ').replace('###', '')
        item_title = "Executive Report" if tool_type == "report" else "Mind Map"
        set_content_cache(cache_key, tool_type, text)
        history_item = {
            "id": str(uuid.uuid4()),
            "tool_type": tool_type,
            "title": item_title,
            "difficulty": difficulty,
            "data": text,
            "created_at": now_str
        }
        if nb:
            nb.setdefault('history', []).insert(0, history_item)
            save_notebook(nb)

        return jsonify({"type": "text", "data": text, "history_item": history_item})
    except Exception as e:
        return jsonify({"type": "text", "data": f"Backend Error: {str(e)}"})


@app.route('/stream-studio-item', methods=['POST'])
def stream_studio_item():
    sse_request_started_at = time.perf_counter()
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    tool_type = data.get('tool_type', 'report')
    difficulty = data.get('difficulty', 'Standard')
    output_language = data.get('output_language', 'English')
    selected_source_ids = data.get('selected_source_ids')
    fallback_sources = data.get('sources')

    nb = get_notebook(notebook_id)
    if not nb and notebook_id:
        nb = {
            "id": notebook_id,
            "user_email": data.get('user_email', 'guest'),
            "title": data.get('notebook_title', 'Notebook'),
            "sources": fallback_sources or [],
            "created_at": str(datetime.datetime.now())
        }
        save_notebook(nb)

    user_email = nb.get('user_email', 'unknown') if nb else 'unknown'
    log_activity(user_email, f"Streaming {tool_type.capitalize()}", f"Triggered live SSE streaming for {tool_type}")

    filtered_sources = get_filtered_sources(notebook_id, selected_source_ids, fallback_sources)
    if not filtered_sources:
        def err_gen():
            yield f"data: {json.dumps({'error': 'Not enough content in the selected sources. Please upload valid sources first.'})}\n\n"
        return Response(err_gen(), mimetype='text/event-stream')

    cache_key = compute_content_hash(filtered_sources, tool_type, difficulty, output_language)
    cached_text = get_content_cache(cache_key)

    # 1. Instant Cached Stream (0.05s simulated high-speed stream from memory)
    if cached_text and isinstance(cached_text, str):
        print("SSE_RESPONSE_CACHED=true", flush=True)
        def cached_stream():
            chunk_size = 80
            for i in range(0, len(cached_text), chunk_size):
                sub = cached_text[i:i+chunk_size]
                yield f"data: {json.dumps({'chunk': sub})}\n\n"
                time.sleep(0.01)
            now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            item_title = "Executive Briefing Doc [⚡ Instant]"
            history_item = {
                "id": str(uuid.uuid4()),
                "tool_type": tool_type,
                "title": item_title,
                "difficulty": difficulty,
                "data": cached_text,
                "created_at": now_str,
                "cached": True
            }
            if nb:
                current_nb = get_notebook(notebook_id) or nb
                current_nb.setdefault('history', []).insert(0, history_item)
                save_notebook(current_nb)
            yield f"data: {json.dumps({'done': True, 'history_item': history_item, 'cached': True})}\n\n"
        response = Response(stream_with_context(cached_stream()), mimetype='text/event-stream')
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        response.headers['Connection'] = 'keep-alive'
        return response

    # 2. Build High-Density RAG Context
    print("SSE_RESPONSE_CACHED=false", flush=True)
    context = rank_and_assemble_rag_context(filtered_sources, max_chars=12000)

    if tool_type == "report":
        prompt = build_briefing_prompt(filtered_sources, context, output_language)
    else:
        prompt = f"""Generate comprehensive structured study notes in {output_language} with headings, key points, definitions, code/formula examples, and takeaways.
        Context: {context}"""

    def event_stream():
        full_accumulated_text = []
        first_chunk_logged = False
        try:
            for text_chunk in stream_with_fallback(prompt):
                full_accumulated_text.append(text_chunk)
                chunk_event = f"data: {json.dumps({'chunk': text_chunk})}\n\n"
                if not first_chunk_logged:
                    first_chunk_logged = True
                    first_chunk_ms = (time.perf_counter() - sse_request_started_at) * 1000
                    print(f"SSE_FIRST_CHUNK_MS={first_chunk_ms:.2f}", flush=True)
                yield chunk_event

            complete_text = "".join(full_accumulated_text).strip()
            if tool_type == "report":
                complete_text = complete_text.replace('### ', '## ').replace('###', '')
            now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            item_title = "Executive Briefing Doc" if tool_type == "report" else "AI Synthesized Notes"

            # Cache completed stream result
            set_content_cache(cache_key, tool_type, complete_text)

            history_item = {
                "id": str(uuid.uuid4()),
                "tool_type": tool_type,
                "title": item_title,
                "difficulty": difficulty,
                "data": complete_text,
                "created_at": now_str
            }

            # Persist to notebook history
            if nb:
                current_nb = get_notebook(notebook_id) or nb
                current_nb.setdefault('history', []).insert(0, history_item)
                save_notebook(current_nb)

            yield f"data: {json.dumps({'done': True, 'history_item': history_item})}\n\n"
        except Exception as stream_err:
            yield f"data: {json.dumps({'error': str(stream_err)})}\n\n"

    response = Response(stream_with_context(event_stream()), mimetype='text/event-stream')
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'
    response.headers['Connection'] = 'keep-alive'
    return response


@app.route('/save-quiz-result', methods=['POST'])
def save_quiz_result():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    score = data.get('score', 0)
    correct_answers = data.get('correct_answers', 0)
    total_questions = data.get('total_questions', 0)
    percentage = data.get('percentage', 0)
    quiz_data = data.get('quiz_data', [])
    breakdown = data.get('breakdown', [])
    quiz_title = data.get('quiz_title', '')

    if not notebook_id:
        return jsonify({"error": "notebook_id is required"}), 400

    nb = get_notebook(notebook_id)
    if not nb:
        return jsonify({"error": "Notebook not found"}), 404

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    result_entry = {
        "id": str(uuid.uuid4()),
        "score": score,
        "correct_answers": correct_answers,
        "total_questions": total_questions,
        "percentage": percentage,
        "played_at": now_str,
        "quiz_data": quiz_data,
        "breakdown": breakdown,
        "quiz_title": quiz_title
    }

    # Track mistakes for Adaptive Weakness Drill
    if isinstance(breakdown, list):
        mistakes_list = nb.setdefault('mistakes_bank', [])
        for item in breakdown:
            is_corr = item.get('is_correct', False)
            if not is_corr:
                q_text = item.get('question', '').strip()
                if q_text and not any(m.get('question') == q_text for m in mistakes_list):
                    mistakes_list.insert(0, {
                        "id": str(uuid.uuid4()),
                        "question": q_text,
                        "user_answer": item.get('selected_answer', ''),
                        "correct_answer": item.get('correct_answer', ''),
                        "explanation": item.get('explanation', '') or item.get('hint', ''),
                        "recorded_at": now_str
                    })

    nb.setdefault('quiz_results', []).insert(0, result_entry)
    save_notebook(nb)

    user_email = nb.get('user_email', 'unknown')
    log_activity(user_email, "Played Quiz", f"Scored {score} pts ({percentage}%)")

    return jsonify({"success": True, "result": result_entry})


@app.route('/api/mistakes-bank/generate-drill', methods=['POST', 'OPTIONS'])
@app.route('/generate-weakness-drill', methods=['POST', 'OPTIONS'])
def generate_weakness_drill():
    if request.method == 'OPTIONS':
        return jsonify({"success": True}), 200
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    output_language = data.get('output_language', 'English')
    fallback_sources = data.get('sources')

    if not notebook_id:
        return jsonify({"success": False, "error": "notebook_id is required"}), 400

    nb = get_notebook(notebook_id)
    if not nb and notebook_id:
        nb = {
            "id": notebook_id,
            "user_email": data.get('user_email', 'guest'),
            "title": data.get('notebook_title', 'Notebook'),
            "sources": fallback_sources or [],
            "created_at": str(datetime.datetime.now())
        }
        save_notebook(nb)

    mistakes = nb.get('mistakes_bank', [])
    if not mistakes:
        return jsonify({
            "success": False,
            "has_mistakes": False,
            "drill_questions": [],
            "message": "🎉 No mistakes recorded yet! Take a standard or hard quiz first to identify your weak points."
        }), 200

    top_mistakes = mistakes[:6]
    mistake_summary = ""
    for idx, m in enumerate(top_mistakes, 1):
        mistake_summary += f"{idx}. Question: {m.get('question')}\n   Student's Prior Wrong Choice: {m.get('user_answer')}\n   Correct Concept: {m.get('correct_answer')}\n   Concept Clarification: {m.get('explanation')}\n\n"

    sources = get_filtered_sources(notebook_id, fallback_sources=fallback_sources)
    context = rank_and_assemble_rag_context(sources, max_chars=10000)

    prompt = f"""You are an expert adaptive tutor designing a targeted 'Weakness Remediation Drill' in {output_language}.
The student previously struggled with and failed the following concepts/questions:

--- STUDENT HISTORICAL MISTAKES ---
{mistake_summary}

--- RELEVANT COURSE NOTES CONTEXT ---
{context}

STRICT REMEDIATION INSTRUCTIONS:
1. Generate EXACTLY 5 to 7 high-yield, targeted VARIATION questions specifically designed to test, clarify, and solidify the exact concepts and misconceptions from the mistake log.
2. DO NOT simply repeat the exact same questions word-for-word. Create conceptual variants, application scenarios, edge cases, and "why is X false" questions that address the root cause of their prior mistakes.
3. RANDOMIZE OPTION POSITIONS: The correct answer MUST be randomly distributed across positions (Option A, B, C, or D).
4. Return valid JSON only with NO markdown fences, NO backticks.

STRICT JSON FORMAT:
[
    {{
        "question": "Targeted remediation question text?",
        "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
        "answer": "Option 2",
        "hint": "A guiding clue helping them avoid their previous misconception.",
        "explanation": "Clear explanation of why this is correct and why common misconceptions fail."
    }}
]"""

    try:
        text = generate_with_fallback(prompt)
        if text.startswith("AI Error:"):
            return jsonify({"success": False, "error": text})

        json_data = clean_ai_response(text)
        if json_data and isinstance(json_data, list):
            import random
            for q in json_data:
                if isinstance(q, dict) and "options" in q and isinstance(q["options"], list):
                    random.shuffle(q["options"])

            now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            item_title = f"🎯 Weakness Drill ({len(json_data)} Qs)"
            history_item = {
                "id": str(uuid.uuid4()),
                "tool_type": "weakness_drill",
                "title": item_title,
                "difficulty": "Adaptive Drill",
                "data": json_data,
                "created_at": now_str,
                "is_weakness_drill": True
            }
            nb.setdefault('history', []).insert(0, history_item)
            save_notebook(nb)

            user_email = nb.get('user_email', 'unknown')
            log_activity(user_email, "Generated Weakness Drill", f"Created {len(json_data)} remediation questions")

            return jsonify({
                "success": True,
                "has_mistakes": True,
                "mistakes_count": len(mistakes),
                "drill_questions": json_data,
                "data": json_data,
                "history_item": history_item
            })
        else:
            return jsonify({"success": False, "error": "AI response was not valid JSON."})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


@app.route('/get-notebook-mistakes', methods=['GET'])
def get_notebook_mistakes():
    notebook_id = request.args.get('notebook_id')
    if not notebook_id:
        return jsonify({"error": "notebook_id required"}), 400
    nb = get_notebook(notebook_id)
    if not nb:
        return jsonify({"mistakes_count": 0, "mistakes": []})
    mistakes = nb.get('mistakes_bank', [])
    return jsonify({"mistakes_count": len(mistakes), "mistakes": mistakes})


@app.route('/api/mistakes-bank/all', methods=['GET'])
def get_all_user_mistakes():
    user_email = request.args.get('user_email', '').strip()
    all_nb = []
    if USING_MONGO:
        query = {}
        if user_email:
            query = {"$or": [{"user_email": user_email}, {"user_email": "guest"}, {"user_email": ""}]}
        all_nb = list(notebooks_col.find(query))
    else:
        for nb in memory_notebooks:
            if not user_email or nb.get('user_email') == user_email or nb.get('user_email') == 'guest':
                all_nb.append(nb)

    grouped_mistakes = []
    total_mistakes = 0
    for nb in all_nb:
        mistakes = nb.get('mistakes_bank', [])
        if mistakes:
            total_mistakes += len(mistakes)
            grouped_mistakes.append({
                "notebook_id": nb.get('id'),
                "course_name": nb.get('title', 'Notebook'),
                "mistakes_count": len(mistakes),
                "mistakes": mistakes,
                "sources": [s.get('name') for s in nb.get('sources', []) if isinstance(s, dict)]
            })

    grouped_mistakes.sort(key=lambda x: x['mistakes_count'], reverse=True)

    return jsonify({
        "success": True,
        "total_mistakes": total_mistakes,
        "courses_count": len(grouped_mistakes),
        "courses": grouped_mistakes
    }), 200


@app.route('/api/quizzes/<quiz_id>', methods=['GET'])
def get_saved_quiz_by_id(quiz_id):
    notebook_id = request.args.get('notebook_id')
    if notebook_id:
        nb = get_notebook(notebook_id)
        if nb:
            for item in nb.get('history', []):
                if item.get('id') == quiz_id:
                    return jsonify({"success": True, "quiz": item})
            for item in nb.get('quiz_results', []):
                if item.get('id') == quiz_id:
                    return jsonify({"success": True, "quiz": item})
    
    if USING_MONGO:
        doc = notebooks_col.find_one({"$or": [{"history.id": quiz_id}, {"quiz_results.id": quiz_id}]})
        if doc:
            for item in doc.get('history', []) + doc.get('quiz_results', []):
                if item.get('id') == quiz_id:
                    return jsonify({"success": True, "quiz": item})
    return jsonify({"success": False, "error": "Quiz not found"}), 404


@app.route('/get-notebook-history', methods=['POST'])
def get_notebook_history():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    nb = get_notebook(notebook_id)
    if not nb:
        return jsonify({"history": [], "quiz_results": []})
    
    return jsonify({
        "history": nb.get('history', []),
        "quiz_results": nb.get('quiz_results', [])
    })


@app.route('/delete-history-item', methods=['POST'])
def delete_history_item():
    data = request.json or {}
    notebook_id = data.get('notebook_id')
    item_id = data.get('item_id')
    item_type = data.get('type', 'generation')

    nb = get_notebook(notebook_id)
    if not nb:
        return jsonify({"error": "Notebook not found"}), 404

    if item_type == 'quiz_result':
        nb['quiz_results'] = [r for r in nb.get('quiz_results', []) if r.get('id') != item_id]
    else:
        nb['history'] = [h for h in nb.get('history', []) if h.get('id') != item_id]

    save_notebook(nb)
    return jsonify({"success": True})


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
        _save_json_file("notebooks.json", memory_notebooks)
        
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
    source_ids = data.get('source_ids', [])
    source_ids_set = {str(s).strip() for s in source_ids if str(s).strip()}
    duration_option = data.get('duration_option', 'AI Automated')  # 1 Day, 3 Days, 7 Days, AI Automated
    try:
        daily_hours = float(data.get('daily_hours', 2.0))
    except:
        daily_hours = 2.0

    if not notebook_ids:
        return jsonify({"error": "At least one notebook must be selected."}), 400

    collected_sources = []
    notebook_titles = []
    collected_mistakes = []
    
    for n_id in notebook_ids:
        nb = get_notebook(n_id)
        if nb:
            nb_title = nb.get("title", "Untitled Subject")
            notebook_titles.append(nb_title)
            for idx, source in enumerate(nb.get("sources", [])):
                src_id = str(source.get("id") or "").strip()
                src_title = str(source.get("title") or f"Topic {idx+1}").strip()
                src_filename = str(source.get("filename") or "").strip()
                src_content = source.get("content", "").strip()

                if source_ids_set:
                    is_match = (
                        src_id in source_ids_set or
                        src_title in source_ids_set or
                        src_filename in source_ids_set or
                        str(idx) in source_ids_set or
                        str(idx + 1) in source_ids_set
                    )
                    if not is_match:
                        continue

                if src_content:
                    collected_sources.append({
                        "notebook_id": n_id,
                        "notebook_title": nb_title,
                        "source_title": src_title,
                        "content_preview": src_content[:1500]
                    })
            for m in nb.get("mistakes_bank", []):
                collected_mistakes.append({
                    "question": m.get("question", ""),
                    "user_answer": m.get("user_answer", ""),
                    "correct_answer": m.get("correct_answer", ""),
                    "explanation": m.get("explanation", "")
                })

    if not collected_sources:
        return jsonify({"error": "Selected topics do not have lecture content. Please ensure topics have uploaded notes."}), 400

    total_sources_count = len(collected_sources)
    total_daily_minutes = int(daily_hours * 60)

    # Intelligently calculate realistic duration based on total topics
    if duration_option == 'AI Automated':
        if total_sources_count <= 2:
            target_days = 2
        elif total_sources_count <= 4:
            target_days = 3
        elif total_sources_count <= 7:
            target_days = 5
        elif total_sources_count <= 12:
            target_days = 7
        elif total_sources_count <= 18:
            target_days = 10
        else:
            target_days = min(14, max(7, (total_sources_count + 1) // 2))
    elif duration_option == '1 Day':
        target_days = 1
    elif duration_option == '3 Days':
        target_days = 3
    elif duration_option == '7 Days':
        target_days = 7
    else:
        target_days = 3

    # Build clear numbered topic catalog for prompt
    sources_catalog_text = ""
    for idx, s in enumerate(collected_sources, 1):
        sources_catalog_text += f"[{idx}] {s['notebook_title']} -> {s['source_title']}\nSummary Excerpt:\n{s['content_preview']}\n\n"

    mistakes_catalog_text = ""
    if collected_mistakes:
        mistakes_catalog_text = "USER'S REAL PAST MISTAKES FROM THESE NOTEBOOKS (Weave into SM-2 Review Drills):\n"
        for m_idx, m in enumerate(collected_mistakes[:8], 1):
            mistakes_catalog_text += f"- Mistake {m_idx}: Q: {m['question']} | Missed Answer: {m['user_answer']} | Correct: {m['correct_answer']}\n"

    # --- GEMINI SYSTEM PROMPT FOR ADVANCED SM-2 ACTIVE AI ROADMAP ---
    prompt = f"""You are a master Academic Curriculum Architect & Pedagogical AI Specialist implementing the SuperMemo-2 (SM-2) Spaced Repetition Science for Note2Quiz.
Your objective is to build a thorough, cognitively-optimized day-by-day Active Study Roadmap across {target_days} Days covering ALL {total_sources_count} lecture topics across {', '.join(notebook_titles)}.

PEDAGOGICAL & SM-2 ARCHITECTURE RULES (STRICTLY ENFORCED):
1. COMPLETE SYLLABUS COVERAGE (ZERO TOPIC OMISSION):
   - Every single one of the {total_sources_count} topics below MUST be scheduled across the {target_days} study days:
{sources_catalog_text}
{mistakes_catalog_text}

2. SM-2 SPACED REPETITION & INTERLEAVED RECALL PROTOCOL:
   - Initial Learning (Repetition 1, Day 1..N): Initial conceptual encoding (AI Synthesized Notes, Core Terms Flashcards, Diagnostic Assessment).
   - SM-2 Interleaved Review (Repetition 2 & 3, Interval 1d, 3d, 6d):
     * On Day 3, 5, 7, 10, weave in dedicated SM-2 Spaced Recall tasks (labeled "🧠 SM-2 Spaced Recall: [Topic]") that pull previously covered high-yield concepts and past mistakes back into active retrieval practice.
     * Mark these tasks with `"is_sm2_review": true`, `"sm2_interval": "3d"`, and `"ease_factor": 2.5`.

3. COGNITIVE LOAD & DIFFICULTY TIERING:
   - Tag every task with:
     * `"difficulty_tier"`: "Foundational" | "Intermediate" | "High-Yield Exam Focus"
     * `"cognitive_load"`: "Light" | "Moderate" | "Deep Focus"

4. INTERACTIVE WORKING MODULES IN 'payload':
   - "note": Comprehensive study note with markdown, LaTeX math/code, definitions, core theorems.
   - "flashcard": 8-12 high-impact active recall term-definition pairs.
   - "quiz": 4-8 diagnostic multiple-choice questions with 4 options, randomized answer, hints, and explanations.

Return ONLY a strict JSON object following this EXACT schema (do NOT wrap in ```json markdown formatting):

{{
  "roadmap_title": "Active Roadmap: {', '.join(notebook_titles)} ({total_sources_count} Topics, {target_days} Days)",
  "recommended_days": {target_days},
  "total_topics_count": {total_sources_count},
  "sm2_enabled": true,
  "days": [
    {{
      "day_number": 1,
      "title": "Day 1: [Specific Topic Names Covered on Day 1]",
      "estimated_minutes": {total_daily_minutes},
      "topics_covered": ["Topic 1 Name", "Topic 2 Name"],
      "focus_objective": "Initial encoding & active recall of fundamental principles",
      "tasks": [
        {{
          "title": "Read AI Notes: Topic 1 (Name) & Topic 2 (Name) [{notebook_titles[0]}]",
          "action_type": "note",
          "is_sm2_review": false,
          "sm2_interval": "1d",
          "difficulty_tier": "Foundational",
          "cognitive_load": "Deep Focus",
          "ease_factor": 2.5,
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "summary_text": "## 📌 Topic Synthesis\n### 1. Key Principles\n- **Core Concept**: Detailed explanation...\n\n### 2. Formulas & Implementation\n- Code or step-by-step example...\n\n### 3. Exam Takeaways\n- Key points to remember..."
          }}
        }},
        {{
          "title": "Active Recall Flashcards: Topic 1 & 2 Core Terms [{notebook_titles[0]}]",
          "action_type": "flashcard",
          "is_sm2_review": false,
          "sm2_interval": "1d",
          "difficulty_tier": "Intermediate",
          "cognitive_load": "Moderate",
          "ease_factor": 2.5,
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "flashcards": [
              {{"front": "Key Term 1", "back": "Precise Definition 1"}},
              {{"front": "Key Term 2", "back": "Precise Definition 2"}}
            ]
          }}
        }},
        {{
          "title": "Checkpoint Quiz: Topic 1 & 2 Assessment [{notebook_titles[0]}]",
          "action_type": "quiz",
          "is_sm2_review": false,
          "sm2_interval": "1d",
          "difficulty_tier": "High-Yield Exam Focus",
          "cognitive_load": "Deep Focus",
          "ease_factor": 2.5,
          "notebook_id": "{notebook_ids[0]}",
          "notebook_title": "{notebook_titles[0]}",
          "payload": {{
            "quiz_data": [
              {{
                "question": "Scenario-based question on Topic 1?",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "answer": "Option A",
                "hint": "Helpful hint",
                "explanation": "Detailed explanation"
              }}
            ]
          }}
        }}
      ]
    }}
  ]
}}"""

    log_activity(email, "Requested AI Roadmap", f"Notebooks: {notebook_titles}, Total Topics: {total_sources_count}, Duration: {target_days} Days, SM-2: Enabled")

    try:
        raw_text = generate_with_fallback(prompt, task_type="complex_structure")
        parsed_data = clean_ai_response(raw_text)

        if isinstance(parsed_data, list):
            full_dict = next((item for item in parsed_data if isinstance(item, dict) and "days" in item), None)
            if full_dict:
                parsed_data = full_dict
            else:
                day_items = [d for d in parsed_data if isinstance(d, dict) and ("tasks" in d or "day_number" in d)]
                if day_items:
                    parsed_data = {
                        "roadmap_title": f"Active Roadmap: {', '.join(notebook_titles)} ({total_sources_count} Topics, {target_days} Days)",
                        "recommended_days": target_days,
                        "total_topics_count": total_sources_count,
                        "days": day_items
                    }

        if not parsed_data or not isinstance(parsed_data, dict) or "days" not in parsed_data:
            return jsonify({"error": "Failed to generate valid roadmap JSON from Gemini API."}), 500

        # Post-process tasks to assign unique task_ids, SM-2 attributes, and completion state
        processed_days = []
        total_tasks_count = 0

        for day in parsed_data.get("days", []):
            day_tasks = []
            for task in day.get("tasks", []):
                total_tasks_count += 1
                
                # If quiz task, ensure answers are shuffled
                payload = task.get("payload", {})
                if task.get("action_type") == "quiz" and isinstance(payload.get("quiz_data"), list):
                    for q in payload["quiz_data"]:
                        if isinstance(q.get("options"), list) and len(q["options"]) > 1:
                            random.shuffle(q["options"])

                day_tasks.append({
                    "task_id": str(uuid.uuid4()),
                    "notebook_id": task.get("notebook_id", notebook_ids[0]),
                    "notebook_title": task.get("notebook_title", notebook_titles[0] if notebook_titles else "Subject"),
                    "title": task.get("title", "Study Task"),
                    "action_type": task.get("action_type", "note"),
                    "is_sm2_review": task.get("is_sm2_review", False),
                    "sm2_interval": task.get("sm2_interval", "1d"),
                    "difficulty_tier": task.get("difficulty_tier", "Intermediate"),
                    "cognitive_load": task.get("cognitive_load", "Moderate"),
                    "ease_factor": float(task.get("ease_factor", 2.5)),
                    "completed": False,
                    "completed_at": None,
                    "payload": payload
                })

            processed_days.append({
                "day_number": day.get("day_number", 1),
                "title": day.get("title", f"Day {day.get('day_number', 1)} Plan"),
                "estimated_minutes": day.get("estimated_minutes", total_daily_minutes),
                "topics_covered": day.get("topics_covered", []),
                "focus_objective": day.get("focus_objective", ""),
                "tasks": day_tasks
            })

        plan_id = str(uuid.uuid4())
        plan_doc = {
            "id": plan_id,
            "user_email": email,
            "title": parsed_data.get("roadmap_title", f"Active Roadmap: {', '.join(notebook_titles)} ({total_sources_count} Topics)"),
            "notebook_ids": notebook_ids,
            "notebook_titles": notebook_titles,
            "duration_option": f"{target_days} Days" if duration_option == 'AI Automated' else duration_option,
            "daily_hours": daily_hours,
            "sm2_enabled": True,
            "total_tasks": total_tasks_count,
            "total_topics_count": total_sources_count,
            "covered_sources": [{"title": s["source_title"], "notebook": s["notebook_title"]} for s in collected_sources],
            "completed_tasks": 0,
            "progress_percentage": 0.0,
            "created_at": str(datetime.datetime.now()),
            "updated_at": str(datetime.datetime.now()),
            "days": processed_days
        }

        save_study_plan(plan_doc)
        if USING_MONGO: plan_doc.pop('_id', None)

        log_activity(email, "Created Active Roadmap", f"Plan ID {plan_id} created with {total_tasks_count} tasks covering {total_sources_count} topics")
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


@app.route('/get-study-plan-history', methods=['GET', 'POST'])
def get_study_plan_history_endpoint():
    data = request.json or {} if request.method == 'POST' else request.args
    email = data.get('email', 'guest')
    plans = get_user_study_plans(email)
    summaries = []
    for p in plans:
        if USING_MONGO: p.pop('_id', None)
        days = p.get('days', [])
        summaries.append({
            "id": p.get("id"),
            "title": p.get("title", "Study Roadmap"),
            "notebook_titles": p.get("notebook_titles", []),
            "duration_option": p.get("duration_option", "Custom"),
            "daily_hours": p.get("daily_hours", 2.0),
            "total_tasks": p.get("total_tasks", 0),
            "total_topics_count": p.get("total_topics_count", len(p.get("covered_sources", []))),
            "completed_tasks": p.get("completed_tasks", 0),
            "progress_percentage": p.get("progress_percentage", 0.0),
            "created_at": p.get("created_at", ""),
            "updated_at": p.get("updated_at", ""),
            "days_count": len(days)
        })
    return jsonify({"history": summaries})


@app.route('/delete-study-plan', methods=['POST', 'DELETE'])
def delete_study_plan_endpoint():
    data = request.json or {}
    plan_id = data.get('plan_id')
    email = data.get('email', 'guest')
    if not plan_id:
        return jsonify({"error": "plan_id is required"}), 400
    delete_study_plan(plan_id, email)
    return jsonify({"success": True, "message": "Study plan deleted successfully."})


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
    port = int(os.environ.get("PORT", 5000))
    debug_mode = os.environ.get("FLASK_DEBUG", "True").lower() in ("true", "1")
    app.run(host='0.0.0.0', port=port, debug=debug_mode, use_reloader=False)
