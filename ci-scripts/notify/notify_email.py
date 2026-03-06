#!/usr/bin/env python3
# 邮件通知脚本（QQ 邮箱版）
# 用途：在 CI 结束后发送一封简单的构建结果邮件
#
# 使用方式示例：
#   SMTP_HOST=smtp.qq.com \
#   SMTP_PORT=465 \
#   SMTP_USER=你的qq邮箱地址 \
#   SMTP_PASS=你的授权码 \
#   MAIL_TO=收件人邮箱 \
#   python3 ci-scripts/notify/notify_email.py --status success
#
# fastlane 中会这样调用：
#   python3 ci-scripts/notify/notify_email.py --status success
#   python3 ci-scripts/notify/notify_email.py --status failure

import argparse
import os
import smtplib
import ssl
from email.mime.text import MIMEText
from email.header import Header
from typing import Optional


def build_message(subject: str, body: str, mail_from: str, mail_to: str) -> MIMEText:
    msg = MIMEText(body, "plain", "utf-8")
    msg["From"] = mail_from
    msg["To"] = mail_to
    msg["Subject"] = Header(subject, "utf-8")
    return msg


def send_mail(
    host: str,
    port: int,
    user: str,
    password: str,
    mail_to: str,
    subject: str,
    body: str,
) -> None:
    msg = build_message(subject, body, user, mail_to)

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(host, port, context=context, timeout=15) as server:
        server.login(user, password)
        server.sendmail(user, [mail_to], msg.as_string())


def main() -> None:
    parser = argparse.ArgumentParser(description="Send build result email (QQ SMTP)")
    parser.add_argument("--status", required=True, choices=["success", "failure"], help="build status")
    args = parser.parse_args()

    host = os.environ.get("SMTP_HOST", "smtp.qq.com")
    port = int(os.environ.get("SMTP_PORT", "465"))
    user = os.environ.get("SMTP_USER")  # QQ 邮箱地址
    password = os.environ.get("SMTP_PASS")  # QQ 邮箱授权码
    mail_to = os.environ.get("MAIL_TO")  # 收件人邮箱（建议先填你自己）

    if not (user and password and mail_to):
        print("[notify_email] SMTP_USER / SMTP_PASS / MAIL_TO 未配置，跳过发送。")
        return

    job_name = os.environ.get("JOB_NAME", "-")
    build_number = os.environ.get("BUILD_NUMBER", "-")
    build_url = os.environ.get("BUILD_URL", "-")
    git_branch = os.environ.get("GIT_BRANCH", os.environ.get("BRANCH_NAME", "-"))

    ok = args.status == "success"
    status_text = "成功" if ok else "失败"
    subject = f"[Demo CI] 构建{status_text} - {job_name} #{build_number}"

    lines = [
        f"Demo CI 构建{status_text}",
        "",
        f"Job: {job_name}",
        f"Build: #{build_number}",
        f"Branch: {git_branch}",
        f"URL: {build_url}",
    ]
    body = "\n".join(lines)

    try:
        send_mail(host, port, user, password, mail_to, subject, body)
        print("[notify_email] 邮件发送成功。")
    except Exception as e:
        print(f"[notify_email] 邮件发送失败: {e}")
        # 不抛异常，避免通知失败导致 CI 失败


if __name__ == "__main__":
    main()
