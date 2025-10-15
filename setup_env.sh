#!/bin/bash

# DuoTask Environment Setup Script

echo "🚀 DuoTask Environment Setup"
echo "=============================="

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
fi

# Copy example file
if [ -f "env.example" ]; then
    cp env.example .env
    echo "✅ Created .env file from template"
else
    echo "❌ env.example not found!"
    exit 1
fi

echo ""
echo "📝 Next Steps:"
echo "1. Edit the .env file and add your Supabase credentials:"
echo "   - SUPABASE_URL=https://your-project.supabase.co"
echo "   - SUPABASE_ANON_KEY=your_supabase_anon_key_here"
echo ""
echo "2. Get your Supabase credentials from:"
echo "   https://supabase.com/dashboard/project/[YOUR_PROJECT]/settings/api"
echo ""
echo "3. Run the app:"
echo "   flutter run"
echo ""
echo "📖 For detailed setup instructions, see SETUP_GUIDE.md"
