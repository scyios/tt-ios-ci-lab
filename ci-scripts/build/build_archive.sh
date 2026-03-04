#!/bin/bash

###############################################################################
# DemoApp CI 打包脚本（Archive + 导出 IPA）
#
# 参考自 TT-iOS 仓库中的脚本：
# - 直接参考：TT 根目录下的 archive.sh
#   - 那个脚本也是通过 xcodebuild archive + -exportArchive 完成打包
#   - 同样需要 ExportOptions.plist 来控制导出方式（ad-hoc / app-store / enterprise）
# - 思路上也和 CI 上调用 build.py 的“打企业包 + 导出 ipa”是同一类操作
#
# 和 TT-iOS 仓库里的 archive.sh 的关系与区别：
# 1. 相同点（核心思路）：
#    - 都是通过 xcodebuild 命令行来完成：
#      (1) archive 生成 .xcarchive
#      (2) -exportArchive 导出 .ipa
#    - 都适合被 CI（Jenkins / GitHub Actions）直接调用，不需要手点 Xcode。
#
# 2. 不同点（主动简化的地方）：
#    - 这里只打一个固定方案：
#        配置：Release
#        方式：development（ExportOptionsPlist.method = "development"）
#      TT 的 archive.sh 会根据交互选择 ad-hoc / app-store / enterprise。
#    - 不会修改 Info.plist / Bundle ID / Team ID / App Group 等配置。
#      TT 的脚本会在打包前后动态切换企业包 / 正式包签名、显示名、Team。
#    - 不做 Zego SDK、ENABLE_BITCODE 等复杂开关。
#      这里专注把「最小打包链路」跑通，方便你理解 CI 如何衔接。
#
# 3. 后面你可以从这里开始，一点点往 TT 的完整能力靠拢：
#    - 增加不同打包模式（ad-hoc / app-store / enterprise）
#    - 根据参数切换 ExportOptionsPlist 的 method / provisioningProfiles
#    - 在打包前修改 Info.plist / project.pbxproj，再在结束后还原。
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 这里的脚本实际路径是 .../ci-scripts/build
# TT-iOS 的脚本一般放在仓库根或单层目录，这里我们手动回到仓库根（上上级目录）
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="${REPO_ROOT}/DemoApp"

echo "===> 当前脚本路径: ${SCRIPT_DIR}"
echo "===> 仓库根目录:   ${REPO_ROOT}"
echo "===> DemoApp 目录: ${APP_DIR}"
echo

if [[ ! -d "${APP_DIR}" ]]; then
  echo "❌ 未找到 DemoApp 目录: ${APP_DIR}"
  exit 1
fi

cd "${APP_DIR}"

WORKSPACE="DemoApp.xcworkspace"
SCHEME="DemoApp"
CONFIGURATION="Release"
SDK="iphoneos"

BUILD_DIR="${APP_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/DemoApp.xcarchive"
EXPORT_DIR="${BUILD_DIR}/ipa"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"

if [[ ! -e "${WORKSPACE}" ]]; then
  echo "❌ 未找到 workspace: ${WORKSPACE}"
  echo "   请确认在 DemoApp 目录执行过 pod install，并生成 DemoApp.xcworkspace。"
  exit 1
fi

mkdir -p "${BUILD_DIR}"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}"

echo "===> Xcode 选择路径:"
xcode-select -print-path || true
echo

echo "===> 1/3 生成 ExportOptions.plist（development 模式）"
cat > "${EXPORT_OPTIONS_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>compileBitcode</key>
  <false/>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
EOF

echo "ExportOptions.plist 写入完成: ${EXPORT_OPTIONS_PLIST}"
echo

echo "===> 2/3 使用 xcodebuild archive 生成 .xcarchive"
echo "workspace    : ${WORKSPACE}"
echo "scheme       : ${SCHEME}"
echo "configuration: ${CONFIGURATION}"
echo "sdk          : ${SDK}"
echo "archivePath  : ${ARCHIVE_PATH}"
echo

xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk "${SDK}" \
  -archivePath "${ARCHIVE_PATH}" \
  clean archive | tee "${BUILD_DIR}/archive.log"

ARCHIVE_RESULT=$?

if [[ ${ARCHIVE_RESULT} -ne 0 ]]; then
  echo
  echo "❌ archive 失败，退出码: ${ARCHIVE_RESULT}"
  exit ${ARCHIVE_RESULT}
fi

echo
echo "✅ archive 成功，产物路径：${ARCHIVE_PATH}"
echo

echo "===> 3/3 使用 xcodebuild -exportArchive 导出 IPA"
mkdir -p "${EXPORT_DIR}"

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -exportPath "${EXPORT_DIR}" | tee "${BUILD_DIR}/export.log"

EXPORT_RESULT=$?

echo
if [[ ${EXPORT_RESULT} -eq 0 ]]; then
  echo "✅ 导出 IPA 成功。"
  echo "   目录：${EXPORT_DIR}"
  echo "   建议检查该目录下的 DemoApp.ipa 是否存在。"
else
  echo "❌ 导出 IPA 失败，退出码: ${EXPORT_RESULT}"
fi

exit ${EXPORT_RESULT}

