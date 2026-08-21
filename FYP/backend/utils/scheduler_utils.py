import datetime
import pytz
import config

DAY_MAP = {
    "Monday": 0,
    "Tuesday": 1,
    "Wednesday": 2,
    "Thursday": 3,
    "Friday": 4,
    "Saturday": 5,
    "Sunday": 6
}

def parse_time_str(time_str):
    h, m = map(int, time_str.split(":"))
    return h, m

def calculate_weekly_schedule(
    semester_start_date_str,
    total_weeks,
    class_day,
    class_start_time_str,
    class_end_time_str,
    has_break_week,
    weekly_topics,
    timezone_str=None,
    revision_delay_hours=None,
    primary_reminder_time_str=None,
    enable_evening_reminder=True,
    evening_reminder_time_str="21:00"
):
    if timezone_str is None:
        timezone_str = config.DEFAULT_TIMEZONE
    if revision_delay_hours is None:
        revision_delay_hours = config.REVISION_DELAY_HOURS

    try:
        tz = pytz.timezone(timezone_str)
    except Exception:
        tz = pytz.timezone(config.DEFAULT_TIMEZONE)

    sem_start_dt = datetime.datetime.strptime(semester_start_date_str, "%Y-%m-%d")
    target_weekday = DAY_MAP.get(class_day.capitalize(), 0)

    # Find first class date on or after semester_start_date
    days_ahead = target_weekday - sem_start_dt.weekday()
    if days_ahead < 0:
        days_ahead += 7
    first_class_date = sem_start_dt.date() + datetime.timedelta(days=days_ahead)

    start_h, start_m = parse_time_str(class_start_time_str)
    end_h, end_m = parse_time_str(class_end_time_str)
    eve_h, eve_m = parse_time_str(evening_reminder_time_str or "21:00")

    schedule = []
    current_class_date = first_class_date

    for week_idx in range(1, total_weeks + 1):
        # Insert break week after week 6 if requested
        if has_break_week and week_idx == 7:
            current_class_date += datetime.timedelta(weeks=1)

        # Local start & end datetimes
        local_start = tz.localize(datetime.datetime.combine(
            current_class_date, datetime.time(start_h, start_m)
        ))
        local_end = tz.localize(datetime.datetime.combine(
            current_class_date, datetime.time(end_h, end_m)
        ))

        # Handle end time past midnight
        if local_end <= local_start:
            local_end += datetime.timedelta(days=1)

        # 1st Email Dispatch: Exactly at Class End Time of that day (or custom time if specified)
        if primary_reminder_time_str and primary_reminder_time_str != "CLASS_END":
            prim_h, prim_m = parse_time_str(primary_reminder_time_str)
            primary_trigger = tz.localize(datetime.datetime.combine(
                current_class_date, datetime.time(prim_h, prim_m)
            ))
        elif revision_delay_hours is not None and revision_delay_hours > 0:
            primary_trigger = local_end + datetime.timedelta(hours=revision_delay_hours)
        else:
            primary_trigger = local_end

        # 2nd Email Dispatch: 9:00 PM on the day of class
        if enable_evening_reminder:
            evening_trigger = tz.localize(datetime.datetime.combine(
                current_class_date, datetime.time(eve_h, eve_m)
            ))
        else:
            evening_trigger = None

        topic_item = next((t for t in weekly_topics if t.get("week_number") == week_idx), None)
        topic_title = topic_item["topic_title"] if topic_item else f"Week {week_idx} Topic"
        key_concepts = topic_item.get("key_concepts", []) if topic_item else []

        schedule_item = {
            "week_number": week_idx,
            "topic_title": topic_title,
            "key_concepts": key_concepts,
            "class_start_timestamp": local_start,
            "class_end_timestamp": local_end,
            "revision_trigger_timestamp": primary_trigger,
            "actual_trigger_timestamp": primary_trigger,
            "primary_trigger_timestamp": primary_trigger,
            "evening_trigger_timestamp": evening_trigger,
            "enable_evening_reminder": enable_evening_reminder,
            "status": "PENDING",
            "email_dispatched_at": None,
            "evening_dispatched_at": None,
            "calendar_event_id": None,
            "quiz_record": None,
            "notification_sent_at": None,
            "completed_at": None,
            "last_error": None
        }

        schedule.append(schedule_item)
        current_class_date += datetime.timedelta(weeks=1)

    return schedule
