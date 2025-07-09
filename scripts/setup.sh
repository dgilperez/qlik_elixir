#!/bin/bash

# Setup script for qlik_elixir development

echo "🔧 Setting up qlik_elixir development environment"
echo "=============================================="

# Install dependencies
echo "📦 Installing dependencies..."
mix deps.get

# Compile
echo "🔨 Compiling..."
mix compile

# Setup dialyzer
echo "🔍 Setting up dialyzer..."
mix dialyzer --plt

# Run tests
echo "🧪 Running tests..."
mix test

# Generate docs
echo "📚 Generating documentation..."
mix docs

echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update mix.exs with your GitHub URL and name"
echo "2. Update LICENSE with your name"
echo "3. Run tests: mix test"
echo "4. When ready to publish: ./scripts/publish.sh"