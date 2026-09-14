import io
import os
import re
import json
import base64
import urllib.parse
import datetime
import requests
from flask import Blueprint, request, jsonify, Response
import google.generativeai as genai
from database.connection import get_timetables_col, memory_timetables, save_memory_timetables
import pytz
from ics import Calendar, Event

# Load API secrets / key if available
try:
    from api_secrets import GEMINI_API_KEY
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)
except Exception:
    pass

timetable_bp = Blueprint("timetable", __name__)

DAY_MAP = {
    "mon": 0, "monday": 0,
    "tue": 1, "tues": 1, "tuesday": 1,
    "wed": 2, "wednesday": 2,
    "thu": 3, "thur": 3, "thurs": 3, "thursday": 3,
    "fri": 4, "friday": 4,
    "sat": 5, "saturday": 5,
    "sun": 6, "sunday": 6
}

DAY_NORMALIZED = {
    0: "Mon", 1: "Tue", 2: "Wed", 3: "Thu", 4: "Fri", 5: "Sat", 6: "Sun"
}

def normalize_time_str(time_str):
    """Normalize time strings like '2:00 PM', '14:00', '08:00 AM' into 'HH:MM' (24-hour)."""
    if not time_str:
        return "09:00"
    time_str = time_str.strip()
    
    # Check 12-hour format with AM/PM
    match_12 = re.match(r"^(\d{1,2}):(\d{2})\s*(AM|PM)$", time_str, re.IGNORECASE)
    if match_12:
        hour = int(match_12.group(1))
        minute = int(match_12.group(2))
        period = match_12.group(3).upper()
        if period == "PM" and hour < 12:
            hour += 12
        elif period == "AM" and hour == 12:
            hour = 0
        return f"{hour:02d}:{minute:02d}"
    
    # Check 24-hour format
    match_24 = re.match(r"^(\d{1,2}):(\d{2})$", time_str)
    if match_24:
        hour = int(match_24.group(1))
        minute = int(match_24.group(2))
        return f"{hour:02d}:{minute:02d}"
    
    return time_str

