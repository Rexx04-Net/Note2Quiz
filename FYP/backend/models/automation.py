import re
import datetime

VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

def validate_automation_request(data, files, from_timetable=False):
    errors = []

    notebook_id = data.get("notebook_id", "").strip()
    if not notebook_id:
        errors.append("notebook_id is required")

    course_name = data.get("course_name", "").strip()
    if not course_name and not data.get("linked_course_id"):
        errors.append("course_name or linked_course_id is required")

    user_email = data.get("user_email", "").strip()
    if not user_email or "@" not in user_email:
        errors.append("valid user_email is required")

    # Day of week
    class_day = data.get("class_day", "").strip().capitalize()
    if not from_timetable or class_day:
        if class_day not in VALID_DAYS:
            errors.append(f"class_day must be one of {VALID_DAYS}")

    # Times (HH:MM format validation)
    class_start_time = data.get("class_start_time", "").strip()
    class_end_time = data.get("class_end_time", "").strip()
    
    if not from_timetable or (class_start_time and class_end_time):
        time_regex = r"^([01]?[0-9]|2[0-3]):[0-5][0-9]$"
        start_valid = bool(re.match(time_regex, class_start_time))
        end_valid = bool(re.match(time_regex, class_end_time))

        if not start_valid:
            errors.append("class_start_time must be in HH:MM format (24-hour)")
        if not end_valid:
            errors.append("class_end_time must be in HH:MM format (24-hour)")

        if start_valid and end_valid:
            start_h, start_m = map(int, class_start_time.split(":"))
            end_h, end_m = map(int, class_end_time.split(":"))
            if (end_h * 60 + end_m) <= (start_h * 60 + start_m):
                errors.append("class_end_time must be later than class_start_time")

    # Semester total_weeks
    try:
        total_weeks = int(data.get("total_weeks", 14))
        if total_weeks not in [12, 13, 14]:
            errors.append("total_weeks must be 12, 13, or 14")
    except ValueError:
        errors.append("total_weeks must be an integer (12, 13, or 14)")

    # Semester start date (YYYY-MM-DD)
    semester_start_date = data.get("semester_start_date", "").strip()
    if semester_start_date:
        try:
            datetime.datetime.strptime(semester_start_date[:10], "%Y-%m-%d")
        except ValueError:
            errors.append("semester_start_date must be in YYYY-MM-DD format")

    # PDF validation
    syllabus_file = files.get("syllabus")
    if not syllabus_file or syllabus_file.filename == "":
        errors.append("Syllabus PDF file is required")
    elif not syllabus_file.filename.lower().endswith(".pdf"):
        errors.append("Syllabus file must be a PDF")

    return errors

def calculate_progress_stats(weekly_schedule, total_weeks=None):
    if total_weeks is None:
        total_weeks = len(weekly_schedule) if weekly_schedule else 14

    completed_count = 0
    next_trigger = None
    now_utc = datetime.datetime.now(datetime.timezone.utc)

    for item in weekly_schedule:
        status = item.get("status")
        if status == "QUIZ_COMPLETED":
            completed_count += 1

        trigger_ts = item.get("actual_trigger_timestamp") or item.get("revision_trigger_timestamp")
        if isinstance(trigger_ts, str):
            try:
                trigger_ts = datetime.datetime.fromisoformat(trigger_ts)
            except Exception:
                trigger_ts = None

        if trigger_ts is not None and getattr(trigger_ts, "tzinfo", None) is None:
            trigger_ts = trigger_ts.replace(tzinfo=datetime.timezone.utc)

        if status in ["PENDING", "PROCESSING", "REMINDER_SENT"] and trigger_ts is not None:
            if next_trigger is None or trigger_ts < next_trigger:
                next_trigger = trigger_ts

    progress_percentage = round((completed_count / total_weeks) * 100.0, 1) if total_weeks > 0 else 0.0

    return {
        "completed_weeks_count": completed_count,
        "progress_percentage": progress_percentage,
        "next_scheduled_trigger": next_trigger
    }

def build_automation_doc(notebook_id, user_email, course_name, timezone_str, semester_config, timetable, syllabus_meta, weekly_schedule, calendar_details=None):
    now = datetime.datetime.now(datetime.timezone.utc)
    total_weeks = semester_config.get("total_weeks", len(weekly_schedule) if weekly_schedule else 14)
    stats = calculate_progress_stats(weekly_schedule, total_weeks)

    return {
        "notebook_id": notebook_id,
        "user_email": user_email,
        "course_name": course_name,
        "timezone": timezone_str,
        "total_weeks": total_weeks,
        "completed_weeks_count": stats["completed_weeks_count"],
        "progress_percentage": stats["progress_percentage"],
        "next_scheduled_trigger": stats["next_scheduled_trigger"],
        "semester_config": semester_config,
        "timetable": timetable,
        "syllabus_metadata": syllabus_meta,
        "sub_calendar_details": calendar_details or {
            "provider": "google",
            "calendar_id": None,
            "calendar_name": f"Note2Quiz - {course_name}"
        },
        "weekly_schedule": weekly_schedule,
        "created_at": now,
        "updated_at": now
    }
