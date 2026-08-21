import datetime
from flask import Blueprint, request, jsonify
from database.connection import get_db, memory_automations, save_memory_automations
from models.automation import validate_automation_request, build_automation_doc, calculate_progress_stats
from services.syllabus_parser import parse_syllabus_pdf
from utils.scheduler_utils import calculate_weekly_schedule
from services.calendar_service import sync_google_calendar

from blueprints.timetable import get_course_lecture_timing

automation_bp = Blueprint("automation", __name__)

@automation_bp.route("/api/automations", methods=["POST"])
def create_or_update_automation():
    form = request.form
    files = request.files
    user_email = form.get("user_email", "").strip()
    linked_course_id = form.get("linked_course_id", "").strip()

    course_timing = None
    if linked_course_id and user_email:
        course_timing = get_course_lecture_timing(user_email, linked_course_id)

    errors = validate_automation_request(form, files, from_timetable=bool(course_timing))
    if errors:
        return jsonify({"success": False, "errors": errors}), 400

    notebook_id = form["notebook_id"].strip()
    course_name = form.get("course_name", "").strip()
    if not course_name and course_timing:
        course_name = f"{course_timing['course_id']} - {course_timing['course_name']}"

    class_day = form.get("class_day", "").strip().capitalize()
    if not class_day and course_timing:
        class_day = course_timing["class_day"]

    class_start_time = form.get("class_start_time", "").strip()
    if not class_start_time and course_timing:
        class_start_time = course_timing["class_start_time"]

    class_end_time = form.get("class_end_time", "").strip()
    if not class_end_time and course_timing:
        class_end_time = course_timing["class_end_time"]

    semester_start_date = form.get("semester_start_date", "").strip() or datetime.date.today().isoformat()
    total_weeks = int(form.get("total_weeks", 14))
    has_break_week = form.get("has_break_week", "false").lower() in ["true", "1", "yes"]

    primary_reminder_time = form.get("primary_reminder_time", "18:00").strip()
    enable_evening_reminder = form.get("enable_evening_reminder", "true").lower() in ["true", "1", "yes"]
    evening_reminder_time = form.get("evening_reminder_time", "21:00").strip()

    # Read PDF bytes
    syllabus_file = files["syllabus"]
    pdf_bytes = syllabus_file.read()

    # 1. Parse syllabus with Gemini / Fallback
    weekly_topics, warnings, source = parse_syllabus_pdf(pdf_bytes, total_weeks, course_name, filename=syllabus_file.filename)

    # 2. Calculate semester schedule
    weekly_schedule = calculate_weekly_schedule(
        semester_start_date_str=semester_start_date,
        total_weeks=total_weeks,
        class_day=class_day,
        class_start_time_str=class_start_time,
        class_end_time_str=class_end_time,
        has_break_week=has_break_week,
        weekly_topics=weekly_topics,
        primary_reminder_time_str=primary_reminder_time,
        enable_evening_reminder=enable_evening_reminder,
        evening_reminder_time_str=evening_reminder_time
    )

    semester_config = {
        "start_date": semester_start_date,
        "total_weeks": total_weeks,
        "has_break_week": has_break_week
    }

    timetable = {
        "day_of_week": class_day,
        "class_start_time": class_start_time,
        "class_end_time": class_end_time,
        "linked_course_id": linked_course_id,
        "primary_reminder_time": primary_reminder_time,
        "enable_evening_reminder": enable_evening_reminder,
        "evening_reminder_time": evening_reminder_time
    }

    syllabus_meta = {
        "filename": syllabus_file.filename,
        "source": source,
        "parsed_at": datetime.datetime.now(datetime.timezone.utc)
    }

    # 3. Google Calendar synchronization (if token/credentials provided in auth header or config)
    oauth_token = request.headers.get("X-Google-OAuth-Token") or form.get("google_oauth_token")
    calendar_details, cal_warnings = sync_google_calendar(
        user_email=user_email,
        course_name=course_name,
        notebook_id=notebook_id,
        weekly_schedule=weekly_schedule,
        oauth_token=oauth_token
    )
    if cal_warnings:
        warnings.extend(cal_warnings)

    # 4. Build doc & persist in MongoDB / memory
    doc = build_automation_doc(
        notebook_id=notebook_id,
        user_email=user_email,
        course_name=course_name,
        timezone_str="Asia/Kuala_Lumpur",
        semester_config=semester_config,
        timetable=timetable,
        syllabus_meta=syllabus_meta,
        weekly_schedule=weekly_schedule,
        calendar_details=calendar_details
    )

    db, is_mongo = get_db()
    automation_id = f"auto_{notebook_id}"

    if is_mongo and db is not None:
        automations = db["course_automations"]
        res = automations.update_one(
            {"notebook_id": notebook_id, "course_name": course_name, "user_email": user_email},
            {"$set": doc},
            upsert=True
        )
        if res.upserted_id:
            automation_id = str(res.upserted_id)
    else:
        memory_key = f"{notebook_id}_{course_name}_{user_email}"
        doc["_id"] = memory_key
        memory_automations[memory_key] = doc
        automation_id = memory_key
        save_memory_automations()

    # Format output schedule timestamps for JSON response
    response_schedule = []
    for s in weekly_schedule:
        item_copy = dict(s)
        item_copy["class_start_timestamp"] = s["class_start_timestamp"].isoformat()
        item_copy["class_end_timestamp"] = s["class_end_timestamp"].isoformat()
        item_copy["revision_trigger_timestamp"] = s["revision_trigger_timestamp"].isoformat()
        response_schedule.append(item_copy)

    return jsonify({
        "success": True,
        "automation_id": automation_id,
        "notebook_id": notebook_id,
        "course_name": course_name,
        "total_weeks": doc.get("total_weeks", total_weeks),
        "completed_weeks_count": doc.get("completed_weeks_count", 0),
        "progress_percentage": doc.get("progress_percentage", 0.0),
        "next_scheduled_trigger": doc["next_scheduled_trigger"].isoformat() if doc.get("next_scheduled_trigger") else None,
        "syllabus_source": source,
        "warnings": warnings,
        "weekly_schedule": response_schedule
    }), 201

