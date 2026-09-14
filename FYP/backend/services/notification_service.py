import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import config

def send_revision_email(user_email, course_name, week_number, topic_title, notebook_id, is_evening_reminder=False):
    if not config.SMTP_USERNAME or not config.SMTP_PASSWORD:
        raise ValueError("SMTP credentials not configured (SMTP_USERNAME and SMTP_PASSWORD required).")

    if hasattr(config, "get_server_public_url"):
        base_server = config.get_server_public_url()
    else:
        base_server = getattr(config, "SERVER_PUBLIC_URL", "http://127.0.0.1:5000").rstrip("/")
    web_url = f"{base_server}/revision?notebook_id={notebook_id}&week_number={week_number}&user_email={user_email}"
    app_scheme_url = f"note2quiz://revision?notebook_id={notebook_id}&week_number={week_number}"

    if is_evening_reminder:
        subject = f"🌙 Note2Quiz Evening Wrap-Up: {course_name} - Week {week_number}"
        header_title = "Evening Study Wrap-Up!"
        header_desc = "Quick recall quiz before you wrap up for the night"
        intro_text = f"Quick reminder before your day ends! Take 2 minutes to review your lecture material for <strong>{course_name}</strong> to lock in key concepts."
    else:
        subject = f"📚 Note2Quiz Revision Alert: {course_name} - Week {week_number}"
        header_title = "Time for Revision!"
        header_desc = "Note2Quiz Automated Revision Engine"
        intro_text = f"It's time to review your recent lecture material for <strong>{course_name}</strong>!"

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f8; margin: 0; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }}
            .header {{ background: linear-gradient(135deg, {'#4f46e5, #7c3aed' if is_evening_reminder else '#6366f1, #8b5cf6'}); color: #ffffff; padding: 30px; text-align: center; }}
            .content {{ padding: 30px; color: #334155; line-height: 1.6; }}
            .topic-box {{ background: #f8fafc; border-left: 4px solid {'#7c3aed' if is_evening_reminder else '#6366f1'}; padding: 15px 20px; border-radius: 6px; margin: 20px 0; }}
            .button {{ display: inline-block; background: {'#7c3aed' if is_evening_reminder else '#6366f1'}; color: #ffffff !important; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: bold; margin-top: 20px; }}
            .footer {{ background: #f1f5f9; padding: 20px; text-align: center; font-size: 12px; color: #64748b; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1 style="margin:0; font-size:24px;">{header_title}</h1>
                <p style="margin:5px 0 0 0; opacity:0.9;">{header_desc}</p>
            </div>
            <div class="content">
                <p>Hello,</p>
                <p>{intro_text}</p>
                
                <div class="topic-box">
                    <h3 style="margin:0 0 8px 0; color:#1e293b;">Week {week_number}: {topic_title}</h3>
                    <p style="margin:0; font-size:14px; color:#64748b;">Reinforce key concepts and test your recall with a short quiz.</p>
                </div>
                
                <div style="text-align: center;">
                    <a href="{web_url}" class="button" target="_blank">🚀 Start Revision Quiz</a>
                </div>
                
                <p style="font-size:12px; color:#94a3b8; margin-top:25px; text-align:center;">
                    Direct Web Link: <a href="{web_url}" style="color:#6366f1;">{web_url}</a>
                </p>
            </div>
            <div class="footer">
                Note2Quiz Educational Platform &bull; Automated Syllabus & Timetable Revision Engine
            </div>
        </div>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = config.SMTP_USERNAME
    msg["To"] = user_email
    msg.attach(MIMEText(html_body, "html"))

    email_sent = False
    last_err = None

    # 1. Try SSL (port 465) first (frequently permitted when 587 is blocked)
    try:
        with smtplib.SMTP_SSL(config.SMTP_HOST, 465, timeout=5) as server:
            server.login(config.SMTP_USERNAME, config.SMTP_PASSWORD)
            server.sendmail(config.SMTP_USERNAME, user_email, msg.as_string())
            email_sent = True
    except Exception as e_ssl:
        last_err = e_ssl

    # 2. Fallback to TLS (port 587)
    if not email_sent:
        try:
            with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT, timeout=5) as server:
                server.starttls()
                server.login(config.SMTP_USERNAME, config.SMTP_PASSWORD)
                server.sendmail(config.SMTP_USERNAME, user_email, msg.as_string())
                email_sent = True
        except Exception as e_tls:
            last_err = e_tls

    if not email_sent:
        raise last_err

    return True