def parse_timetable_with_gemini(image_bytes, mime_type="image/png"):
    """Uses Gemini Multimodal API to parse a university timetable image into structured JSON."""
    prompt = """
You are an expert OCR and schedule parser for university timetables.
Analyze the provided university timetable image carefully. University timetables typically have a weekly visual grid at the top and a structured summary table at the bottom.

Extract all scheduled course sessions. Focus especially on the course table (with columns like No, Unit, Description, Type, Class Group, Day, Time, Venue/Location).

For each course, extract:
- course_id: The course code / unit code (e.g., "UCCD1024", "UCCB1013", "UCCD3084").
- course_name: The full descriptive course name (e.g., "DATA STRUCTURE AND ALGORITHMIC PROBLEM SOLVING").
- classes: A list of all class sessions for this course, where each class has:
    - type: One of "L" (Lecture), "P" (Practical / Lab), "T" (Tutorial).
    - day: "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", or "Sun".
    - start_time: 24-hour format "HH:MM" (e.g., "14:00", "08:00").
    - end_time: 24-hour format "HH:MM" (e.g., "15:00", "10:00").
    - venue: Classroom / lab / lecture hall if visible (e.g., "LDK3", "N008B"), or empty string if not found.
    - group: Class group number or identifier (e.g., "1", "2", "7") or empty string.

Return ONLY a valid JSON object matching this exact schema, with no markdown fences, no explanatory text, and no backticks:
{
  "semester_start_date": "2026-09-07",
  "courses": [
    {
      "course_id": "UCCD1024",
      "course_name": "DATA STRUCTURE AND ALGORITHMIC PROBLEM SOLVING",
      "classes": [
        {
          "type": "L",
          "day": "Mon",
          "start_time": "14:00",
          "end_time": "15:00",
          "venue": "LDK3",
          "group": "1"
        },
        {
          "type": "L",
          "day": "Tue",
          "start_time": "08:00",
          "end_time": "10:00",
          "venue": "LDK3",
          "group": "1"
        },
        {
          "type": "P",
          "day": "Wed",
          "start_time": "08:00",
          "end_time": "10:00",
          "venue": "N008B",
          "group": "2"
        }
      ]
    }
  ]
}
"""

    models_to_try = [
        'gemini-3.7-flash',
        'gemini-3.5-flash-lite',
        'gemini-2.5-flash',
        'gemini-3.1-pro',
        'gemini-3-flash'
    ]

    # Convert to PIL Image for maximum compatibility with Gemini Vision
    pil_img = None
    try:
        import PIL.Image
        pil_img = PIL.Image.open(io.BytesIO(image_bytes))
    except Exception as img_err:
        print(f"⚠️ [TimetableOCR] PIL.Image.open failed: {img_err}")

    content_inputs = [prompt, pil_img] if pil_img is not None else [prompt, {"mime_type": mime_type, "data": image_bytes}]

    raw_response = None
    last_err = None
    for model_name in models_to_try:
        try:
            model = genai.GenerativeModel(model_name)
            resp = model.generate_content(content_inputs)
            if resp and resp.text:
                raw_response = resp.text
                print(f"✅ [TimetableOCR] Gemini response received via {model_name}")
                break
        except Exception as e:
            last_err = e
            print(f"⚠️ [TimetableOCR] Model {model_name} failed: {e}")
            continue

    if not raw_response:
        raise ValueError(f"Failed to get response from Gemini Vision API ({last_err}). Please check your Gemini API key in backend/api_secrets.py.")

    # Clean JSON
    cleaned = raw_response.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()

    try:
        data = json.loads(cleaned)
    except Exception as e:
        json_match = re.search(r"\{[\s\S]*\}", cleaned)
        if json_match:
            data = json.loads(json_match.group(0))
        else:
            raise ValueError(f"Could not parse Gemini OCR output as JSON: {e}\nRaw: {raw_response[:300]}")

    # Validate and normalize parsed courses
    courses = data.get("courses", [])
    normalized_courses = []
    for c in courses:
        cid = str(c.get("course_id", "")).strip().upper()
        cname = str(c.get("course_name", "")).strip()
        if not cid:
            continue
        classes = []
        for cl in c.get("classes", []):
            raw_day = str(cl.get("day", "Mon")).strip().lower()
            day_idx = DAY_MAP.get(raw_day, 0)
            norm_day = DAY_NORMALIZED.get(day_idx, "Mon")
            
            raw_type = str(cl.get("type", "L")).strip().upper()
            if raw_type not in ["L", "P", "T"]:
                raw_type = "L" if "LEC" in raw_type else ("P" if "PRAC" in raw_type or "LAB" in raw_type else "T")

            start_t = normalize_time_str(str(cl.get("start_time", "09:00")))
            end_t = normalize_time_str(str(cl.get("end_time", "11:00")))
            venue = str(cl.get("venue", "")).strip()
            group = str(cl.get("group", "")).strip()

            classes.append({
                "type": raw_type,
                "day": norm_day,
                "start_time": start_t,
                "end_time": end_t,
                "venue": venue,
                "group": group
            })

        normalized_courses.append({
            "course_id": cid,
            "course_name": cname or cid,
            "classes": classes
        })

    return {
        "semester_start_date": data.get("semester_start_date", datetime.date.today().isoformat()),
        "courses": normalized_courses
    }

@timetable_bp.route("/api/timetable/upload", methods=["POST"])
def upload_timetable():
    """Accepts image upload, parses using Gemini Vision, and saves result in user_timetables."""
    user_email = request.form.get("user_email", "").strip()
    if not user_email:
        return jsonify({"success": False, "error": "user_email is required"}), 400

    if "image" not in request.files and "file" not in request.files:
        return jsonify({"success": False, "error": "Image file is required"}), 400

    file = request.files.get("image") or request.files.get("file")
    if file.filename == "":
        return jsonify({"success": False, "error": "No file selected"}), 400

    mime_type = file.mimetype or "image/png"
    image_bytes = file.read()

    try:
        parsed_result = parse_timetable_with_gemini(image_bytes, mime_type=mime_type)
    except Exception as e:
        print(f"❌ [TimetableOCR Error] {e}")
        return jsonify({"success": False, "error": f"OCR parsing error: {str(e)}"}), 500

    semester_start_date = request.form.get("semester_start_date") or parsed_result.get("semester_start_date")
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()

    doc = {
        "user_email": user_email,
        "semester_start_date": semester_start_date,
        "courses": parsed_result.get("courses", []),
        "created_at": now_iso,
        "updated_at": now_iso
    }

    # Save to MongoDB or local storage
    col = get_timetables_col()
    if col is not None:
        try:
            col.update_one(
                {"user_email": user_email},
                {"$set": doc},
                upsert=True
            )
            print(f"✅ [Timetable] Upserted timetable in MongoDB for {user_email}")
        except Exception as e:
            print(f"⚠️ [Timetable] MongoDB upsert failed: {e}")
            memory_timetables[user_email] = doc
            save_memory_timetables()
    else:
        memory_timetables[user_email] = doc
        save_memory_timetables()
        print(f"✅ [Timetable] Saved timetable in memory for {user_email}")

    # Remove internal _id for JSON response if present
    response_doc = dict(doc)
    response_doc.pop("_id", None)

    return jsonify({
        "success": True,
        "message": f"Successfully parsed {len(doc['courses'])} courses from timetable.",
        "timetable": response_doc
    }), 200