def _format_iso(dt):
    if not isinstance(dt, datetime.datetime):
        return dt
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.isoformat()

def _serialize_automation_doc(doc):
    if not doc:
        return doc
    doc_copy = dict(doc)
    if "_id" in doc_copy:
        doc_copy["_id"] = str(doc_copy["_id"])
    for key in ["created_at", "updated_at", "next_scheduled_trigger"]:
        if isinstance(doc_copy.get(key), datetime.datetime):
            doc_copy[key] = _format_iso(doc_copy[key])

    if "weekly_schedule" in doc_copy:
        formatted_schedule = []
        for s in doc_copy["weekly_schedule"]:
            s_copy = dict(s)
            for k in [
                "class_start_timestamp",
                "class_end_timestamp",
                "revision_trigger_timestamp",
                "actual_trigger_timestamp",
                "primary_trigger_timestamp",
                "evening_trigger_timestamp",
                "email_dispatched_at",
                "evening_dispatched_at",
                "notification_sent_at",
                "completed_at"
            ]:
                if isinstance(s_copy.get(k), datetime.datetime):
                    s_copy[k] = _format_iso(s_copy[k])

            if isinstance(s_copy.get("quiz_record"), dict):
                qr = dict(s_copy["quiz_record"])
                if isinstance(qr.get("completed_at"), datetime.datetime):
                    qr["completed_at"] = _format_iso(qr["completed_at"])
                s_copy["quiz_record"] = qr

            formatted_schedule.append(s_copy)
        doc_copy["weekly_schedule"] = formatted_schedule
    return doc_copy

