import os
import sys
import unittest
import datetime
import pytz

# Add backend directory to sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from utils.scheduler_utils import calculate_weekly_schedule
from services.syllabus_parser import validate_and_normalize_topics, generate_fallback_topics
from models.automation import validate_automation_request

class TestScheduleCalculator(unittest.TestCase):

    def test_schedule_14_weeks_with_break(self):
        topics = generate_fallback_topics("CS101", 14)
        schedule = calculate_weekly_schedule(
            semester_start_date_str="2026-09-07",  # A Monday
            total_weeks=14,
            class_day="Monday",
            class_start_time_str="09:00",
            class_end_time_str="11:00",
            has_break_week=True,
            weekly_topics=topics,
            timezone_str="Asia/Kuala_Lumpur",
            revision_delay_hours=24
        )

        self.assertEqual(len(schedule), 14)
        self.assertEqual(schedule[0]["week_number"], 1)
        self.assertEqual(schedule[13]["week_number"], 14)

        # Check revision trigger is 24 hours after class end
        first_item = schedule[0]
        end_ts = first_item["class_end_timestamp"]
        trigger_ts = first_item["revision_trigger_timestamp"]
        self.assertEqual(trigger_ts - end_ts, datetime.timedelta(hours=24))

        # Check break week displacement (Week 6 to Week 7 has 2 weeks gap instead of 1)
        week6_start = schedule[5]["class_start_timestamp"]
        week7_start = schedule[6]["class_start_timestamp"]
        self.assertEqual(week7_start - week6_start, datetime.timedelta(days=14))

    def test_schedule_12_weeks_no_break(self):
        topics = generate_fallback_topics("MATH201", 12)
        schedule = calculate_weekly_schedule(
            semester_start_date_str="2026-09-07",
            total_weeks=12,
            class_day="Wednesday",
            class_start_time_str="14:00",
            class_end_time_str="16:00",
            has_break_week=False,
            weekly_topics=topics,
            timezone_str="Asia/Kuala_Lumpur",
            revision_delay_hours=12
        )

        self.assertEqual(len(schedule), 12)
        first_item = schedule[0]
        end_ts = first_item["class_end_timestamp"]
        trigger_ts = first_item["revision_trigger_timestamp"]
        self.assertEqual(trigger_ts - end_ts, datetime.timedelta(hours=12))

    def test_dual_reminders_schedule(self):
        topics = generate_fallback_topics("MATH201", 12)
        schedule = calculate_weekly_schedule(
            semester_start_date_str="2026-09-07",
            total_weeks=12,
            class_day="Monday",
            class_start_time_str="10:00",
            class_end_time_str="12:00",
            has_break_week=False,
            weekly_topics=topics,
            timezone_str="Asia/Kuala_Lumpur",
            primary_reminder_time_str="18:00",
            enable_evening_reminder=True,
            evening_reminder_time_str="21:00"
        )

        first_item = schedule[0]
        self.assertEqual(first_item["primary_trigger_timestamp"].hour, 18)
        self.assertEqual(first_item["evening_trigger_timestamp"].hour, 21)
        self.assertTrue(first_item["enable_evening_reminder"])

    def test_presentation_demo_mode_schedule(self):
        topics = [{"week_number": 1, "topic_title": "Intro"}]
        schedule = calculate_weekly_schedule(
            semester_start_date_str="2026-09-07",
            total_weeks=14,
            class_day="Thursday",  # course is Thursday, but demo is today
            class_start_time_str="10:00",
            class_end_time_str="12:00",
            has_break_week=False,
            weekly_topics=topics,
            timezone_str="Asia/Kuala_Lumpur",
            is_demo_mode=True,
            demo_minutes=2
        )

        first_item = schedule[0]
        now = datetime.datetime.now()
        trigger = first_item["primary_trigger_timestamp"]
        # Must be on today's date
        self.assertEqual(trigger.date(), now.date())
        # Difference between trigger and now should be roughly 2 minutes (between 1 and 3 mins)
        diff_secs = (trigger.replace(tzinfo=None) - now).total_seconds()
        self.assertTrue(0 <= diff_secs <= 180, f"Expected diff ~120s, got {diff_secs}")



class TestSyllabusParserValidation(unittest.TestCase):

    def test_valid_json_normalization(self):
        raw_json = {
            "course_name": "Physics 101",
            "weekly_topics": [
                {"week_number": 1, "topic_title": "Kinematics", "key_concepts": ["Velocity", "Acceleration"]},
                {"week_number": 2, "topic_title": "Dynamics", "key_concepts": ["Force", "Mass"]}
            ]
        }
        topics, warnings, source = validate_and_normalize_topics(raw_json, 12, "Physics 101")
        self.assertEqual(len(topics), 12)
        self.assertEqual(topics[0]["topic_title"], "Kinematics")
        self.assertEqual(topics[1]["topic_title"], "Dynamics")
        self.assertEqual(source, "gemini")

    def test_malformed_json_fallback(self):
        raw_json = "Not a dict"
        topics, warnings, source = validate_and_normalize_topics(raw_json, 14, "Chemistry")
        self.assertEqual(len(topics), 14)
        self.assertEqual(source, "fallback")
        self.assertTrue(any("not a valid JSON object" in w for w in warnings))


class TestAutomationRequestValidation(unittest.TestCase):

    def test_invalid_weeks_and_times(self):
        form = {
            "notebook_id": "nb_123",
            "course_name": "CS",
            "user_email": "student@example.com",
            "class_day": "Funday",  # Invalid
            "class_start_time": "14:00",
            "class_end_time": "10:00",  # End earlier than start
            "total_weeks": "10",  # Outside 12,13,14
            "semester_start_date": "invalid-date"
        }
        class DummyFile:
            filename = "syllabus.pdf"

        files = {"syllabus": DummyFile()}
        errors = validate_automation_request(form, files)

        self.assertIn("class_day must be one of ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']", errors)
        self.assertIn("class_end_time must be later than class_start_time", errors)
        self.assertIn("total_weeks must be 12, 13, or 14", errors)
        self.assertIn("semester_start_date must be in YYYY-MM-DD format", errors)


if __name__ == "__main__":
    unittest.main()