@timetable_bp.route("/api/timetable", methods=["GET"])
def get_user_timetable():
    """Retrieve saved timetable for a user."""
    user_email = request.args.get("user_email", "").strip()
    if not user_email:
        return jsonify({"success": False, "error": "user_email parameter is required"}), 400

    col = get_timetables_col()
    doc = None
    if col is not None:
        try:
            doc = col.find_one({"user_email": user_email})
            if doc and "_id" in doc:
                doc["_id"] = str(doc["_id"])
        except Exception as e:
            print(f"⚠️ [Timetable] MongoDB find error: {e}")

    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    if not doc:
        return jsonify({
            "success": True,
            "timetable": None,
            "courses": []
        }), 200

    return jsonify({
        "success": True,
        "timetable": doc,
        "courses": doc.get("courses", [])
    }), 200

@timetable_bp.route("/api/timetable/export-ics", methods=["POST"])
def export_ics():
    """Generates a downloadable .ics calendar file for selected courses over 14 weeks."""
    data = request.get_json(silent=True) or request.form
    user_email = data.get("user_email", "").strip()
    selected_course_ids = data.get("course_ids", [])
    if isinstance(selected_course_ids, str):
        try:
            selected_course_ids = json.loads(selected_course_ids)
        except Exception:
            selected_course_ids = [c.strip() for c in selected_course_ids.split(",") if c.strip()]

    semester_start_date = data.get("semester_start_date")
    courses = data.get("courses")
    return export_ics_logic(
        user_email=user_email,
        selected_course_ids=selected_course_ids,
        semester_start_date=semester_start_date,
        courses_override=courses
    )

@timetable_bp.route("/api/timetable/download-ics", methods=["GET"])
def download_ics_get():
    """Direct GET endpoint to trigger browser download for .ics calendar."""
    user_email = request.args.get("user_email", "").strip()
    raw_course_ids = request.args.get("course_ids", "")
    course_ids = [c.strip() for c in raw_course_ids.split(",") if c.strip()] if raw_course_ids else []
    
    # Delegate to export_ics logic
    return export_ics_logic(user_email=user_email, selected_course_ids=course_ids)

def get_user_google_tokens_col():
    try:
        from app import mongo
        return mongo.db.user_google_tokens
    except Exception:
        return None

