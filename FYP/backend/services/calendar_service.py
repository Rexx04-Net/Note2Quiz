import config

try:
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    GOOGLE_CAL_AVAILABLE = True
except ImportError:
    GOOGLE_CAL_AVAILABLE = False

def sync_google_calendar(user_email, course_name, notebook_id, weekly_schedule, oauth_token=None):
    calendar_details = {
        "provider": "google",
        "calendar_id": None,
        "calendar_name": f"Note2Quiz - {course_name}"
    }
    warnings = []

    if not oauth_token:
        warnings.append("Google OAuth token not provided. Google Calendar sync skipped.")
        return calendar_details, warnings

    if not GOOGLE_CAL_AVAILABLE:
        warnings.append("googleapiclient/google-auth libraries not installed. Calendar sync skipped.")
        return calendar_details, warnings

    try:
        creds = Credentials(token=oauth_token)
        service = build("calendar", "v3", credentials=creds)

        # 1. Get or create calendar
        cal_list = service.calendarList().list().execute()
        target_cal_id = None
        target_summary = f"Note2Quiz - {course_name}"

        for item in cal_list.get("items", []):
            if item.get("summary") == target_summary:
                target_cal_id = item.get("id")
                break

        if not target_cal_id:
            new_cal = {
                "summary": target_summary,
                "timeZone": config.DEFAULT_TIMEZONE
            }
            created_cal = service.calendars().insert(body=new_cal).execute()
            target_cal_id = created_cal.get("id")

        calendar_details["calendar_id"] = target_cal_id

        # 2. Sync events idempotently
        for s in weekly_schedule:
            week_num = s["week_number"]
            topic = s["topic_title"]
            deep_link = f"note2quiz://revision?notebook_id={notebook_id}&week_number={week_num}"

            event_body = {
                "summary": f"Note2Quiz Revision - Week {week_num} - {topic}",
                "description": (
                    f"Course: {course_name}\n"
                    f"Notebook ID: {notebook_id}\n"
                    f"Week Number: {week_num}\n"
                    f"Deep Link: {deep_link}"
                ),
                "start": {
                    "dateTime": s["class_start_timestamp"].isoformat(),
                    "timeZone": config.DEFAULT_TIMEZONE,
                },
                "end": {
                    "dateTime": s["class_end_timestamp"].isoformat(),
                    "timeZone": config.DEFAULT_TIMEZONE,
                },
                "extendedProperties": {
                    "private": {
                        "notebook_id": notebook_id,
                        "course_name": course_name,
                        "week_number": str(week_num)
                    }
                }
            }

            event_id = s.get("calendar_event_id")
            if event_id:
                try:
                    updated_event = service.events().update(
                        calendarId=target_cal_id,
                        eventId=event_id,
                        body=event_body
                    ).execute()
                    s["calendar_event_id"] = updated_event.get("id")
                except Exception:
                    created_event = service.events().insert(
                        calendarId=target_cal_id,
                        body=event_body
                    ).execute()
                    s["calendar_event_id"] = created_event.get("id")
            else:
                created_event = service.events().insert(
                    calendarId=target_cal_id,
                    body=event_body
                ).execute()
                s["calendar_event_id"] = created_event.get("id")

        print(f"✅ [Calendar] Successfully synced {len(weekly_schedule)} events to Google Calendar '{target_summary}'")
    except Exception as e:
        warnings.append(f"Google Calendar API sync error: {e}")
        print(f"⚠️ [Calendar] Calendar sync failed: {e}")

    return calendar_details, warnings
