import os
import sys
import json
from pymongo import MongoClient
import config

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

_client = None
_db = None
USING_MONGO = False

# Persistent file storage setup
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data_storage")
os.makedirs(DATA_DIR, exist_ok=True)
AUTOMATIONS_FILE = os.path.join(DATA_DIR, "automations.json")
TIMETABLES_FILE = os.path.join(DATA_DIR, "timetables.json")

def _load_automations_file():
    if os.path.exists(AUTOMATIONS_FILE):
        try:
            with open(AUTOMATIONS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ [Database] Error reading automations.json: {e}")
    return {}

def _load_timetables_file():
    if os.path.exists(TIMETABLES_FILE):
        try:
            with open(TIMETABLES_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ [Database] Error reading timetables.json: {e}")
    return {}

def save_memory_automations():
    try:
        def json_serial(obj):
            if hasattr(obj, 'isoformat'):
                return obj.isoformat()
            return str(obj)

        with open(AUTOMATIONS_FILE, "w", encoding="utf-8") as f:
            json.dump(memory_automations, f, ensure_ascii=False, indent=2, default=json_serial)
    except Exception as e:
        print(f"⚠️ [Database] Error saving automations.json: {e}")

def save_memory_timetables():
    try:
        def json_serial(obj):
            if hasattr(obj, 'isoformat'):
                return obj.isoformat()
            return str(obj)

        with open(TIMETABLES_FILE, "w", encoding="utf-8") as f:
            json.dump(memory_timetables, f, ensure_ascii=False, indent=2, default=json_serial)
    except Exception as e:
        print(f"⚠️ [Database] Error saving timetables.json: {e}")

# Load persisted automations & timetables into memory dictionaries
memory_automations = _load_automations_file()
memory_timetables = _load_timetables_file()

def get_db():
    global _client, _db, USING_MONGO
    if _db is not None:
        return _db, USING_MONGO

    try:
        _client = MongoClient(config.MONGODB_URI, serverSelectionTimeoutMS=2000)
        _client.server_info()
        _db = _client[config.DB_NAME]
        USING_MONGO = True
        print(f"✅ [Database] Successfully connected to MongoDB: {config.DB_NAME}")
    except Exception as e:
        print(f"⚠️ [Database] MongoDB connection failed ({e}). Using persistent local JSON file storage.")
        USING_MONGO = False
        _db = None

    return _db, USING_MONGO

def get_automations_col():
    db, is_mongo = get_db()
    if is_mongo and db is not None:
        return db["course_automations"]
    return None

def get_timetables_col():
    db, is_mongo = get_db()
    if is_mongo and db is not None:
        return db["user_timetables"]
    return None
