from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("RoadSOSEmergencyAPI")

app = FastAPI(
    title="RoadSOS API",
    description="Backend API for IIT-M RoadSOS - Road Emergency & Rescue Operating System",
    version="1.0.0"
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class EmergencyPayload(BaseModel):
    user_name: str
    coordinates: Dict[str, float]
    address: str
    timestamp: str
    emergency_type: str
    medical_summary: Optional[str] = None
    notified_contacts: Optional[List[str]] = None

class EmailRequest(BaseModel):
    to: List[str]
    subject: str
    payload: EmergencyPayload

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "RoadSOS Emergency API Gateway",
        "version": "1.0.0",
        "documentation": "/docs"
    }

@app.post("/api/v1/emergency/email")
def send_emergency_email(request: EmailRequest):
    logger.info(f"[ROADSOS] Received emergency email request for: {request.to}")
    
    html_content = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333333;">
        <div style="max-width: 600px; margin: 0 auto; border: 1px solid #dddddd; padding: 20px; border-radius: 8px;">
          <h2 style="color: #dc3545; border-bottom: 2px solid #dc3545; padding-bottom: 10px;">🚨 CRITICAL ROAD EMERGENCY ALERT - RoadSOS</h2>
          <p>A critical road emergency has been manually triggered/detected for user <strong>{request.payload.user_name}</strong>.</p>
          
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
            <tr style="background-color: #f8f9fa;">
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold; width: 150px;">User Name</td>
              <td style="padding: 10px; border: 1px solid #eeeeee;">{request.payload.user_name}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold;">Emergency Type</td>
              <td style="padding: 10px; border: 1px solid #eeeeee; text-transform: uppercase; color: #dc3545; font-weight: bold;">{request.payload.emergency_type}</td>
            </tr>
            <tr style="background-color: #f8f9fa;">
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold;">Timestamp</td>
              <td style="padding: 10px; border: 1px solid #eeeeee;">{request.payload.timestamp}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold;">Coordinates</td>
              <td style="padding: 10px; border: 1px solid #eeeeee; font-family: monospace;">{request.payload.coordinates.get('lat', 0.0)}, {request.payload.coordinates.get('lng', 0.0)}</td>
            </tr>
            <tr style="background-color: #f8f9fa;">
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold;">Address</td>
              <td style="padding: 10px; border: 1px solid #eeeeee;">{request.payload.address}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border: 1px solid #eeeeee; font-weight: bold;">Medical Summary</td>
              <td style="padding: 10px; border: 1px solid #eeeeee;">{request.payload.medical_summary or 'No medical profile details recorded.'}</td>
            </tr>
          </table>
          
          <div style="background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; padding: 15px; border-radius: 4px; margin-top: 20px;">
            <strong>Emergency Action Required:</strong> Please contact them immediately or coordinate local rescuers.
          </div>
          <hr style="border: 0; border-top: 1px solid #dddddd; margin: 20px 0;" />
          <p style="font-size: 11px; color: #777777; text-align: center;">Sent automatically via RoadSOS — Emergency Rescue & Operating System</p>
        </div>
      </body>
    </html>
    """

    smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USERNAME", "")
    smtp_pass = os.getenv("SMTP_PASSWORD", "")
    smtp_sender = os.getenv("SMTP_SENDER", "emergency-alert@roadsos.org")

    if not smtp_user or not smtp_pass:
        logger.warning("[ROADSOS][MOCK_EMAIL] SMTP credentials not set. Logging emergency payload:")
        logger.info(f"TO: {request.to}")
        logger.info(f"SUBJECT: {request.subject}")
        logger.info(f"BODY:\n{html_content}")
        return {
            "status": "success",
            "message": "SMTP credentials absent. Email logged successfully (Developer Sandbox Mode).",
            "recipients": request.to
        }

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = request.subject
        msg["From"] = smtp_sender
        msg["To"] = ", ".join(request.to)
        msg.attach(MIMEText(html_content, "html"))

        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.sendmail(smtp_sender, request.to, msg.as_string())

        logger.info(f"[ROADSOS] Transactional email sent successfully to {request.to}")
        return {"status": "success", "message": "Emails sent successfully."}
    except Exception as e:
        logger.error(f"[ROADSOS] Failed to send email via SMTP smtplib: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"SMTP transmission failed: {str(e)}"
        )
