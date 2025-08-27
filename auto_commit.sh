#!/bin/bash

# Auto-commit and push script for auto-key-press project

echo "🔄 Auto-committing changes..."

# Add all changes
git add .

# Check if there are any changes to commit
if git diff --cached --quiet; then
    echo "✅ No changes to commit"
else
    # Create commit with timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Auto-commit: $timestamp - Auto key presser updates"
    
    # Push to GitHub
    echo "🚀 Pushing to GitHub..."
    git push origin main
    
    echo "✅ Successfully committed and pushed changes!"
fi