@automation_bp.route("/api/automations", methods=["GET"])
def get_all_automations():
    user_email = request.args.get("user_email", "").strip()
    db, is_mongo = get_db()
    all_docs = []

    if is_mongo and db is not None:
        automations = db["course_automations"]
        query = {}
        if user_email:
            query = {"$or": [{"user_email": user_email}, {"user_email": "guest"}, {"user_email": ""}]}
        cursor = automations.find(query).sort("updated_at", -1)
        all_docs = list(cursor)
        if not all_docs and user_email:
            all_docs = list(automations.find().sort("updated_at", -1))
    else:
        for k, v in memory_automations.items():
            if not user_email or v.get("user_email") == user_email or v.get("user_email") == "guest":
                all_docs.append(v)
        if not all_docs:
            all_docs = list(memory_automations.values())

    serialized_all = []
    for d in all_docs:
        stats_d = calculate_progress_stats(d.get("weekly_schedule", []), d.get("total_weeks"))
        d["completed_weeks_count"] = stats_d["completed_weeks_count"]
        d["progress_percentage"] = stats_d["progress_percentage"]
        d["next_scheduled_trigger"] = stats_d["next_scheduled_trigger"]
        serialized_all.append(_serialize_automation_doc(d))

    return jsonify({
        "success": True,
        "total_automations": len(serialized_all),
        "automations": serialized_all
    }), 200

@automation_bp.route("/api/automations/<notebook_id>", methods=["GET"])
@automation_bp.route("/api/automations/<notebook_id>/history", methods=["GET"])
def get_automation_history(notebook_id):
    user_email = request.args.get("user_email", "").strip()
    course_name = request.args.get("course_name", "").strip()
    db, is_mongo = get_db()

    doc = None
    all_docs = []

    if is_mongo and db is not None:
        automations = db["course_automations"]
        query = {"notebook_id": notebook_id}
        if user_email:
            query["user_email"] = user_email
        if course_name:
            query["course_name"] = course_name

        cursor = automations.find(query).sort("updated_at", -1)
        all_docs = list(cursor)

        if not all_docs and (user_email or course_name):
            # Fallback without filters
            all_docs = list(automations.find({"notebook_id": notebook_id}).sort("updated_at", -1))

        if all_docs:
            doc = all_docs[0]
    else:
        for k, v in memory_automations.items():
            if v.get("notebook_id") == notebook_id:
                if (not user_email or v.get("user_email") == user_email) and (not course_name or v.get("course_name") == course_name):
                    all_docs.append(v)
        if not all_docs:
            for k, v in memory_automations.items():
                if v.get("notebook_id") == notebook_id:
                    all_docs.append(v)
        if all_docs:
            doc = all_docs[0]

    if not doc:
        return jsonify({"success": False, "message": "Automation record not found", "all_automations": []}), 404

    # Ensure stats are up to date for all records
    serialized_all = []
    for d in all_docs:
        stats_d = calculate_progress_stats(d.get("weekly_schedule", []), d.get("total_weeks"))
        d["completed_weeks_count"] = stats_d["completed_weeks_count"]
        d["progress_percentage"] = stats_d["progress_percentage"]
        d["next_scheduled_trigger"] = stats_d["next_scheduled_trigger"]
        serialized_all.append(_serialize_automation_doc(d))

    stats = calculate_progress_stats(doc.get("weekly_schedule", []), doc.get("total_weeks"))
    doc["completed_weeks_count"] = stats["completed_weeks_count"]
    doc["progress_percentage"] = stats["progress_percentage"]
    doc["next_scheduled_trigger"] = stats["next_scheduled_trigger"]

    serialized = _serialize_automation_doc(doc)
    return jsonify({
        "success": True,
        "automation": serialized,
        "all_automations": serialized_all,
        "history": serialized.get("weekly_schedule", []),
        "stats": {
            "total_weeks": serialized.get("total_weeks", 14),
            "completed_weeks_count": stats["completed_weeks_count"],
            "progress_percentage": stats["progress_percentage"],
            "next_scheduled_trigger": stats["next_scheduled_trigger"].isoformat() if stats["next_scheduled_trigger"] else None
        }
    }), 200

