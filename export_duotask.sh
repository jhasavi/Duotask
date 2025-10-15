#!/bin/bash
echo "Zipping DuoTask project..."

zip -r duotask_backup.zip ./task_bubble \
  -x "*.dart_tool/*" "*.build/*" "*.idea/*" "*build/*" \
  -x "*.DS_Store" "*.lock" ".git/*" ".vscode/*" "node_modules/*"

echo "✅ Backup created: duotask_backup.zip"

