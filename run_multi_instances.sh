#!/bin/bash

# Launch DuoTask on multiple platforms for pairing/auth testing.
# Opens one instance each on Chrome, iOS, and Android (when available).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter is not installed or not in PATH."
  exit 1
fi

echo "🚀 DuoTask Multi-Instance Launcher"
echo "=================================="
echo "Project: $PROJECT_ROOT"
echo ""

echo "🔎 Detecting devices..."
DEVICES_OUTPUT="$(flutter devices)"
echo "$DEVICES_OUTPUT"
echo ""

extract_id() {
  local pattern="$1"
  echo "$DEVICES_OUTPUT" | awk -F '•' -v p="$pattern" '
    BEGIN { IGNORECASE=1 }
    $0 ~ p {
      id=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      print id
      exit
    }
  '
}

CHROME_ID="$(extract_id "Chrome")"
IOS_ID="$(extract_id "(iPhone|ios)")"
ANDROID_ID="$(extract_id "(android|emulator)")"

if [ -z "$CHROME_ID" ] && [ -z "$IOS_ID" ] && [ -z "$ANDROID_ID" ]; then
  echo "❌ No runnable Chrome/iOS/Android targets found."
  echo ""
  echo "Try:"
  echo "1. Start Chrome"
  echo "2. Start iOS Simulator: open -a Simulator"
  echo "3. Start Android emulator via Android Studio Device Manager"
  echo "4. Run this script again"
  exit 1
fi

launch_with_terminal() {
  local name="$1"
  local cmd="$2"

  osascript <<EOF >/dev/null
  tell application "Terminal"
    activate
    do script "cd '$PROJECT_ROOT'; echo '▶ Starting $name...'; $cmd"
  end tell
EOF
}

launch_target() {
  local target_name="$1"
  local target_id="$2"
  local extra_args="$3"

  if [ -z "$target_id" ]; then
    echo "⏭️  Skipping $target_name (device not found)"
    return
  fi

  echo "✅ Launching $target_name on device id: $target_id"
  launch_with_terminal "$target_name" "flutter run -d $target_id $extra_args"
}

# Web gets a fixed port for easier repeated testing.
launch_target "Chrome" "$CHROME_ID" "--web-port 3000"
launch_target "iOS" "$IOS_ID" ""
launch_target "Android" "$ANDROID_ID" ""

echo ""
echo "🧪 Instances launched."
echo "Tips:"
echo "- Use separate test accounts per device for pairing/auth verification."
echo "- Chrome is on http://localhost:3000 (if Chrome target was found)."
echo "- Stop each run with Ctrl+C in its Terminal window."
