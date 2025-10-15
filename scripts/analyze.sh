#!/usr/bin/env bash
set -euo pipefail

echo "Running flutter analyze..."
flutter --version
flutter pub get
flutter analyze