@automation_bp.route("/api/automations/<notebook_id>", methods=["DELETE"])
def delete_automation(notebook_id):
    user_email = request.args.get("user_email", "").strip()
    course_name = request.args.get("course_name", "").strip()
    db, is_mongo = get_db()

    deleted = False
    if is_mongo and db is not None:
        automations = db["course_automations"]
        query = {"notebook_id": notebook_id}
        if user_email:
            query["user_email"] = user_email
        if course_name:
            query["course_name"] = course_name
        res = automations.delete_one(query)
        if res.deleted_count == 0 and (user_email or course_name):
            res = automations.delete_one({"notebook_id": notebook_id})
        deleted = res.deleted_count > 0
    else:
        for k in list(memory_automations.keys()):
            v = memory_automations[k]
            if v.get("notebook_id") == notebook_id:
                if (not user_email or v.get("user_email") == user_email) and (not course_name or v.get("course_name") == course_name):
                    del memory_automations[k]
                    deleted = True
                    break
        if not deleted:
            for k in list(memory_automations.keys()):
                if memory_automations[k].get("notebook_id") == notebook_id:
                    del memory_automations[k]
                    deleted = True
                    break
        if deleted:
            save_memory_automations()

    if not deleted:
        return jsonify({"success": False, "message": "Automation record not found"}), 404

    return jsonify({"success": True, "message": f"Automation for notebook {notebook_id} successfully deleted"}), 200

@automation_bp.route("/api/automations/quiz-completed", methods=["POST"])
def record_quiz_completed():
    data = request.get_json() or {}
    notebook_id = data.get("notebook_id", "").strip()
    user_email = data.get("user_email", "").strip()
    
    try:
        week_number = int(data.get("week_number", 0))
    except (ValueError, TypeError):
        return jsonify({"success": False, "error": "Invalid week_number"}), 400

    score = data.get("score", 0)
    total_questions = data.get("total_questions", 5)

    if not notebook_id or week_number <= 0:
        return jsonify({"success": False, "error": "notebook_id and positive week_number are required"}), 400

    db, is_mongo = get_db()
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    quiz_record = {
        "score": score,
        "total_questions": total_questions,
        "completed_at": now_utc
    }

    doc = None
    if is_mongo and db is not None:
        automations = db["course_automations"]
        query = {"notebook_id": notebook_id}
        if user_email:
            query["user_email"] = user_email
        doc = automations.find_one(query)
        if not doc:
            return jsonify({"success": False, "message": "Automation not found"}), 404

        weekly_schedule = doc.get("weekly_schedule", [])
        matched = False
        for idx, item in enumerate(weekly_schedule):
            if item.get("week_number") == week_number:
                weekly_schedule[idx]["status"] = "QUIZ_COMPLETED"
                weekly_schedule[idx]["quiz_record"] = quiz_record
                weekly_schedule[idx]["completed_at"] = now_utc
                matched = True
                break

        if not matched:
            return jsonify({"success": False, "message": f"Week {week_number} not found in schedule"}), 404

        stats = calculate_progress_stats(weekly_schedule, doc.get("total_weeks"))
        automations.update_one(
            {"_id": doc["_id"]},
            {"$set": {
                "weekly_schedule": weekly_schedule,
                "completed_weeks_count": stats["completed_weeks_count"],
                "progress_percentage": stats["progress_percentage"],
                "next_scheduled_trigger": stats["next_scheduled_trigger"],
                "updated_at": now_utc
            }}
        )
        doc["completed_weeks_count"] = stats["completed_weeks_count"]
        doc["progress_percentage"] = stats["progress_percentage"]
        doc["next_scheduled_trigger"] = stats["next_scheduled_trigger"]
    else:
        for k, v in memory_automations.items():
            if v.get("notebook_id") == notebook_id:
                if not user_email or v.get("user_email") == user_email:
                    doc = v
                    break
        if not doc:
            return jsonify({"success": False, "message": "Automation not found"}), 404

        weekly_schedule = doc.get("weekly_schedule", [])
        for item in weekly_schedule:
            if item.get("week_number") == week_number:
                item["status"] = "QUIZ_COMPLETED"
                item["quiz_record"] = quiz_record
                item["completed_at"] = now_utc
                break

        stats = calculate_progress_stats(weekly_schedule, doc.get("total_weeks"))
        doc["completed_weeks_count"] = stats["completed_weeks_count"]
        doc["progress_percentage"] = stats["progress_percentage"]
        doc["next_scheduled_trigger"] = stats["next_scheduled_trigger"]
        doc["updated_at"] = now_utc
        save_memory_automations()

    return jsonify({
        "success": True,
        "message": f"Week {week_number} marked as QUIZ_COMPLETED",
        "stats": {
            "completed_weeks_count": doc.get("completed_weeks_count", 0),
            "progress_percentage": doc.get("progress_percentage", 0.0),
            "next_scheduled_trigger": doc["next_scheduled_trigger"].isoformat() if doc.get("next_scheduled_trigger") else None
        }
    }), 200

