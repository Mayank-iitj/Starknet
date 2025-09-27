#!/bin/bash

# StarkNet Ultra DeFi - Deployment Script
echo "🚀 StarkNet Ultra DeFi - Deployment Script"
echo "=========================================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check Node version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

echo "✅ Node.js version: $(node -v)"

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
cd frontend
npm install
if [ $? -ne 0 ]; then
    echo "❌ Failed to install frontend dependencies"
    exit 1
fi

# Build frontend
echo "🔨 Building frontend application..."
npm run build
if [ $? -ne 0 ]; then
    echo "❌ Frontend build failed"
    exit 1
fi

# Install mobile dependencies
echo "📱 Installing mobile dependencies..."
cd ../mobile
npm install
if [ $? -ne 0 ]; then
    echo "❌ Failed to install mobile dependencies"
    exit 1
fi

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Start development server: cd frontend && npm run dev"
echo "2. Open browser: http://localhost:3000"
echo "3. Start mobile app: cd mobile && npm start"
echo ""
echo "🌟 StarkNet Ultra DeFi is ready for hackathon submission!"