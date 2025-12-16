"""
Email service for sending verification, password reset, and welcome emails
"""

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
import logging

logger = logging.getLogger(__name__)

# Email configuration from environment
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "noreply@meterscience.org")
APP_URL = os.getenv("APP_URL", "http://localhost:8000")
APP_NAME = "MeterScience"


def get_smtp_connection():
    """Create and return an SMTP connection"""
    try:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()
        if SMTP_USER and SMTP_PASSWORD:
            server.login(SMTP_USER, SMTP_PASSWORD)
        return server
    except Exception as e:
        logger.error(f"Failed to connect to SMTP server: {e}")
        raise


def send_email(to_email: str, subject: str, html_content: str, text_content: Optional[str] = None) -> bool:
    """
    Send an email with HTML content

    Args:
        to_email: Recipient email address
        subject: Email subject
        html_content: HTML email content
        text_content: Plain text fallback (optional)

    Returns:
        True if email sent successfully, False otherwise
    """
    try:
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = FROM_EMAIL
        msg['To'] = to_email

        # Add text and HTML parts
        if text_content:
            msg.attach(MIMEText(text_content, 'plain'))
        msg.attach(MIMEText(html_content, 'html'))

        # Send email
        server = get_smtp_connection()
        server.send_message(msg)
        server.quit()

        logger.info(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email to {to_email}: {e}")
        return False


def get_email_template(content: str) -> str:
    """
    Wrap email content in a branded template

    Args:
        content: HTML content to wrap

    Returns:
        Complete HTML email with styling
    """
    return f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{APP_NAME}</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="padding: 40px 40px 20px 40px; text-align: center; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px 8px 0 0;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: bold;">
                                ⚡ {APP_NAME}
                            </h1>
                            <p style="margin: 10px 0 0 0; color: #ffffff; font-size: 16px; opacity: 0.9;">
                                Citizen Science for Utility Data
                            </p>
                        </td>
                    </tr>

                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px;">
                            {content}
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="padding: 20px 40px 40px 40px; text-align: center; border-top: 1px solid #e5e5e5;">
                            <p style="margin: 0; color: #666666; font-size: 14px;">
                                {APP_NAME} - Empowering communities through data
                            </p>
                            <p style="margin: 10px 0 0 0; color: #999999; font-size: 12px;">
                                This email was sent from {FROM_EMAIL}
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""


def send_verification_email(to_email: str, verification_token: str) -> bool:
    """
    Send email verification link

    Args:
        to_email: Recipient email address
        verification_token: Unique verification token

    Returns:
        True if email sent successfully
    """
    verification_url = f"{APP_URL}/api/v1/users/verify-email?token={verification_token}"

    content = f"""
        <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">
            Verify Your Email Address
        </h2>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Thank you for joining MeterScience! To complete your registration and start contributing to citizen science, please verify your email address.
        </p>

        <p style="margin: 0 0 30px 0; text-align: center;">
            <a href="{verification_url}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: bold;">
                Verify Email Address
            </a>
        </p>

        <p style="margin: 0 0 10px 0; color: #999999; font-size: 14px; line-height: 1.5;">
            Or copy and paste this link into your browser:
        </p>
        <p style="margin: 0 0 20px 0; color: #667eea; font-size: 14px; word-break: break-all;">
            {verification_url}
        </p>

        <p style="margin: 0; color: #666666; font-size: 14px; line-height: 1.5;">
            This verification link will expire in 24 hours. If you didn't create a MeterScience account, you can safely ignore this email.
        </p>
    """

    html = get_email_template(content)
    text = f"""
Verify Your Email Address

Thank you for joining MeterScience! To complete your registration, please verify your email address by clicking the link below:

{verification_url}

This verification link will expire in 24 hours. If you didn't create a MeterScience account, you can safely ignore this email.

---
MeterScience - Empowering communities through data
"""

    return send_email(to_email, f"Verify your {APP_NAME} account", html, text)


def send_password_reset_email(to_email: str, reset_token: str, display_name: str) -> bool:
    """
    Send password reset link

    Args:
        to_email: Recipient email address
        reset_token: Unique password reset token
        display_name: User's display name

    Returns:
        True if email sent successfully
    """
    reset_url = f"{APP_URL}/reset-password?token={reset_token}"

    content = f"""
        <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">
            Reset Your Password
        </h2>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Hi {display_name},
        </p>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            We received a request to reset your password for your MeterScience account. Click the button below to create a new password.
        </p>

        <p style="margin: 0 0 30px 0; text-align: center;">
            <a href="{reset_url}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: bold;">
                Reset Password
            </a>
        </p>

        <p style="margin: 0 0 10px 0; color: #999999; font-size: 14px; line-height: 1.5;">
            Or copy and paste this link into your browser:
        </p>
        <p style="margin: 0 0 20px 0; color: #667eea; font-size: 14px; word-break: break-all;">
            {reset_url}
        </p>

        <p style="margin: 0; color: #666666; font-size: 14px; line-height: 1.5;">
            This password reset link will expire in 24 hours. If you didn't request a password reset, you can safely ignore this email - your password will not be changed.
        </p>
    """

    html = get_email_template(content)
    text = f"""
Reset Your Password

Hi {display_name},

We received a request to reset your password for your MeterScience account. Click the link below to create a new password:

{reset_url}

This password reset link will expire in 24 hours. If you didn't request a password reset, you can safely ignore this email.

---
MeterScience - Empowering communities through data
"""

    return send_email(to_email, f"Reset your {APP_NAME} password", html, text)


def send_welcome_email(to_email: str, display_name: str) -> bool:
    """
    Send welcome email to new verified users

    Args:
        to_email: Recipient email address
        display_name: User's display name

    Returns:
        True if email sent successfully
    """
    content = f"""
        <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">
            Welcome to MeterScience!
        </h2>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Hi {display_name},
        </p>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Your email has been verified! You're now ready to start contributing to citizen science through utility meter readings.
        </p>

        <h3 style="margin: 30px 0 15px 0; color: #333333; font-size: 18px;">
            Getting Started
        </h3>

        <ul style="margin: 0 0 20px 0; padding-left: 20px; color: #666666; font-size: 16px; line-height: 1.8;">
            <li>📱 <strong>Set up your first meter</strong> - Configure your utility meters in the app</li>
            <li>📸 <strong>Scan and submit readings</strong> - Use our OCR technology for quick data capture</li>
            <li>✓ <strong>Verify others' readings</strong> - Build trust score by helping the community</li>
            <li>🏆 <strong>Earn XP and badges</strong> - Level up as you contribute more data</li>
            <li>📊 <strong>View neighborhood stats</strong> - See aggregated data from your area</li>
        </ul>

        <h3 style="margin: 30px 0 15px 0; color: #333333; font-size: 18px;">
            Your Referral Code
        </h3>

        <p style="margin: 0 0 10px 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Invite friends to earn rewards! Share your referral code:
        </p>

        <p style="margin: 0 0 30px 0; text-align: center;">
            <span style="display: inline-block; padding: 14px 32px; background-color: #f0f0f0; color: #333333; border-radius: 6px; font-size: 24px; font-weight: bold; font-family: monospace;">
                [Check app for code]
            </span>
        </p>

        <p style="margin: 0 0 20px 0; color: #666666; font-size: 14px; line-height: 1.5;">
            <strong>Referral Rewards:</strong><br>
            • 1 referral = 1 month Neighbor tier free<br>
            • 5 referrals = 25% off forever<br>
            • 10 referrals = Block tier for life<br>
            • 25 referrals = District tier for life
        </p>

        <p style="margin: 30px 0 0 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Questions? Reply to this email or check our help center.
        </p>

        <p style="margin: 20px 0 0 0; color: #666666; font-size: 16px; line-height: 1.5;">
            Happy meter reading!<br>
            <strong>The MeterScience Team</strong>
        </p>
    """

    html = get_email_template(content)
    text = f"""
Welcome to MeterScience!

Hi {display_name},

Your email has been verified! You're now ready to start contributing to citizen science through utility meter readings.

Getting Started:
• Set up your first meter - Configure your utility meters in the app
• Scan and submit readings - Use our OCR technology for quick data capture
• Verify others' readings - Build trust score by helping the community
• Earn XP and badges - Level up as you contribute more data
• View neighborhood stats - See aggregated data from your area

Your Referral Code:
Check the app for your unique referral code to invite friends!

Referral Rewards:
• 1 referral = 1 month Neighbor tier free
• 5 referrals = 25% off forever
• 10 referrals = Block tier for life
• 25 referrals = District tier for life

Questions? Reply to this email or check our help center.

Happy meter reading!
The MeterScience Team

---
MeterScience - Empowering communities through data
"""

    return send_email(to_email, f"Welcome to {APP_NAME}!", html, text)
