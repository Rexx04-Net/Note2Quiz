import datetime
from database.connection import get_db, memory_automations
from services.notification_service import send_revision_email
from models.automation import calculate_progress_stats

def check_and_send_due_notifications():
    db, is_mongo = get_db()
    now_utc = datetime.datetime.now(datetime.timezone.utc)

    if is_mongo and db is not None:
        automations_col = db["course_automations"]
        cursor = automations_col.find({
            "weekly_schedule": {
                "$elemMatch": {
                    "$or": [
                        # Stage 1: Primary reminder (e.g. 6:00 PM)
                        {
                            "status": "PENDING",
                            "$or": [
                                {"primary_trigger_timestamp": {"$lte": now_utc}},
                                {"actual_trigger_timestamp": {"$lte": now_utc}},
                                {"revision_trigger_timestamp": {"$lte": now_utc}}
                            ]
                        },
                        # Stage 2: Evening follow-up reminder (e.g. 9:00 PM) if uncompleted
                        {
                            "status": "REMINDER_SENT",
                            "enable_evening_reminder": True,
                            "evening_dispatched_at": None,
                            "evening_trigger_timestamp": {"$lte": now_utc}
                        }
                    ]
                }
            }
        })

        for auto in cursor:
            notebook_id = auto.get("notebook_id")
            user_email = auto.get("user_email")
            course_name = auto.get("course_name")
            weekly_schedule = auto.get("weekly_schedule", [])

            for idx, item in enumerate(weekly_schedule):
                status = item.get("status")
                prim_trigger = item.get("primary_trigger_timestamp") or item.get("actual_trigger_timestamp") or item.get("revision_trigger_timestamp")
                eve_trigger = item.get("evening_trigger_timestamp")
                enable_eve = item.get("enable_evening_reminder", True)
                eve_dispatched = item.get("evening_dispatched_at")

                if isinstance(prim_trigger, datetime.datetime) and prim_trigger.tzinfo is None:
                    prim_trigger = prim_trigger.replace(tzinfo=datetime.timezone.utc)
                if isinstance(eve_trigger, datetime.datetime) and eve_trigger.tzinfo is None:
                    eve_trigger = eve_trigger.replace(tzinfo=datetime.timezone.utc)

                # 1. Primary Reminder (6:00 PM)
                if status == "PENDING" and prim_trigger and prim_trigger <= now_utc:
                    week_num = item.get("week_number")
                    topic_title = item.get("topic_title")

                    claim_result = automations_col.update_one(
                        {
                            "_id": auto["_id"],
                            f"weekly_schedule.{idx}.status": "PENDING"
                        },
                        {
                            "$set": {f"weekly_schedule.{idx}.status": "PROCESSING"}
                        }
                    )

                    if claim_result.modified_count > 0:
                        try:
                            send_revision_email(
                                user_email=user_email,
                                course_name=course_name,
                                week_number=week_num,
                                topic_title=topic_title,
                                notebook_id=notebook_id,
                                is_evening_reminder=False
                            )
                            sent_time = datetime.datetime.now(datetime.timezone.utc)
                            weekly_schedule[idx]["status"] = "REMINDER_SENT"
                            weekly_schedule[idx]["email_dispatched_at"] = sent_time
                            weekly_schedule[idx]["notification_sent_at"] = sent_time

                            stats = calculate_progress_stats(weekly_schedule, auto.get("total_weeks"))
                            automations_col.update_one(
                                {"_id": auto["_id"]},
                                {"$set": {
                                    f"weekly_schedule.{idx}.status": "REMINDER_SENT",
                                    f"weekly_schedule.{idx}.email_dispatched_at": sent_time,
                                    f"weekly_schedule.{idx}.notification_sent_at": sent_time,
                                    "next_scheduled_trigger": stats["next_scheduled_trigger"],
                                    "updated_at": sent_time
                                }}
                            )
                            print(f"📧 [Notifier] Sent 1st revision email for {course_name} (Week {week_num}) to {user_email}")
                        except Exception as err:
                            err_str = str(err)
                            automations_col.update_one(
                                {"_id": auto["_id"]},
                                {"$set": {
                                    f"weekly_schedule.{idx}.status": "FAILED",
                                    f"weekly_schedule.{idx}.last_error": err_str,
                                    "updated_at": datetime.datetime.now(datetime.timezone.utc)
                                }}
                            )
                            print(f"⚠️ [Notifier] 1st email delivery failed for Week {week_num}: {err_str}")

                # 2. Evening Follow-Up Reminder (9:00 PM) - only if quiz still not completed
                elif status == "REMINDER_SENT" and enable_eve and eve_dispatched is None and eve_trigger and eve_trigger <= now_utc:
                    week_num = item.get("week_number")
                    topic_title = item.get("topic_title")

                    try:
                        send_revision_email(
                            user_email=user_email,
                            course_name=course_name,
                            week_number=week_num,
                            topic_title=topic_title,
                            notebook_id=notebook_id,
                            is_evening_reminder=True
                        )
                        eve_sent_time = datetime.datetime.now(datetime.timezone.utc)
                        weekly_schedule[idx]["evening_dispatched_at"] = eve_sent_time

                        automations_col.update_one(
                            {"_id": auto["_id"]},
                            {"$set": {
                                f"weekly_schedule.{idx}.evening_dispatched_at": eve_sent_time,
                                "updated_at": eve_sent_time
                            }}
                        )
                        print(f"🌙 [Notifier] Sent 2nd evening follow-up email for {course_name} (Week {week_num}) to {user_email}")
                    except Exception as err:
                        print(f"⚠️ [Notifier] Evening follow-up email failed for Week {week_num}: {err}")
    else:
        # In-memory storage mode worker
        for key, auto in list(memory_automations.items()):
            notebook_id = auto.get("notebook_id")
            user_email = auto.get("user_email")
            course_name = auto.get("course_name")
            weekly_schedule = auto.get("weekly_schedule", [])

            for idx, item in enumerate(weekly_schedule):
                status = item.get("status")
                prim_trigger = item.get("primary_trigger_timestamp") or item.get("actual_trigger_timestamp") or item.get("revision_trigger_timestamp")
                eve_trigger = item.get("evening_trigger_timestamp")
                enable_eve = item.get("enable_evening_reminder", True)
                eve_dispatched = item.get("evening_dispatched_at")

                if isinstance(prim_trigger, str):
                    try:
                        prim_trigger = datetime.datetime.fromisoformat(prim_trigger)
                    except Exception:
                        prim_trigger = None
                if isinstance(eve_trigger, str):
                    try:
                        eve_trigger = datetime.datetime.fromisoformat(eve_trigger)
                    except Exception:
                        eve_trigger = None

                if status == "PENDING" and prim_trigger and prim_trigger <= now_utc:
                    item["status"] = "PROCESSING"
                    week_num = item.get("week_number")
                    topic_title = item.get("topic_title")

                    try:
                        send_revision_email(
                            user_email=user_email,
                            course_name=course_name,
                            week_number=week_num,
                            topic_title=topic_title,
                            notebook_id=notebook_id,
                            is_evening_reminder=False
                        )
                        sent_time = datetime.datetime.now(datetime.timezone.utc)
                        item["status"] = "REMINDER_SENT"
                        item["email_dispatched_at"] = sent_time
                        item["notification_sent_at"] = sent_time
                        stats = calculate_progress_stats(weekly_schedule, auto.get("total_weeks"))
                        auto["next_scheduled_trigger"] = stats["next_scheduled_trigger"]
                        print(f"📧 [Notifier] Memory mode: Sent 1st revision email for {course_name} (Week {week_num})")
                    except Exception as err:
                        item["status"] = "FAILED"
                        item["last_error"] = str(err)
                        print(f"⚠️ [Notifier] Memory mode: Email delivery failed: {err}")

                elif status == "REMINDER_SENT" and enable_eve and eve_dispatched is None and eve_trigger and eve_trigger <= now_utc:
                    week_num = item.get("week_number")
                    topic_title = item.get("topic_title")
                    try:
                        send_revision_email(
                            user_email=user_email,
                            course_name=course_name,
                            week_number=week_num,
                            topic_title=topic_title,
                            notebook_id=notebook_id,
                            is_evening_reminder=True
                        )
                        item["evening_dispatched_at"] = datetime.datetime.now(datetime.timezone.utc)
                        print(f"🌙 [Notifier] Memory mode: Sent 2nd evening follow-up for {course_name} (Week {week_num})")
                    except Exception as err:
                        print(f"⚠️ [Notifier] Memory mode: Evening follow-up failed: {err}")
