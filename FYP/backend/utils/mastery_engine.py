import math
import datetime

def parse_iso_or_str_time(time_val):
    if not time_val:
        return None
    if isinstance(time_val, datetime.datetime):
        return time_val
    for fmt in ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f"]:
        try:
            return datetime.datetime.strptime(str(time_val).split(".")[0], fmt)
        except Exception:
            continue
    return None

def calculate_topic_mastery(last_percentage, last_reviewed_at, review_count=1):
    """
    Computes dynamic retention score based on Ebbinghaus Forgetting Curve and SM-2 repetition model.
    Formula:
        t = days elapsed since last review
        S (Stability) = 1.0 + (0.65 * (review_count - 1))
        R(t) = Base_Accuracy * e^(-t / (7.0 * S))
        Mastery = round(R(t))
    """
    if last_percentage is None:
        return {
            "mastery_score": 0,
            "status": "unreviewed",
            "status_label": "Not Started",
            "decay_days": 0,
            "color": "#9E9E9E",
            "stability": 1.0,
            "needs_review": True
        }

    base_score = float(last_percentage)
    review_count = max(1, int(review_count or 1))
    
    last_dt = parse_iso_or_str_time(last_reviewed_at)
    if not last_dt:
        days_elapsed = 0.0
    else:
        now = datetime.datetime.now()
        diff = now - last_dt
        days_elapsed = max(0.0, diff.total_seconds() / 86400.0)

    # SM-2 Stability factor: each successful review strengthens retention memory half-life
    stability = 1.0 + (0.65 * (review_count - 1))
    
    # Ebbinghaus exponential decay
    decay_factor = math.exp(-days_elapsed / (7.0 * stability))
    current_retention = max(0.0, min(100.0, base_score * decay_factor))
    mastery_score = round(current_retention)

    if mastery_score >= 80:
        status = "fresh"
        status_label = "Fresh (Mastered)"
        color = "#4CAF50" # Green
        needs_review = False
    elif mastery_score >= 50:
        status = "fading"
        status_label = "Fading (Review Soon)"
        color = "#FFC107" # Yellow
        needs_review = True
    else:
        status = "critical"
        status_label = "At Risk (Review Needed)"
        color = "#F44336" # Red
        needs_review = True

    return {
        "mastery_score": mastery_score,
        "base_score": round(base_score),
        "status": status,
        "status_label": status_label,
        "decay_days": round(days_elapsed, 1),
        "color": color,
        "stability": round(stability, 2),
        "review_count": review_count,
        "needs_review": needs_review
    }

def calculate_course_mastery_metrics(syllabus_schedule, history_results):
    """
    Computes aggregated course mastery across all 14 weeks.
    """
    if not syllabus_schedule:
        return {"overall_mastery": 0, "mastered_weeks": 0, "total_weeks": 0, "retention_status": "No Schedule"}

    week_map_history = {}
    for h in (history_results or []):
        w_num = h.get("week_number")
        if w_num is not None:
            pct = h.get("percentage") if h.get("percentage") is not None else (h.get("score", 0) / max(1, h.get("total_questions", 1)) * 100)
            if w_num not in week_map_history or (str(h.get("completed_at", "")) > str(week_map_history[w_num].get("completed_at", ""))):
                week_map_history[w_num] = {
                    "percentage": pct,
                    "completed_at": h.get("completed_at", ""),
                    "count": week_map_history.get(w_num, {}).get("count", 0) + 1
                }

    total_score = 0
    mastered_count = 0
    total_active_weeks = len(syllabus_schedule)

    for item in syllabus_schedule:
        w_num = item.get("week_number")
        h_data = week_map_history.get(w_num)
        if h_data:
            m_res = calculate_topic_mastery(h_data["percentage"], h_data["completed_at"], h_data["count"])
            total_score += m_res["mastery_score"]
            if m_res["mastery_score"] >= 80:
                mastered_count += 1

    overall_mastery = round(total_score / max(1, total_active_weeks))
    return {
        "overall_mastery": overall_mastery,
        "mastered_weeks": mastered_count,
        "total_weeks": total_active_weeks,
        "retention_status": "Strong" if overall_mastery >= 75 else ("Moderate" if overall_mastery >= 50 else "Needs Revision")
    }
