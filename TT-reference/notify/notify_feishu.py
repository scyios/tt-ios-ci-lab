#!/usr/bin/env python3
# 飞书机器人通知脚本（Demo 版）
# 使用方式示例：
#   FEISHU_WEBHOOK=... python3 notify_feishu.py --status success --text "构建成功"
#
# 依赖：
#   - 环境变量 FEISHU_WEBHOOK：飞书自定义机器人 Webhook URL
#   - 可选环境变量 FEISHU_SECRET：如果你将来启用「签名校验」，可在这里实现签名逻辑
#   - Jenkins 会自动提供 JOB_NAME / BUILD_NUMBER / BUILD_URL / GIT_BRANCH 等环境变量

import argparse
import json
import os
import sys
import time
import hmac
import hashlib
import base64
from typing import Optional


def build_sign(secret: str, timestamp: str) -> str:
    """如果配置了 FEISHU_SECRET，则按飞书文档计算签名。
    当前实现基于官方示例：sign = base64( HMAC-SHA256( f"{timestamp}\n{secret}", key=secret ) )
    如果你没开启「加签」，可以不设置 FEISHU_SECRET，脚本会跳过签名。
    """
    string_to_sign = f"{timestamp}\n{secret}".encode("utf-8")
    secret_bytes = secret.encode("utf-8")
    h = hmac.new(secret_bytes, string_to_sign, digestmod=hashlib.sha256).digest()
    return base64.b64encode(h).decode("utf-8")


def send_feishu_text(webhook: str, text: str, secret: Optional[str] = None) -> None:
    import urllib.request

    timestamp = str(int(time.time()))
    headers = {"Content-Type": "application/json; charset=utf-8"}

    body: dict = {
        "msg_type": "text",
        "content": {
            "text": text,
        },
    }

    # 如果配置了 FEISHU_SECRET，则附加 timestamp/sign 字段
    if secret:
        sign = build_sign(secret, timestamp)
        body.update({"timestamp": timestamp, "sign": sign})

    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(webhook, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp_body = resp.read().decode("utf-8")
        # 仅在需要时打印响应，避免打爆日志
        print(f"[notify_feishu] response: {resp.status} {resp_body}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Send Feishu robot notification for Demo CI")
    parser.add_argument("--status", required=True, choices=["success", "failure"], help="build status")
    parser.add_argument("--text", required=True, help="main text to send")
    args = parser.parse_args()

    webhook = os.environ.get("FEISHU_WEBHOOK")
    secret = os.environ.get("FEISHU_SECRET")  # 可选

    if not webhook:
        print("[notify_feishu] FEISHU_WEBHOOK not set, skip sending.", file=sys.stderr)
        return

    # 从 Jenkins / 环境中拼一些额外信息（如果存在）
    job_name = os.environ.get("JOB_NAME", "-")
    build_number = os.environ.get("BUILD_NUMBER", "-")
    build_url = os.environ.get("BUILD_URL", "-")
    git_branch = os.environ.get("GIT_BRANCH", os.environ.get("BRANCH_NAME", "-"))

    status_emoji = "✅" if args.status == "success" else "❌"
    title = f"{status_emoji} Demo CI 构建{ '成功' if args.status == 'success' else '失败' }"

    lines = [
        title,
        args.text,
        "",
        f"Job: {job_name} #{build_number}",
        f"Branch: {git_branch}",
        f"URL: {build_url}",
    ]
    full_text = "\n".join(lines)

    try:
        send_feishu_text(webhook, full_text, secret)
    except Exception as e:
        print(f"[notify_feishu] send error: {e}", file=sys.stderr)
        # 不抛出异常，避免通知失败导致 CI 失败


if __name__ == "__main__":
    main()
