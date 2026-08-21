from pymongo import ASCENDING
from database.connection import get_db

def init_indexes():
    db, is_mongo = get_db()
    if not is_mongo or db is None:
        print("ℹ️ [Indexes] Skipping MongoDB index initialization (Memory mode active).")
        return

    automations = db["course_automations"]
    try:
        # 1. Unique compound index: notebook_id + user_email
        automations.create_index(
            [("notebook_id", ASCENDING), ("user_email", ASCENDING)],
            unique=True,
            name="uniq_notebook_user"
        )

        # 2. Query index for due schedule notifications
        automations.create_index(
            [("weekly_schedule.status", ASCENDING), ("weekly_schedule.actual_trigger_timestamp", ASCENDING)],
            name="idx_schedule_status_actual_trigger"
        )
        automations.create_index(
            [("weekly_schedule.status", ASCENDING), ("weekly_schedule.revision_trigger_timestamp", ASCENDING)],
            name="idx_schedule_status_trigger"
        )

        # 3. Secondary indexes
        automations.create_index([("user_email", ASCENDING)], name="idx_user_email")
        automations.create_index([("course_name", ASCENDING)], name="idx_course_name")
        automations.create_index([("updated_at", ASCENDING)], name="idx_updated_at")

        print("✅ [Indexes] Course automations indexes verified/created successfully.")
    except Exception as e:
        print(f"⚠️ [Indexes] Index initialization warning: {e}")