@automation_bp.route("/api/automations/revision-quiz", methods=["GET"])
def get_revision_quiz():
    notebook_id = request.args.get("notebook_id")
    week_number = request.args.get("week_number")

    if not notebook_id or not week_number:
        return jsonify({"success": False, "error": "notebook_id and week_number parameters required"}), 400

    try:
        week_num = int(week_number)
    except ValueError:
        return jsonify({"success": False, "error": "week_number must be an integer"}), 400

    db, is_mongo = get_db()
    auto_doc = None
    if is_mongo and db is not None:
        auto_doc = db["course_automations"].find_one({"notebook_id": notebook_id})
    else:
        for v in memory_automations.values():
            if v.get("notebook_id") == notebook_id:
                auto_doc = v
                break

    topic_title = f"Week {week_num} Revision Quiz"
    key_concepts = ["General Concept"]
    course_name = "Course Revision"

    if auto_doc:
        course_name = auto_doc.get("course_name", course_name)
        for s in auto_doc.get("weekly_schedule", []):
            if s.get("week_number") == week_num:
                topic_title = s.get("topic_title", topic_title)
                key_concepts = s.get("key_concepts", key_concepts)
                break

    # Construct interactive quiz questions based on topic and concepts
    quiz_questions = [
        {
            "question": f"In {course_name} (Week {week_num}: {topic_title}), what is the primary focus of {key_concepts[0] if key_concepts else 'this module'}?",
            "options": [
                f"Understanding the principles of {key_concepts[0] if key_concepts else 'the topic'}",
                "Ignoring baseline implementation details",
                "Deprecated legacy frameworks",
                "Non-related theoretical mechanics"
            ],
            "answer": f"Understanding the principles of {key_concepts[0] if key_concepts else 'the topic'}",
            "hint": f"Focus on {topic_title} fundamentals."
        },
        {
            "question": f"Which approach best applies to solving problems related to {topic_title}?",
            "options": [
                "Systematic revision and structured practice",
                "Random guessing without review",
                "Skipping foundational concepts",
                "Hardcoding fixed values"
            ],
            "answer": "Systematic revision and structured practice",
            "hint": "Think about effective study methods."
        }
    ]

    # Randomize option positions so correct answer is NOT always Option A
    import random
    for q in quiz_questions:
        if isinstance(q.get("options"), list):
            random.shuffle(q["options"])

    return jsonify({
        "success": True,
        "notebook_id": notebook_id,
        "week_number": week_num,
        "course_name": course_name,
        "topic_title": topic_title,
        "quiz_data": quiz_questions
    }), 200

