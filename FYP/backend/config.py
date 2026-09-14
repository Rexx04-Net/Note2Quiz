import os
import sys

try:
    from dotenv import load_dotenv
    # Load backend/.env
    load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
    # Load root .env
    load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
    load_dotenv()
except ImportError:
    pass

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not GEMINI_API_KEY:
    try:
        from api_secrets import GEMINI_API_KEY as SECRET_KEY
        GEMINI_API_KEY = SECRET_KEY
    except ImportError:
        pass

MONGODB_URI = os.environ.get("MONGODB_URI", "mongodb://localhost:27017/")
DB_NAME = os.environ.get("DB_NAME", "note2quiz_db")

GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")
if not GOOGLE_CLIENT_ID:
    try:
        from api_secrets import GOOGLE_CLIENT_ID as G_ID, GOOGLE_CLIENT_SECRET as G_SECRET
        GOOGLE_CLIENT_ID = G_ID
        GOOGLE_CLIENT_SECRET = G_SECRET
    except ImportError:
        pass

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
SMTP_USERNAME = os.environ.get("SMTP_USERNAME", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")

DEFAULT_TIMEZONE = os.environ.get("DEFAULT_TIMEZONE", "Asia/Kuala_Lumpur")
REVISION_DELAY_HOURS = int(os.environ.get("REVISION_DELAY_HOURS", 24))

def _detect_server_ip():
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def get_server_public_url():
    # 1. Explicit environment variable
    env_val = os.environ.get("SERVER_PUBLIC_URL")
    if env_val:
        return env_val.rstrip("/")
    # 2. Automatically query running ngrok tunnel if active
    try:
        import urllib.request
        import json
        with urllib.request.urlopen("http://127.0.0.1:4040/api/tunnels", timeout=0.8) as resp:
            data = json.loads(resp.read().decode())
            for tun in data.get("tunnels", []):
                pub = tun.get("public_url", "")
                if pub.startswith("https://"):
                    return pub.rstrip("/")
    except Exception:
        pass
    # 3. Fallback to LAN IP
    return f"http://{_detect_server_ip()}:5000"

SERVER_PUBLIC_URL = get_server_public_url()
