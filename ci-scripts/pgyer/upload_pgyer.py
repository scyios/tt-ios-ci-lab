#!/usr/bin/env python3
# 上传 IPA 到蒲公英，并输出下载短链接和二维码地址
#
# 依赖：
#   - 环境变量 PGYER_API_KEY（必需）：蒲公英后台的 _api_key
#   - 可选 PGYER_INSTALL_TYPE：安装方式（1=公开，2=密码，3=邀请），默认 1
#   - 可选 PGYER_PASSWORD：当安装方式为 2 时的安装密码
#   - 可选 PGYER_UPDATE_DESC：更新说明，不配置时可以用分支/构建号拼接
#
# 输出：
#   成功时在 stdout 输出一行："<buildShortcutUrl>|<buildQRCodeURL>"
#   失败时在 stderr 输出错误信息并 exit 1

import json
import os
import subprocess
import sys
from typing import Tuple


def get_repo_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, os.pardir, os.pardir))


def get_ipa_path(repo_root: str) -> str:
    ipa_path = os.path.join(repo_root, "DemoApp", "build", "ipa", "DemoApp.ipa")
    if not os.path.isfile(ipa_path):
        raise FileNotFoundError(f"未找到 IPA 文件: {ipa_path}")
    return ipa_path


def upload_to_pgyer(ipa_path: str) -> Tuple[str, str]:
    api_key = os.environ.get("PGYER_API_KEY")
    if not api_key:
        raise RuntimeError("PGYER_API_KEY 未配置（蒲公英 _api_key）")

    install_type = os.environ.get("PGYER_INSTALL_TYPE", "1")  # 默认公开安装
    password = os.environ.get("PGYER_PASSWORD")

    # 更新说明：优先使用 PGYER_UPDATE_DESC，否则用分支和构建号拼一段
    update_desc = os.environ.get("PGYER_UPDATE_DESC")
    if not update_desc:
        branch = os.environ.get("GIT_BRANCH") or os.environ.get("BRANCH_NAME") or "-"
        job = os.environ.get("JOB_NAME", "-")
        build = os.environ.get("BUILD_NUMBER", "-")
        update_desc = f"Demo CI 构建: {job} #{build} ({branch})"

    url = "https://api.pgyer.com/apiv2/app/upload"

    cmd = [
        "curl",
        "-sS",
        "-F",
        f"_api_key={api_key}",
        "-F",
        f"file=@{ipa_path}",
        "-F",
        f"buildInstallType={install_type}",
        "-F",
        f"buildUpdateDescription={update_desc}",
    ]

    if password:
        cmd.extend(["-F", f"buildPassword={password}"])

    cmd.append(url)

    try:
        result = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except FileNotFoundError:
        raise RuntimeError("未找到 curl 命令，请在系统中安装 curl 再重试。")

    if result.returncode != 0:
        raise RuntimeError(f"curl 调用失败: {result.stderr.strip()}")

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"解析蒲公英响应失败: {e}: {result.stdout[:200]}")

    if data.get("code") != 0:
        raise RuntimeError(f"蒲公英上传失败: code={data.get('code')} message={data.get('message')}")

    d = data.get("data") or {}
    shortcut = d.get("buildShortcutUrl") or ""
    qr_url = d.get("buildQRCodeURL") or ""

    if not shortcut:
        raise RuntimeError("蒲公英返回数据中缺少 buildShortcutUrl")

    return shortcut, qr_url


def main() -> None:
    try:
        repo_root = get_repo_root()
        ipa_path = get_ipa_path(repo_root)
        shortcut, qr_url = upload_to_pgyer(ipa_path)
    except Exception as e:
        print(f"[upload_pgyer] 错误: {e}", file=sys.stderr)
        sys.exit(1)

    # 输出给 fastlane 使用：一行 "shortcut|qr_url"
    # 其中下载页地址为 https://www.pgyer.com/<shortcut>
    print(f"{shortcut}|{qr_url}")


if __name__ == "__main__":
    main()