@automation_bp.route("/revision", methods=["GET"])
def direct_web_revision_page():
    notebook_id = request.args.get("notebook_id", "")
    week_number = request.args.get("week_number", "1")
    user_email = request.args.get("user_email", "")

    db, is_mongo = get_db()
    auto_doc = None
    if is_mongo and db is not None:
        auto_doc = db["course_automations"].find_one({"notebook_id": notebook_id})
    else:
        for v in memory_automations.values():
            if v.get("notebook_id") == notebook_id:
                auto_doc = v
                break

    try:
        week_num = int(week_number)
    except ValueError:
        week_num = 1

    topic_title = f"Week {week_num} Active Study"
    key_concepts = ["Key Concepts"]
    course_name = "Subject Revision"

    if auto_doc:
        course_name = auto_doc.get("course_name", course_name)
        for s in auto_doc.get("weekly_schedule", []):
            if s.get("week_number") == week_num:
                topic_title = s.get("topic_title", topic_title)
                key_concepts = s.get("key_concepts", key_concepts)
                break

    # Build randomized HTML option buttons
    import random
    q1_opts = [
        ("Systematic recall quiz and reviewing key lecture concepts", True),
        ("Ignoring foundational definitions", False),
        ("Memorizing without practical understanding", False),
        ("Skipping revision exercises entirely", False)
    ]
    random.shuffle(q1_opts)
    letters = ["A", "B", "C", "D"]
    q1_html = "".join([f'<button class="option-btn" onclick="selectOption(1, this, {str(is_corr).lower()})">{letters[i]}) {opt}</button>\n' for i, (opt, is_corr) in enumerate(q1_opts)])

    q2_opts = [
        ("Building strong conceptual retention and problem-solving readiness", True),
        ("Relying solely on last-minute cramming", False),
        ("Unstructured passive reading", False),
        ("Leaving assignments incomplete", False)
    ]
    random.shuffle(q2_opts)
    q2_html = "".join([f'<button class="option-btn" onclick="selectOption(2, this, {str(is_corr).lower()})">{letters[i]}) {opt}</button>\n' for i, (opt, is_corr) in enumerate(q2_opts)])

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Note2Quiz - Week {week_num} Revision: {topic_title}</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }}
        body {{ background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }}
        .card {{ background: #1e293b; border: 1px solid #334155; border-radius: 20px; max-width: 650px; width: 100%; padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.4); }}
        .badge {{ display: inline-block; background: rgba(99, 102, 241, 0.2); color: #818cf8; font-weight: 600; font-size: 13px; padding: 6px 14px; border-radius: 20px; margin-bottom: 14px; }}
        h1 {{ font-size: 24px; margin-bottom: 8px; color: #ffffff; }}
        .sub {{ color: #94a3b8; font-size: 14px; margin-bottom: 24px; line-height: 1.5; }}
        .question-box {{ background: #0f172a; border: 1px solid #334155; border-radius: 14px; padding: 20px; margin-bottom: 20px; }}
        .q-title {{ font-size: 16px; font-weight: 600; margin-bottom: 16px; color: #e2e8f0; }}
        .option-btn {{ display: block; width: 100%; text-align: left; background: #1e293b; border: 1px solid #475569; color: #cbd5e1; padding: 14px 18px; border-radius: 10px; margin-bottom: 10px; cursor: pointer; font-size: 14px; transition: all 0.2s ease; }}
        .option-btn:hover {{ border-color: #6366f1; background: rgba(99, 102, 241, 0.1); }}
        .option-btn.selected {{ border-color: #6366f1; background: #6366f1; color: #ffffff; font-weight: 600; }}
        .submit-btn {{ display: block; width: 100%; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: white; border: none; padding: 16px; border-radius: 12px; font-size: 16px; font-weight: 700; cursor: pointer; margin-top: 20px; transition: opacity 0.2s; }}
        .submit-btn:hover {{ opacity: 0.9; }}
        .result {{ display: none; text-align: center; padding: 30px 10px; }}
        .result h2 {{ font-size: 28px; color: #4ade80; margin-bottom: 10px; }}
        .result p {{ color: #94a3b8; margin-bottom: 20px; }}
        .app-link {{ color: #818cf8; text-decoration: none; font-size: 13px; display: inline-block; margin-top: 15px; }}
    </style>
</head>
<body>
    <div class="card">
        <div id="quiz-section">
            <span class="badge">Week {week_num} Active Revision</span>
            <h1>{course_name}</h1>
            <p class="sub"><strong>Topic:</strong> {topic_title}</p>
            
            <div class="question-box">
                <div class="q-title">Q1: Which approach best reinforces your understanding of {topic_title}?</div>
                {q1_html}
            </div>

            <div class="question-box">
                <div class="q-title">Q2: In {course_name}, what is the key outcome of mastering {key_concepts[0] if key_concepts else topic_title}?</div>
                {q2_html}
            </div>

            <button class="submit-btn" onclick="submitQuiz()">Complete Revision Quiz</button>
        </div>

        <div id="result-section" class="result">
            <h2>🎉 Revision Completed!</h2>
            <p>Score: <strong id="score-text">2 / 2</strong> (100%)</p>
            <p style="color:#cbd5e1; font-size:14px; margin-bottom: 20px;">Your progress has been synced to Note2Quiz and recorded on your schedule!</p>
            
            <button class="submit-btn" style="background:#3b82f6; margin-bottom: 12px;" onclick="returnToDashboard()">
                ✨ Return to Note2Quiz Web Dashboard
            </button>
            <button class="submit-btn" style="background:#1e293b; border: 1px solid #475569; font-size: 14px; padding: 12px; margin-bottom: 12px;" onclick="launchMobileApp()">
                📱 Launch Note2Quiz Mobile App
            </button>
            <div style="font-size:12px; color:#94a3b8;">(Or you can safely close this browser tab)</div>
        </div>
    </div>

    <script>
        const answers = {{ 1: false, 2: false }};

        function selectOption(qNum, btn, isCorrect) {{
            const parent = btn.parentElement;
            parent.querySelectorAll('.option-btn').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            answers[qNum] = isCorrect;
        }}

        async function submitQuiz() {{
            let score = 0;
            if (answers[1]) score++;
            if (answers[2]) score++;

            try {{
                await fetch('/api/automations/quiz-completed', {{
                    method: 'POST',
                    headers: {{ 'Content-Type': 'application/json' }},
                    body: JSON.stringify({{
                        notebook_id: '{notebook_id}',
                        user_email: '{user_email}',
                        week_number: {week_num},
                        score: score,
                        total_questions: 2
                    }})
                }});
            }} catch(e) {{
                console.error("Submission failed:", e);
            }}

            document.getElementById('quiz-section').style.display = 'none';
            document.getElementById('score-text').innerText = score + ' / 2';
            document.getElementById('result-section').style.display = 'block';
        }}

        function returnToDashboard() {{
            if (window.opener && !window.opener.closed) {{
                try {{
                    window.opener.focus();
                    window.close();
                    return;
                }} catch(e) {{}}
            }}
            window.close();
            setTimeout(() => {{
                if (document.referrer && document.referrer.includes('localhost:')) {{
                    window.location.href = document.referrer;
                }} else {{
                    window.location.href = "http://localhost:60627";
                }}
            }}, 250);
        }}

        function launchMobileApp() {{
            const mobileUrl = "note2quiz://revision?notebook_id={notebook_id}&week_number={week_num}";
            // Attempt protocol launch
            window.location.href = mobileUrl;
            // Fallback for desktop browsers without app installed
            setTimeout(() => {{
                alert("If Note2Quiz app didn't open, please ensure the mobile app is installed, or use the 'Return to Note2Quiz Tab' button for the Web App!");
            }}, 1000);
        }}
    </script>
</body>
</html>"""
    return html, 200, {"Content-Type": "text/html; charset=utf-8"}
