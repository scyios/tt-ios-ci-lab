#!/bin/bash

###############################################################################
# DemoApp CI 打包脚本（Debug 构建版本）
#
# 参考自 TT-iOS 仓库中的脚本：
# - 主要参考：TT 根目录下的 archive.sh 中的 xcodebuild 调用方式
# - 思路类比：CI 中用于“只编译不打包”的那些 Stage / Job
#   （例如某些只做 build / analyze 的 Jenkins 阶段）
#
# 和 TT-iOS 仓库里的 archive.sh 的关系与区别：
# 1. 相同点（思路一致）：
#    - 都是通过 xcodebuild 命令行来驱动构建 / 打包，而不是手动点 Xcode。
#    - 都会指定 workspace / scheme / configuration 等参数，方便后面给 CI 调用。
# 2. 不同点（刻意简化，适合作为练手机器人）：
#    - 这里只做 Debug 构建（build），不做 .xcarchive + ipa 导出。
#      TT 的 archive.sh 会根据交互选择 ad-hoc / AppStore / enterprise，并自动导出 ipa。
#    - 不修改 Info.plist、Bundle ID、Team ID、App Group 等配置。
#      TT 的 archive.sh 会在打包前后动态修改这些字段（企业包 / 正式包切换）。
#    - 不处理 Zego SDK、ENABLE_BITCODE 等复杂开关。
#      这里仅保证基础构建通过，方便你专注学习 CI 流程本身。
# 3. 之后你可以在这个脚本基础上，逐步「加料」去靠近真实的 archive.sh 能力。
###############################################################################

set -euo pipefail

## 脚本根目录（即 tt-ios-ci-lab 仓库根）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 这里的脚本实际路径是 .../ci-scripts/build
# TT-iOS 的脚本一般放在仓库根或单层目录，这里我们手动回到仓库根（上上级目录）
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

## DemoApp 工程所在目录
APP_DIR="${REPO_ROOT}/DemoApp"

## 输出一些环境信息，方便在 CI 日志里排查问题
echo "===> 当前脚本路径: ${SCRIPT_DIR}"
echo "===> 仓库根目录:   ${REPO_ROOT}"
echo "===> DemoApp 目录: ${APP_DIR}"
echo

if [[ ! -d "${APP_DIR}" ]]; then
  echo "❌ 未找到 DemoApp 目录: ${APP_DIR}"
  exit 1
fi

cd "${APP_DIR}"

## 配置构建参数
WORKSPACE="DemoApp.xcworkspace"
SCHEME="DemoApp"
CONFIGURATION="Debug"
SDK="iphonesimulator"
# 这里的模拟器名称需要与你本机的可用设备一致
# 可通过 `xcrun simctl list devices` 查看，可根据需要修改为其它设备名称
DESTINATION="platform=iOS Simulator,name=iPhone 17"

if [[ ! -e "${WORKSPACE}" ]]; then
  echo "❌ 未找到 workspace: ${WORKSPACE}"
  echo "   请确认在 DemoApp 目录执行过 pod install，并生成 DemoApp.xcworkspace。"
  exit 1
fi

echo "===> Xcode 选择路径:"
xcode-select -print-path || true
echo

echo "===> 开始使用 xcodebuild 构建 DemoApp （Debug / 模拟器）"
echo "workspace   : ${WORKSPACE}"
echo "scheme      : ${SCHEME}"
echo "configuration: ${CONFIGURATION}"
echo "sdk         : ${SDK}"
echo "destination : ${DESTINATION}"
echo

## 说明：
## - 和 TT 的 archive.sh 不同，这里只做 build（编译），不做 archive（归档）。
##   方便快速验证：工程是否可在命令行环境下成功构建，是后续 CI 所有步骤的基础。

xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk "${SDK}" \
  -destination "${DESTINATION}" \
  clean build | tee "${APP_DIR}/build_debug.log"

BUILD_RESULT=$?

echo
if [[ ${BUILD_RESULT} -eq 0 ]]; then
  echo "✅ DemoApp Debug 构建成功。（日志已保存到 build_debug.log）"
else
  echo "❌ DemoApp Debug 构建失败，退出码: ${BUILD_RESULT}"
fi

exit ${BUILD_RESULT}