def push_timetable_to_google_calendar(access_token, refresh_token=None, courses=[], sem_monday=None):
    """Inserts sub-calendar and pushes 14-week recurring classes with distinct color IDs to Google Calendar."""
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    import googleapiclient.discovery
    from config import GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET

    creds = Credentials(
        token=access_token,
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=GOOGLE_CLIENT_ID,
        client_secret=GOOGLE_CLIENT_SECRET,
        scopes=["https://www.googleapis.com/auth/calendar"]
    )

    try:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
    except Exception as ref_err:
        print(f"⚠️ [Google Token Refresh] {ref_err}")

    service = googleapiclient.discovery.build('calendar', 'v3', credentials=creds)
    cal_title = f"UTAR Timetable ({sem_monday.strftime('%b %Y')})"
    target_cal_id = None

    try:
        cal_list = service.calendarList().list().execute()
        for item in cal_list.get('items', []):
            if item.get('summary') == cal_title:
                target_cal_id = item.get('id')
                break
    except Exception as e:
        print(f"⚠️ [Google CalendarList] {e}")

    if not target_cal_id:
        try:
            new_cal = service.calendars().insert(body={
                'summary': cal_title,
                'description': f'University semester timetable synced automatically by Note2Quiz (Starting {sem_monday.strftime("%d %b %Y")})',
                'timeZone': 'Asia/Kuala_Lumpur'
            }).execute()
            target_cal_id = new_cal.get('id')
        except Exception as create_err:
            print(f"⚠️ [Google Calendar Create] {create_err}")
            target_cal_id = "primary"

    calendar_id = target_cal_id or "primary"
    kl_tz = pytz.timezone("Asia/Kuala_Lumpur")
    GOOGLE_COLOR_PALETTE = ["9", "10", "3", "6", "4", "7", "11", "1"]
    synced_events_count = 0

    for course_idx, course in enumerate(courses):
        cid = course.get("course_id", "COURSE")
        cname = course.get("course_name", "")
        course_color = GOOGLE_COLOR_PALETTE[course_idx % len(GOOGLE_COLOR_PALETTE)]

        for cl in course.get("classes", []):
            ctype = cl.get("type", "L")
            type_name = "Lecture" if ctype == "L" else ("Practical/Lab" if ctype == "P" else "Tutorial")
            day_str = cl.get("day", "Mon").lower()
            day_offset = DAY_MAP.get(day_str, 0)
            class_date = sem_monday + datetime.timedelta(days=day_offset)

            start_time_str = cl.get("start_time", "09:00")
            end_time_str = cl.get("end_time", "11:00")
            venue = cl.get("venue", "")
            group = cl.get("group", "")

            try:
                s_h, s_m = map(int, start_time_str.split(":"))
                e_h, e_m = map(int, end_time_str.split(":"))

                start_dt = kl_tz.localize(datetime.datetime(class_date.year, class_date.month, class_date.day, s_h, s_m))
                end_dt = kl_tz.localize(datetime.datetime(class_date.year, class_date.month, class_date.day, e_h, e_m))

                event_body = {
                    'summary': f"{cid} ({ctype}) - {cname}",
                    'location': venue,
                    'description': f"Course: {cname} ({cid})\nType: {type_name}\nGroup: {group}\nSynced automatically from Note2Quiz (14-Week Schedule)",
                    'start': {
                        'dateTime': start_dt.isoformat(),
                        'timeZone': 'Asia/Kuala_Lumpur'
                    },
                    'end': {
                        'dateTime': end_dt.isoformat(),
                        'timeZone': 'Asia/Kuala_Lumpur'
                    },
                    'recurrence': [
                        'RRULE:FREQ=WEEKLY;COUNT=14'
                    ],
                    'colorId': course_color
                }

                service.events().insert(calendarId=calendar_id, body=event_body).execute()
                synced_events_count += 1
            except Exception as ev_err:
                print(f"⚠️ [Google Event Insert] Error inserting class: {ev_err}")

    return {
        "calendar_title": cal_title,
        "calendar_id": calendar_id,
        "events_count": synced_events_count
    }

@timetable_bp.route("/api/timetable/google-oauth-url", methods=["GET"])
def get_google_oauth_url():
    """Generates direct Google OAuth 2.0 authorization URL for user to grant Google Calendar permission."""
    user_email = request.args.get("user_email", "").strip()
    sem_start = request.args.get("semester_start_date", "")
    course_ids = request.args.get("course_ids", "")

    from config import GOOGLE_CLIENT_ID
    if not GOOGLE_CLIENT_ID:
        return jsonify({
            "configured": False,
            "error": "Google OAuth is not configured with a GOOGLE_CLIENT_ID."
        }), 200

    host = request.host
    # Prefer localhost if running locally
    if host.startswith("127.0.0.1"):
        host = host.replace("127.0.0.1", "localhost")
    redirect_uri = f"{request.scheme}://{host}/api/timetable/google-oauth-callback"
    state_data = {
        "user_email": user_email,
        "semester_start_date": sem_start,
        "course_ids": course_ids,
    }
    state = base64.urlsafe_b64encode(json.dumps(state_data).encode()).decode()

    scopes = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.email"
    auth_url = (
        f"https://accounts.google.com/o/oauth2/v2/auth?"
        f"client_id={GOOGLE_CLIENT_ID}&"
        f"redirect_uri={urllib.parse.quote(redirect_uri)}&"
        f"response_type=code&"
        f"scope={urllib.parse.quote(scopes)}&"
        f"access_type=offline&"
        f"prompt=consent&"
        f"state={state}"
    )

    return jsonify({
        "configured": True,
        "oauth_url": auth_url
    }), 200

