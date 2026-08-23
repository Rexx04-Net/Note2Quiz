import datetime
from flask import Blueprint, request, jsonify
from database.connection import get_db, memory_automations, save_memory_automations
from models.automation import validate_automation_request, build_automation_doc, calculate_progress_stats
from services.syllabus_parser import parse_syllabus_pdf
from utils.scheduler_utils import calculate_weekly_schedule
from services.calendar_service import sync_google_calendar
from utils.mastery_engine import calculate_topic_mastery, calculate_course_mastery_metrics

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

            # Calculate SM-2 Retention Mastery for this week
            qr_data = s_copy.get("quiz_record")
            if qr_data:
                pct = qr_data.get("percentage") if qr_data.get("percentage") is not None else (qr_data.get("score", 0) / max(1, qr_data.get("total_questions", 1)) * 100)
                comp_at = qr_data.get("completed_at") or s_copy.get("completed_at")
                s_copy["mastery"] = calculate_topic_mastery(pct, comp_at, qr_data.get("review_count", 1))
            elif s_copy.get("status") == "completed":
                s_copy["mastery"] = calculate_topic_mastery(100, s_copy.get("completed_at"), 1)
            else:
                s_copy["mastery"] = calculate_topic_mastery(None, None, 0)

            formatted_schedule.append(s_copy)
        doc_copy["weekly_schedule"] = formatted_schedule

    # Overall course mastery
    history_records = [s.get("quiz_record") for s in doc_copy.get("weekly_schedule", []) if s.get("quiz_record")]
    doc_copy["mastery_metrics"] = calculate_course_mastery_metrics(doc_copy.get("weekly_schedule", []), history_records)
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
        query_conditions = [{"notebook_id": notebook_id}]
        if course_name:
            query_conditions.append({"course_name": course_name})
            prefix = course_name.split("-")[0].strip()
            if prefix:
                query_conditions.append({"course_name": {"$regex": f"^{prefix}", "$options": "i"}})

        main_query = {"$or": query_conditions}
        if user_email and user_email.lower() not in ["guest", ""]:
            cursor = automations.find({"$and": [main_query, {"user_email": user_email}]}).sort("updated_at", -1)
            all_docs = list(cursor)

        if not all_docs:
            all_docs = list(automations.find(main_query).sort("updated_at", -1))

        if not all_docs:
            all_docs = list(automations.find({"notebook_id": notebook_id}).sort("updated_at", -1))

        if all_docs:
            doc = all_docs[0]
    else:
        for k, v in memory_automations.items():
            if v.get("notebook_id") == notebook_id or (course_name and course_name.split('-')[0].strip() in v.get("course_name", "")):
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
        query_conditions = [{"notebook_id": notebook_id}]
        if course_name:
            query_conditions.append({"course_name": course_name})
            prefix = course_name.split("-")[0].strip()
            if prefix:
                query_conditions.append({"course_name": {"$regex": f"^{prefix}", "$options": "i"}})

        res = automations.delete_many({"$or": query_conditions})
        deleted = res.deleted_count > 0
    else:
        for k in list(memory_automations.keys()):
            v = memory_automations[k]
            if v.get("notebook_id") == notebook_id or (course_name and course_name.split('-')[0].strip() in v.get("course_name", "")):
                del memory_automations[k]
                deleted = True
        if deleted:
            save_memory_automations()

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
        if user_email and user_email.lower() not in ["guest", ""]:
            query["$or"] = [{"user_email": user_email}, {"user_email": "guest"}, {"user_email": ""}]
        doc = automations.find_one(query)
        if not doc:
            doc = automations.find_one({"notebook_id": notebook_id})
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


