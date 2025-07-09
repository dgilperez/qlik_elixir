#!/bin/bash

# Publishing script for qlik_elixir

echo "🚀 Publishing qlik_elixir to Hex.pm"
echo "=================================="

# Check if we're on main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
    echo "❌ Error: You must be on the main branch to publish"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: You have uncommitted changes"
    exit 1
fi

# Run tests
echo "📋 Running tests..."
if ! mix test; then
    echo "❌ Error: Tests failed"
    exit 1
fi

# Check formatting
echo "🎨 Checking formatting..."
if ! mix format --check-formatted; then
    echo "❌ Error: Code is not formatted"
    echo "Run 'mix format' to fix"
    exit 1
fi

# Run Credo
echo "🔍 Running Credo..."
if ! mix credo --strict; then
    echo "⚠️  Warning: Credo found issues"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build docs
echo "📚 Building documentation..."
mix docs

# Get current version
VERSION=$(grep '@version' mix.exs | head -1 | cut -d'"' -f2)
echo "📦 Current version: $VERSION"

# Confirm
read -p "🤔 Ready to publish v$VERSION to Hex.pm? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Publishing cancelled"
    exit 0
fi

# Dry run first
echo "🧪 Running dry run..."
mix hex.publish --dry-run

read -p "👀 Does everything look correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Publishing cancelled"
    exit 0
fi

# Tag the release
echo "🏷️  Creating git tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"

# Publish
echo "📤 Publishing to Hex.pm..."
mix hex.publish

# Push tag
echo "📤 Pushing git tag..."
git push origin "v$VERSION"

echo "✅ Successfully published qlik_elixir v$VERSION!"
echo "🎉 View your package at: https://hex.pm/packages/qlik_elixir"