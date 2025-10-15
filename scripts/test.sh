#!/usr/bin/env bash
set -euo pipefail

echo "Running flutter test..."
flutter --version
flutter pub get
flutter test -r compact