@timetable_bp.route("/api/timetable/google-oauth-callback", methods=["GET"])
def google_oauth_callback():
    """Handles Google OAuth redirect, exchanges authorization code for tokens, and pushes timetable events."""
    code = request.args.get("code")
    state_str = request.args.get("state")
    error = request.args.get("error")

    if error or not code:
        return f"""
        <html><body style="font-family:sans-serif;text-align:center;padding:40px;background:#0d1117;color:#fff;">
        <h2>Google Authentication Cancelled</h2>
        <p>{error or 'No authorization code received.'}</p>
        </body></html>
        """, 400

    from config import GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
    redirect_uri = f"{request.scheme}://{request.host}/api/timetable/google-oauth-callback"

    # Exchange authorization code for token
    token_url = "https://oauth2.googleapis.com/token"
    token_payload = {
        "code": code,
        "client_id": GOOGLE_CLIENT_ID,
        "client_secret": GOOGLE_CLIENT_SECRET,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
    }
    token_resp = requests.post(token_url, data=token_payload)
    if token_resp.status_code != 200:
        return f"""
        <html><body style="font-family:sans-serif;text-align:center;padding:40px;background:#0d1117;color:#fff;">
        <h2>Failed to exchange OAuth token</h2>
        <p>{token_resp.text}</p>
        </body></html>
        """, 400

    tokens = token_resp.json()
    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")

    # Decode state
    state_data = {}
    if state_str:
        try:
            state_data = json.loads(base64.urlsafe_b64decode(state_str.encode()).decode())
        except Exception:
            pass

    user_email = state_data.get("user_email", "")
    sem_start_str = state_data.get("semester_start_date")
    course_ids_str = state_data.get("course_ids", "")
    course_ids = [c.strip() for c in course_ids_str.split(",") if c.strip()] if course_ids_str else []

    # Store token in MongoDB for future automatic 1-click sync
    tok_col = get_user_google_tokens_col()
    if tok_col is not None and user_email:
        tok_col.update_one(
            {"user_email": user_email},
            {"$set": {
                "user_email": user_email,
                "access_token": access_token,
                "refresh_token": refresh_token,
                "updated_at": datetime.datetime.now(datetime.timezone.utc)
            }},
            upsert=True
        )

    # Fetch user's courses
    doc = None
    col = get_timetables_col()
    if col is not None and user_email:
        doc = col.find_one({"user_email": {"$regex": f"^{re.escape(user_email)}$", "$options": "i"}})
    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    courses = doc.get("courses", []) if doc else []
    if course_ids:
        c_set = {cid.upper() for cid in course_ids}
        courses = [c for c in courses if c.get("course_id", "").upper() in c_set]

    # Parse semester date
    if sem_start_str:
        try:
            sem_start = datetime.datetime.strptime(sem_start_str[:10], "%Y-%m-%d").date()
        except Exception:
            sem_start = datetime.date.today()
    else:
        sem_start = datetime.date.today()

    sem_monday = sem_start - datetime.timedelta(days=sem_start.weekday())

    push_result = push_timetable_to_google_calendar(
        access_token=access_token,
        refresh_token=refresh_token,
        courses=courses,
        sem_monday=sem_monday
    )

    events_count = push_result.get("events_count", 0)
    cal_title = push_result.get("calendar_title", "UTAR Timetable")

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Google Calendar Synced</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&display=swap" rel="stylesheet">
        <style>
            body {{
                font-family: 'Outfit', sans-serif;
                background: #0B0E14;
                color: #FFFFFF;
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
                margin: 0;
            }}
            .card {{
                background: #151A23;
                border: 1px solid rgba(255,255,255,0.1);
                border-radius: 24px;
                padding: 40px 32px;
                max-width: 480px;
                width: 90%;
                text-align: center;
                box-shadow: 0 20px 40px rgba(0,0,0,0.6);
            }}
            .icon-badge {{
                width: 72px;
                height: 72px;
                background: rgba(26, 115, 232, 0.15);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 20px;
                font-size: 36px;
            }}
            h2 {{ margin: 0 0 10px; font-size: 24px; color: #FFFFFF; }}
            p {{ color: #94A3B8; font-size: 15px; line-height: 1.6; margin: 0 0 24px; }}
            .highlight {{ color: #60A5FA; font-weight: 600; }}
            .btn {{
                display: inline-flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                background: #1A73E8;
                color: white;
                padding: 14px 28px;
                border-radius: 14px;
                text-decoration: none;
                font-weight: 600;
                font-size: 15px;
                box-shadow: 0 4px 14px rgba(26, 115, 232, 0.4);
                transition: transform 0.2s, background 0.2s;
            }}
            .btn:hover {{ background: #1557B0; transform: translateY(-2px); }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon-badge">📅</div>
            <h2>Google Calendar Synced!</h2>
            <p>
                Successfully created <span class="highlight">{cal_title}</span> with <span class="highlight">{len(courses)} courses</span> ({events_count} weekly recurring sessions) across your entire 14-week semester.
            </p>
            <a href="https://calendar.google.com" target="_blank" class="btn">
                Open Google Calendar ↗
            </a>
            <script>
                if (window.opener) {{
                    window.opener.postMessage({{"type": "GOOGLE_SYNC_SUCCESS"}}, "*");
                }}
            </script>
        </div>
    </body>
    </html>
    """, 200

@timetable_bp.route("/api/timetable/sync-google-calendar", methods=["POST"])
def sync_google_calendar():
    """Directly pushes 14-week university timetable to user's Google Calendar with distinct course colors."""
    data = request.get_json(silent=True) or request.form
    user_email = data.get("user_email", "").strip()
    access_token = data.get("access_token", "").strip()
    selected_course_ids = data.get("course_ids", [])
    if isinstance(selected_course_ids, str):
        try:
            selected_course_ids = json.loads(selected_course_ids)
        except Exception:
            selected_course_ids = [c.strip() for c in selected_course_ids.split(",") if c.strip()]

    # Fetch user's timetable
    doc = None
    col = get_timetables_col()
    if col is not None and user_email:
        try:
            doc = col.find_one({"user_email": {"$regex": f"^{re.escape(user_email)}$", "$options": "i"}})
        except Exception:
            pass

    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    courses = data.get("courses") or (doc.get("courses", []) if doc else [])
    if not courses:
        return jsonify({"success": False, "error": "No timetable data found to sync."}), 400

    if selected_course_ids:
        selected_set = {str(cid).upper() for cid in selected_course_ids}
        courses = [c for c in courses if c.get("course_id", "").upper() in selected_set]

    if not courses:
        return jsonify({"success": False, "error": "No matching courses selected for Google Calendar sync."}), 400

    # Determine semester start date
    start_date_str = data.get("semester_start_date") or (doc.get("semester_start_date") if doc else None)
    if start_date_str:
        try:
            sem_start = datetime.datetime.fromisoformat(start_date_str.replace("Z", "+00:00")).date()
        except Exception:
            try:
                sem_start = datetime.datetime.strptime(start_date_str[:10], "%Y-%m-%d").date()
            except Exception:
                sem_start = datetime.date.today()
    else:
        sem_start = datetime.date.today()

    # Align sem_start to Monday
    sem_monday = sem_start - datetime.timedelta(days=sem_start.weekday())

    # Check for stored OAuth tokens in DB
    refresh_token = None
    if not access_token:
        tok_col = get_user_google_tokens_col()
        if tok_col is not None and user_email:
            tok_doc = tok_col.find_one({"user_email": user_email})
            if tok_doc:
                access_token = tok_doc.get("access_token")
                refresh_token = tok_doc.get("refresh_token")

    from config import GOOGLE_CLIENT_ID
    if not access_token and not refresh_token:
        if GOOGLE_CLIENT_ID:
            # Return OAuth URL for 1-click authorization
            host = request.host
            if host.startswith("127.0.0.1"):
                host = host.replace("127.0.0.1", "localhost")
            redirect_uri = f"{request.scheme}://{host}/api/timetable/google-oauth-callback"
            state_data = {
                "user_email": user_email,
                "semester_start_date": start_date_str or sem_monday.isoformat(),
                "course_ids": ",".join(selected_course_ids),
            }
            state = base64.urlsafe_b64encode(json.dumps(state_data).encode()).decode()
            scopes = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.email"
            auth_url = (
                f"https://accounts.google.com/o/oauth2/v2/auth?"
                f"client_id={GOOGLE_CLIENT_ID}&"
                f"redirect_uri={urllib.parse.quote(redirect_uri)}&"
                f"response_type=code&"
                f"scope={urllib.parse.quote(scopes)}&"
                f"access_type=offline&"
                f"prompt=consent&"
                f"state={state}"
            )
            return jsonify({
                "success": True,
                "requires_oauth": True,
                "oauth_url": auth_url
            }), 200
        else:
            return jsonify({
                "success": False,
                "needs_client_id": True,
                "error": "Google OAuth is not configured yet. Please add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET to backend/api_secrets.py."
            }), 200

    # We have tokens! Push directly to Google Calendar API
    try:
        push_result = push_timetable_to_google_calendar(
            access_token=access_token,
            refresh_token=refresh_token,
            courses=courses,
            sem_monday=sem_monday
        )
        return jsonify({
            "success": True,
            "requires_oauth": False,
            "message": f"Successfully synced {len(courses)} course(s) to Google Calendar.",
            "calendar_title": push_result.get("calendar_title"),
            "calendar_id": push_result.get("calendar_id"),
            "events_count": push_result.get("events_count", 0),
            "courses_count": len(courses),
            "semester_start_monday": sem_monday.isoformat()
        }), 200
    except Exception as push_err:
        print(f"❌ [Google Calendar Sync Error] {push_err}")
        return jsonify({
            "success": False,
            "error": f"Failed to sync to Google Calendar: {str(push_err)}"
        }), 500

@timetable_bp.route("/api/timetable/auto-create-notebooks", methods=["POST"])
def auto_create_notebooks():
    """Automatically creates dedicated notebooks for each selected course from timetable."""
    import uuid
    from database.connection import get_db, BASE_DIR
    
    data = request.get_json(silent=True) or request.form
    user_email = data.get("user_email", "").strip()
    if not user_email:
        return jsonify({"success": False, "error": "user_email is required"}), 400

    selected_course_ids = data.get("course_ids", [])
    if isinstance(selected_course_ids, str):
        try:
            selected_course_ids = json.loads(selected_course_ids)
        except Exception:
            selected_course_ids = [c.strip() for c in selected_course_ids.split(",") if c.strip()]

    # Fetch user's timetable courses
    col = get_timetables_col()
    doc = None
    if col is not None:
        try:
            doc = col.find_one({"user_email": user_email})
        except Exception:
            pass

    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    if not doc or not doc.get("courses"):
        return jsonify({"success": False, "error": "No timetable courses found for user."}), 404

    courses = doc.get("courses", [])
    if selected_course_ids:
        selected_set = {str(cid).upper() for cid in selected_course_ids}
        courses = [c for c in courses if c.get("course_id", "").upper() in selected_set]

    if not courses:
        return jsonify({"success": False, "error": "No matching courses selected."}), 400

    # Get DB connection or local JSON
    db, is_mongo = get_db()
    notebooks_file = os.path.join(BASE_DIR, "data_storage", "notebooks.json")

    def _load_notebooks():
        if is_mongo and db is not None:
            return list(db["notebooks"].find({"user_email": {"$regex": f"^{re.escape(user_email)}$", "$options": "i"}}))
        if os.path.exists(notebooks_file):
            try:
                with open(notebooks_file, "r", encoding="utf-8") as f:
                    all_nbs = json.load(f)
                    return [n for n in all_nbs if n.get("user_email", "").lower() == user_email.lower()]
            except Exception:
                pass
        return []

    existing_nbs = _load_notebooks()
    existing_titles = {n.get("title", "").strip().upper() for n in existing_nbs}
    
    created_list = []
    skipped_list = []

    for course in courses:
        cid = course.get("course_id", "").strip().upper()
        cname = course.get("course_name", "").strip()
        title = f"{cid} - {cname}"

        # Check if already exists
        if title.upper() in existing_titles or any(cid in t for t in existing_titles):
            skipped_list.append(title)
            continue

        new_nb = {
            "id": str(uuid.uuid4()),
            "user_email": user_email,
            "title": title,
            "sources": [],
            "created_at": str(datetime.datetime.now())
        }

        if is_mongo and db is not None:
            try:
                db["notebooks"].insert_one(dict(new_nb))
            except Exception as e:
                print(f"⚠️ [AutoCreateNotebooks] Mongo insert error: {e}")
        else:
            try:
                all_nbs = []
                if os.path.exists(notebooks_file):
                    with open(notebooks_file, "r", encoding="utf-8") as f:
                        all_nbs = json.load(f)
                all_nbs.append(new_nb)
                with open(notebooks_file, "w", encoding="utf-8") as f:
                    json.dump(all_nbs, f, ensure_ascii=False, indent=2)
            except Exception as e:
                print(f"⚠️ [AutoCreateNotebooks] File save error: {e}")

        # Clean _id for json response if mongo added it
        new_nb.pop("_id", None)
        created_list.append(new_nb)
        existing_titles.add(title.upper())

    return jsonify({
        "success": True,
        "message": f"Successfully created {len(created_list)} notebook(s)." + (f" ({len(skipped_list)} already existed)" if skipped_list else ""),
        "created_count": len(created_list),
        "created_notebooks": created_list,
        "skipped_notebooks": skipped_list
    }), 200

def export_ics_logic(user_email, selected_course_ids=None, semester_start_date=None, courses_override=None):
    # Fetch user's timetable
    doc = None
    col = get_timetables_col()
    if col is not None:
        try:
            doc = col.find_one({"user_email": user_email})
        except Exception:
            pass

    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    courses = courses_override or (doc.get("courses", []) if doc else [])
    if not courses:
        return jsonify({"success": False, "error": "No timetable data found to export."}), 400

    if selected_course_ids:
        selected_set = {str(cid).upper() for cid in selected_course_ids}
        courses = [c for c in courses if c.get("course_id", "").upper() in selected_set]

    if not courses:
        return jsonify({"success": False, "error": "No matching courses found for export."}), 400

    start_date_str = semester_start_date or (doc.get("semester_start_date") if doc else None)
    if start_date_str:
        try:
            sem_start = datetime.datetime.fromisoformat(start_date_str.replace("Z", "+00:00")).date()
        except Exception:
            try:
                sem_start = datetime.datetime.strptime(start_date_str[:10], "%Y-%m-%d").date()
            except Exception:
                sem_start = datetime.date.today()
    else:
        sem_start = datetime.date.today()

    sem_monday = sem_start - datetime.timedelta(days=sem_start.weekday())
    cal = Calendar()
    kl_tz = pytz.timezone("Asia/Kuala_Lumpur")

    for week_num in range(1, 15):
        week_monday = sem_monday + datetime.timedelta(weeks=week_num - 1)
        for course in courses:
            cid = course.get("course_id", "COURSE")
            cname = course.get("course_name", "")
            for cl in course.get("classes", []):
                ctype = cl.get("type", "L")
                type_name = "Lecture" if ctype == "L" else ("Practical/Lab" if ctype == "P" else "Tutorial")
                day_str = cl.get("day", "Mon").lower()
                day_offset = DAY_MAP.get(day_str, 0)
                class_date = week_monday + datetime.timedelta(days=day_offset)

                start_time_str = cl.get("start_time", "09:00")
                end_time_str = cl.get("end_time", "11:00")
                venue = cl.get("venue", "")
                group = cl.get("group", "")

                try:
                    s_h, s_m = map(int, start_time_str.split(":"))
                    e_h, e_m = map(int, end_time_str.split(":"))

                    start_dt = kl_tz.localize(datetime.datetime(class_date.year, class_date.month, class_date.day, s_h, s_m))
                    end_dt = kl_tz.localize(datetime.datetime(class_date.year, class_date.month, class_date.day, e_h, e_m))

                    event = Event()
                    event.name = f"{cid} ({ctype}) - {cname}"
                    event.begin = start_dt
                    event.end = end_dt
                    if venue:
                        event.location = venue
                    event.description = f"Course: {cname} ({cid})\nType: {type_name}\nGroup: {group}\nWeek {week_num}/14"
                    cal.events.add(event)
                except Exception as ev_err:
                    print(f"⚠️ [ICS Export] Event error: {ev_err}")

    ics_output = cal.serialize()
    filename = f"semester_timetable_{user_email.split('@')[0]}.ics"

    return Response(
        ics_output,
        mimetype="text/calendar",
        headers={
            "Content-Disposition": f"attachment; filename={filename}",
            "Content-Type": "text/calendar; charset=utf-8"
        }
    )

def get_course_lecture_timing(user_email, course_id):
    """
    Looks up a course in user_timetables and finds the last Lecture (L) session of the week.
    Returns dict with course details, class_day, class_start_time, class_end_time, etc.
    """
    col = get_timetables_col()
    doc = None
    if col is not None:
        try:
            doc = col.find_one({"user_email": user_email})
        except Exception:
            pass

    if not doc and user_email in memory_timetables:
        doc = memory_timetables[user_email]

    if not doc:
        return None

    target_cid = course_id.strip().upper()
    matching_course = None
    for c in doc.get("courses", []):
        if c.get("course_id", "").strip().upper() == target_cid or target_cid in c.get("course_id", "").strip().upper():
            matching_course = c
            break

    if not matching_course:
        return None

    classes = matching_course.get("classes", [])
    if not classes:
        return None

    # Filter Lecture classes
    lectures = [cl for cl in classes if cl.get("type", "L").upper() == "L"]
    if not lectures:
        lectures = classes # fallback to whatever class exists

    # Sort by day of week then by start_time to get the last session
    def session_sort_key(cl):
        d = DAY_MAP.get(str(cl.get("day", "Mon")).lower(), 0)
        t = str(cl.get("start_time", "00:00"))
        return (d, t)

    lectures.sort(key=session_sort_key)
    last_lecture = lectures[-1]

    day_short = last_lecture.get("day", "Mon")
    day_idx = DAY_MAP.get(day_short.lower(), 0)
    full_day = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day_idx]

    return {
        "course_id": matching_course.get("course_id"),
        "course_name": matching_course.get("course_name"),
        "class_day": full_day,
        "class_start_time": last_lecture.get("start_time", "08:00"),
        "class_end_time": last_lecture.get("end_time", "10:00"),
        "venue": last_lecture.get("venue", ""),
        "all_classes": classes
    }
