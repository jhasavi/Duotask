#!/bin/bash

# Kill any process using port 5000
echo "🔍 Checking for processes using port 5000..."
if lsof -i :5000 > /dev/null 2>&1; then
    echo "⚠️  Found processes using port 5000. Killing them..."
    lsof -ti :5000 | xargs kill -9
    sleep 2
    echo "✅ Killed processes on port 5000"
else
    echo "✅ Port 5000 is free"
fi

# Run Flutter web app on port 5000
echo "🚀 Starting DuoTask on port 5000..."
echo "📝 OAuth redirect URL configured for: http://localhost:5000"
echo ""

flutter run -d chrome --web-port 5000 