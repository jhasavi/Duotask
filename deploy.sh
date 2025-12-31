#!/bin/bash

# DuoTask Production Deployment Script
# This script builds and deploys DuoTask to Vercel

set -e

echo "🚀 Starting DuoTask deployment..."
echo ""

# Step 1: Clean previous build
echo "📦 Cleaning previous build..."
rm -rf build/web
echo "✅ Clean complete"
echo ""

# Step 2: Build Flutter web
echo "🔨 Building Flutter web (release mode)..."
flutter build web --release
echo "✅ Build complete"
echo ""

# Step 3: Deploy to Vercel
echo "🌐 Deploying to Vercel..."
npx vercel deploy --prod --yes
echo ""

echo "✅ Deployment complete!"
echo ""
echo "🎉 Your app is live!"
