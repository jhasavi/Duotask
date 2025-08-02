#!/bin/bash

# Script to commit and push current authentication configuration to GitHub
# Usage: ./push_auth_to_github.sh [GITHUB_REPO_URL]

set -e  # Exit on any error

echo "🚀 Starting authentication configuration backup to GitHub..."

# Check if GitHub repo URL is provided
if [ -z "$1" ]; then
    echo "❌ Error: Please provide GitHub repository URL"
    echo "Usage: ./push_auth_to_github.sh https://github.com/username/repo-name.git"
    exit 1
fi

GITHUB_REPO_URL="$1"

# Add all current changes
echo "📁 Adding all current changes..."
git add .

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "ℹ️  No changes to commit"
else
    # Commit with descriptive message
    echo "💾 Committing authentication configuration..."
    git commit -m "feat: Working Google OAuth authentication configuration

- Google Sign-In working on Chrome and iPhone
- Android configuration ready (needs debugging)
- Firebase configuration complete
- Environment variables configured
- OAuth client IDs and secrets configured
- iOS and Android platform configurations
- Authentication service implementation
- Task and user models
- Basic UI screens (auth, pairing, tasks)

This commit preserves the working authentication setup before Android debugging."
fi

# Add remote if not already added
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "🔗 Adding GitHub remote..."
    git remote add origin "$GITHUB_REPO_URL"
else
    echo "🔗 Updating GitHub remote..."
    git remote set-url origin "$GITHUB_REPO_URL"
fi

# Push to GitHub
echo "📤 Pushing to GitHub..."
git push -u origin main

echo "✅ Successfully pushed authentication configuration to GitHub!"
echo "🔗 Repository: $GITHUB_REPO_URL"
echo ""
echo "📋 Next steps:"
echo "1. Debug Android Google Sign-In error"
echo "2. Test authentication flow on all platforms"
echo "3. Continue with UI improvements" 