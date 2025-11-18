#!/bin/bash

# Deploy DuoTask Web App - Quick Deployment Script

echo "=========================================="
echo "🚀 DUOTASK WEB APP - DEPLOYMENT OPTIONS"
echo "=========================================="
echo ""

# Check if web build exists
if [ ! -d "build/web" ]; then
    echo "📦 Building web app first..."
    flutter build web --release
fi

echo "✅ Web app built successfully!"
echo ""
echo "Choose deployment method:"
echo ""
echo "1️⃣  VERCEL (Recommended - Free, Fast, Custom Domain)"
echo "   • Run: vercel login"
echo "   • Then: vercel --prod"
echo "   • Get instant URL: https://duotask-xyz.vercel.app"
echo ""
echo "2️⃣  NETLIFY (Alternative - Drag & Drop)"
echo "   • Visit: app.netlify.com/drop"
echo "   • Drag build/web folder"
echo "   • Get instant URL: https://duotask-xyz.netlify.app"
echo ""
echo "3️⃣  FIREBASE HOSTING (Google Integration)"
echo "   • Run: npm install -g firebase-tools"
echo "   • Run: firebase login"
echo "   • Run: firebase init hosting"
echo "   • Run: firebase deploy"
echo ""
echo "4️⃣  LOCAL SERVER (Testing - Already Running)"
echo "   • Current: http://localhost:8080"
echo "   • Works on local network only"
echo ""
echo "=========================================="
echo "📱 EASIEST: Netlify Drag & Drop"
echo "=========================================="
echo ""
echo "Steps:"
echo "1. Open: https://app.netlify.com/drop"
echo "2. Drag this folder: build/web"
echo "3. Get instant live URL!"
echo ""
echo "Want to try Vercel instead?"
echo "Run: vercel login"
echo "Then run this script again"
echo ""

# Ask user preference
read -p "Deploy now with Vercel? (requires login) [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Vercel deployment..."
    vercel --prod
fi