@automation_bp.route("/api/analytics/overview", methods=["GET"])
def get_analytics_overview():
    user_email = request.args.get("user_email", "").strip()
    db, is_mongo = get_db()

    course_list = []
    radar_data = []

    # Smart topic label cleaner
    import re
    def clean_topic_label(raw_title, default_prefix="T"):
        if not raw_title:
            return default_prefix
        t = raw_title.replace(".pdf", "").replace(".pptx", "").replace(".ppt", "").replace(".docx", "").strip()
        t = re.sub(r'^[A-Z0-9]{6,8}\s*[-_]\s*', '', t)
        t = t.replace('_', ' ').replace('-', ' ')
        m = re.search(r'(?:Lecture|Chapter|Week|Topic)\s*(\d+)(.*)', t, re.IGNORECASE)
        if m:
            num = m.group(1)
            rest = m.group(2).strip(' -:_').strip()
            stop_words = {'part', 'the', 'of', 'for', 'to', 'in', 'and', 'as', 'a', 'an', 'revision', 'basic', 'on', 'exploring', 'fundamentals'}
            words = [w for w in rest.split() if w.lower() not in stop_words]
            if not words and rest:
                words = rest.split()
            clean_rest = ' '.join(words[:2]) if words else ''
            if len(clean_rest) > 11:
                clean_rest = clean_rest[:11]
            return f"L{num}: {clean_rest}" if clean_rest else f"L{num}"
        return t[:12]

    # 1. Fetch user's automations
    # 1. Fetch user's automations, notebooks, and active study roadmaps
    all_automations = []
    notebooks = []
    study_plans = []
    if is_mongo and db is not None:
        query = {}
        if user_email:
            query = {"$or": [{"user_email": user_email}, {"user_email": "guest"}, {"user_email": ""}]}
        all_automations = list(db["course_automations"].find(query))
        notebooks = list(db["notebooks"].find(query if user_email else {}))
        study_plans = list(db["study_plans"].find(query if user_email else {}))
    else:
        all_automations = list(memory_automations.values())
        try:
            from app import memory_notebooks, memory_study_plans
            notebooks = memory_notebooks
            study_plans = memory_study_plans
        except Exception:
            notebooks = []
            study_plans = []

    # 2. Build course mastery metrics
    for auto in all_automations:
        c_name = auto.get("course_name", "Course")
        c_code = c_name.split("-")[0].strip().lower()
        schedule = auto.get("weekly_schedule") or auto.get("schedule", [])

        history_results = []
        for idx, s in enumerate(schedule, 1):
            w_num = s.get("week_number", idx)
            if s.get("quiz_record"):
                qr = dict(s["quiz_record"])
                qr["week_number"] = w_num
                history_results.append(qr)
            elif str(s.get("status", "")).upper() in ["QUIZ_COMPLETED", "COMPLETED"]:
                history_results.append({
                    "week_number": w_num,
                    "percentage": 100,
                    "completed_at": s.get("completed_at")
                })

        nb_id = auto.get("notebook_id")
        nb = next((n for n in notebooks if n.get("id") == nb_id or c_code in (n.get("title", "").lower())), None)
        
        # Rule: Do not count courses that have 0 uploaded sources and 0 quiz activity
        nb_sources_count = len(nb.get("sources", [])) if nb else 0
        if nb_sources_count == 0 and len(history_results) == 0:
            continue

        c_metrics = calculate_course_mastery_metrics(schedule, history_results)
        mistake_count = len(nb.get("mistakes_bank", [])) if nb else 0

        # Find matching AI Study Roadmaps for this course
        course_plans = [p for p in study_plans if (nb and nb.get("id") in p.get("notebook_ids", [])) or (c_code and c_code in p.get("title", "").lower())]
        roadmap_progress = max([float(p.get("progress_percentage", 0.0)) for p in course_plans], default=0.0)

        # 1. Automation Topic Track (from weekly_schedule)
        automation_topics = []
        if schedule:
            for idx, s in enumerate(schedule, 1):
                w_num = s.get("week_number", idx)
                t_title = s.get("topic_title") or f"Week {w_num}"
                short_t = clean_topic_label(t_title, default_prefix=f"W{w_num}")
                qr_data = s.get("quiz_record")
                is_completed = str(s.get("status", "")).upper() in ["QUIZ_COMPLETED", "COMPLETED"]

                if qr_data:
                    score_val = qr_data.get("score")
                    total_val = qr_data.get("total_questions")
                    if qr_data.get("percentage") is not None:
                        pct = qr_data["percentage"]
                    elif score_val is not None and total_val is not None and total_val > 0:
                        pct = (score_val / total_val) * 100
                    else:
                        pct = 100
                    comp_at = qr_data.get("completed_at") or s.get("completed_at")
                    m_score = calculate_topic_mastery(pct, comp_at, qr_data.get("review_count", 1))["mastery_score"]
                elif is_completed:
                    m_score = calculate_topic_mastery(100, s.get("completed_at"), 1)["mastery_score"]
                else:
                    m_score = 0

                automation_topics.append({
                    "subject": short_t,
                    "full_name": t_title,
                    "automation_score": m_score,
                    "notebook_score": 0,
                    "score": m_score,
                    "fullMark": 100
                })

        # 2. Notebook Sources & AI Roadmap Track (from notebook sources + roadmap tasks)
        notebook_topics = []
        if nb and nb.get("sources"):
            nb_sources = nb.get("sources", [])
            q_results = nb.get("quiz_results", [])

            for idx, src in enumerate(nb_sources, 1):
                raw_name = ""
                if isinstance(src, dict):
                    raw_name = src.get("title") or src.get("name") or src.get("filename") or f"Topic {idx}"
                else:
                    raw_name = str(src) if src else f"Topic {idx}"
                clean_name = raw_name.replace(".pdf", "").replace(".pptx", "").replace(".ppt", "").replace(".docx", "").strip()
                short_label = clean_topic_label(clean_name, default_prefix=f"T{idx}")

                # 2a. Check if any notebook quiz specifically practiced this topic
                matching_quiz = next((q for q in q_results if clean_name.lower() in str(q.get("quiz_title", "")).lower() or str(idx) in str(q.get("quiz_title", ""))), None)
                if matching_quiz:
                    pct = matching_quiz.get("percentage", 100)
                    nb_score = calculate_topic_mastery(pct, matching_quiz.get("completed_at"), matching_quiz.get("review_count", 1))["mastery_score"]
                else:
                    nb_score = 0

                # 2b. Check if this topic was completed in the AI Study Roadmap
                for plan in course_plans:
                    for day in plan.get("days", []):
                        for task in day.get("tasks", []):
                            if task.get("completed"):
                                t_task_title = task.get("title", "").lower()
                                if clean_name.lower() in t_task_title or f"chapter {idx}" in t_task_title or f"topic {idx}" in t_task_title:
                                    nb_score = max(nb_score, 100)

                # Match automation track
                auto_score = 0
                if idx <= len(automation_topics):
                    auto_score = automation_topics[idx - 1]["automation_score"]

                notebook_topics.append({
                    "subject": short_label,
                    "full_name": clean_name,
                    "automation_score": auto_score,
                    "notebook_score": nb_score,
                    "score": max(auto_score, nb_score),
                    "fullMark": 100
                })

        # Select richest topic radar representation
        topic_radar = notebook_topics if (notebook_topics and len(notebook_topics) >= len(automation_topics)) else (automation_topics or notebook_topics)

        while len(topic_radar) < 3:
            idx = len(topic_radar) + 1
            topic_radar.append({
                "subject": f"Topic {idx}",
                "full_name": f"Topic {idx}",
                "automation_score": 0,
                "notebook_score": 0,
                "score": 0,
                "fullMark": 100
            })

        course_item = {
            "course_name": c_name,
            "notebook_id": nb_id,
            "overall_mastery": c_metrics["overall_mastery"],
            "mastered_weeks": c_metrics["mastered_weeks"],
            "total_weeks": c_metrics["total_weeks"],
            "retention_status": c_metrics["retention_status"],
            "mistakes_count": mistake_count,
            "completed_weeks": len(history_results),
            "topic_radar": topic_radar
        }
        course_list.append(course_item)

        # Course-level Notebook/Roadmap Score
        quiz_avg = round(sum(q.get("percentage", 0) for q in nb.get("quiz_results", [])) / max(1, len(nb.get("quiz_results", [])))) if (nb and nb.get("quiz_results")) else 0
        effective_nb_score = round(max(roadmap_progress, quiz_avg))

        short_label = c_name.split("-")[0].strip() if "-" in c_name else c_name[:12]
        radar_data.append({
            "subject": short_label,
            "full_name": c_name,
            "automation_score": c_metrics["overall_mastery"],
            "notebook_score": effective_nb_score,
            "score": max(c_metrics["overall_mastery"], effective_nb_score),
            "fullMark": 100
        })

    # Include standalone notebooks without active automation (excluding dummy test placeholders and empty notebooks)
    for nb in notebooks:
        nb_title = (nb.get("title") or "").strip()
        nb_id_str = str(nb.get("id") or nb.get("_id") or "")
        if nb_title.lower() in ["notebook", "test", "test nb", "test blended nb"] or nb_id_str.startswith("test_"):
            continue

        nb_sources = nb.get("sources", [])
        q_results = nb.get("quiz_results", [])
        # Strictly ignore notebooks that haven't uploaded sources and have no quiz activity
        if len(nb_sources) == 0 and len(q_results) == 0:
            continue

        c_code_nb = nb_title.split("-")[0].strip().lower()
        if not any(c["notebook_id"] == nb.get("id") or c_code_nb in c["course_name"].lower() for c in course_list):
            course_plans = [p for p in study_plans if nb.get("id") in p.get("notebook_ids", []) or c_code_nb in p.get("title", "").lower()]
            roadmap_progress = max([float(p.get("progress_percentage", 0.0)) for p in course_plans], default=0.0)
            quiz_avg = round(sum(q.get("percentage", 0) for q in q_results) / max(1, len(q_results))) if q_results else 0
            effective_nb_score = round(max(roadmap_progress, quiz_avg))

            short_label = nb_title.split("-")[0].strip()[:12]
            
            # Build topic radar from all uploaded sources
            nb_topic_radar = []
            for idx, src in enumerate(nb_sources, 1):
                raw_name = ""
                if isinstance(src, dict):
                    raw_name = src.get("title") or src.get("name") or src.get("filename") or f"Topic {idx}"
                else:
                    raw_name = str(src) if src else f"Topic {idx}"
                clean_name = raw_name.replace(".pdf", "").replace(".pptx", "").replace(".docx", "").strip()
                short_label_topic = clean_topic_label(clean_name, default_prefix=f"T{idx}")
                
                # Check topic completion in roadmap
                t_score = 0
                for plan in course_plans:
                    for day in plan.get("days", []):
                        for task in day.get("tasks", []):
                            if task.get("completed"):
                                t_task_title = task.get("title", "").lower()
                                if clean_name.lower() in t_task_title or f"chapter {idx}" in t_task_title or f"topic {idx}" in t_task_title:
                                    t_score = 100

                nb_topic_radar.append({
                    "subject": short_label_topic,
                    "full_name": clean_name,
                    "automation_score": 0,
                    "notebook_score": t_score,
                    "score": t_score,
                    "fullMark": 100
                })

            while len(nb_topic_radar) < 3:
                idx = len(nb_topic_radar) + 1
                nb_topic_radar.append({
                    "subject": f"Topic {idx}",
                    "full_name": f"Topic {idx}",
                    "automation_score": 0,
                    "notebook_score": 0,
                    "score": 0,
                    "fullMark": 100
                })

            radar_data.append({
                "subject": short_label,
                "full_name": nb_title,
                "automation_score": 0,
                "notebook_score": effective_nb_score,
                "score": effective_nb_score,
                "fullMark": 100
            })
            course_list.append({
                "course_name": nb_title,
                "notebook_id": nb.get("id"),
                "overall_mastery": effective_nb_score,
                "mastered_weeks": len(q_results),
                "total_weeks": max(1, len(q_results)),
                "retention_status": "Active" if effective_nb_score >= 70 else "Needs Practice",
                "mistakes_count": len(nb.get("mistakes_bank", [])),
                "completed_weeks": len(q_results),
                "topic_radar": nb_topic_radar
            })

    radar_data = radar_data[:6]
    if len(radar_data) < 3:
        radar_data.append({"subject": "Exam Ready", "score": 85, "fullMark": 100})
        radar_data.append({"subject": "Retention", "score": 80, "fullMark": 100})
        radar_data.append({"subject": "Recall", "score": 90, "fullMark": 100})

    weekly_trend = [
        {"week": "W1", "accuracy": 78, "quizzes": 2},
        {"week": "W2", "accuracy": 84, "quizzes": 3},
        {"week": "W3", "accuracy": 92, "quizzes": 4},
        {"week": "W4", "accuracy": 86, "quizzes": 3},
        {"week": "W5", "accuracy": 95, "quizzes": 5},
        {"week": "W6", "accuracy": 90, "quizzes": 4},
    ]

    avg_mastery = round(sum(c["overall_mastery"] for c in course_list) / max(1, len(course_list))) if course_list else 80
    strongest = max(course_list, key=lambda x: x["overall_mastery"]) if course_list else None
    weakest = min(course_list, key=lambda x: x["overall_mastery"]) if course_list else None

    diagnostic_text = f"Overall memory retention index is currently at {avg_mastery}% across {len(course_list)} enrolled courses."
    if strongest and strongest.get("overall_mastery", 0) >= 75:
        diagnostic_text += f" Excellent retention exhibited in {strongest['course_name']} ({strongest['overall_mastery']}%)."
    if weakest and weakest.get("overall_mastery", 0) < 70:
        diagnostic_text += f" Memory decay detected in {weakest['course_name']} ({weakest['overall_mastery']}%); an Ebbinghaus spaced revision session is recommended."

    return jsonify({
        "success": True,
        "overall_retention_index": avg_mastery,
        "courses_count": len(course_list),
        "total_active_mistakes": sum(c.get("mistakes_count", 0) for c in course_list),
        "radar_data": radar_data,
        "courses": course_list,
        "weekly_trend": weekly_trend,
        "diagnostic_insight": {
            "title": "AI Spaced Learning Diagnostic",
            "summary": diagnostic_text,
            "strongest_domain": strongest["course_name"] if strongest else "General Concepts",
            "recommended_focus": weakest["course_name"] if weakest else "Review Active Notes",
            "retention_health": "Optimal (🟢 Green)" if avg_mastery >= 75 else ("Moderate (🟡 Yellow)" if avg_mastery >= 50 else "At Risk (🔴 Red)")
        }
    }), 200
