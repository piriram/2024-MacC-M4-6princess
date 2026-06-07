#!/bin/bash
set -euo pipefail

# Frameet (6princess) TestFlight 업로드
# ColorCam 프로젝트의 app-store-connect export 방식과 동일한 흐름.
#
# 사용법:  scripts/upload_testflight.sh [BUILD_NUMBER]
#   BUILD_NUMBER 생략 시 pbxproj의 CURRENT_PROJECT_VERSION 값을 그대로 사용.

cd "$(dirname "$0")/.."

PROJECT="2024-MacC-M4-6princess/2024-MacC-M4-6princess.xcodeproj"
SCHEME="2024-MacC-M4-6princess"
TEAM_ID="557346W8SC"   # 이 Mac에 설치된 Apple Distribution 인증서의 팀
VERSION="2.2.2"
BUILD="${1:-202602230}"
ARCHIVE="build/Frameet-${VERSION}-b${BUILD}.xcarchive"

echo "▶︎ [1/2] archive → $ARCHIVE"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates

echo "▶︎ [2/2] export & upload to TestFlight"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/UploadOptions.plist \
  -exportPath "build/upload-${VERSION}-b${BUILD}" \
  -allowProvisioningUpdates

echo "✅ 업로드 완료 (build ${BUILD})"
