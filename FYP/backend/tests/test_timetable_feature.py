import sys
import os
import unittest
import json
import datetime

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
from blueprints.timetable import normalize_time_str, get_course_lecture_timing, export_ics
from database.connection import memory_timetables

class TestTimetableFeature(unittest.TestCase):
    def setUp(self):
        self.sample_user = "student@utar.edu.my"
        self.sample_timetable = {
            "user_email": self.sample_user,
            "semester_start_date": "2026-09-07T00:00:00Z",
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
                },
                {
                    "course_id": "UCCB1013",
                    "course_name": "FUNDAMENTALS OF BUSINESS SYSTEMS",
                    "classes": [
                        {
                            "type": "L",
                            "day": "Wed",
                            "start_time": "12:00",
                            "end_time": "14:00",
                            "venue": "LDK1",
                            "group": "1"
                        }
                    ]
                }
            ]
        }
        memory_timetables[self.sample_user] = self.sample_timetable

    def test_normalize_time(self):
        self.assertEqual(normalize_time_str("2:00 PM"), "14:00")
        self.assertEqual(normalize_time_str("8:00 AM"), "08:00")
        self.assertEqual(normalize_time_str("12:00 PM"), "12:00")
        self.assertEqual(normalize_time_str("14:30"), "14:30")

    def test_get_course_lecture_timing(self):
        # Last lecture for UCCD1024 is Tuesday 08:00 - 10:00 (since Monday is 14:00-15:00 and Tuesday is later day)
        timing = get_course_lecture_timing(self.sample_user, "UCCD1024")
        self.assertIsNotNone(timing)
        self.assertEqual(timing["course_id"], "UCCD1024")
        self.assertEqual(timing["class_day"], "Tuesday")
        self.assertEqual(timing["class_start_time"], "08:00")
        self.assertEqual(timing["class_end_time"], "10:00")

    def test_ics_generation(self):
        from app import app
        with app.test_client() as client:
            res = client.post("/api/timetable/export-ics", json={
                "user_email": self.sample_user,
                "course_ids": ["UCCD1024"]
            })
            self.assertEqual(res.status_code, 200)
            self.assertEqual(res.mimetype, "text/calendar")
            ics_text = res.data.decode("utf-8")
            self.assertIn("BEGIN:VCALENDAR", ics_text)
            self.assertIn("UCCD1024", ics_text)
            self.assertIn("DATA STRUCTURE", ics_text)

if __name__ == "__main__":
    unittest.main()
