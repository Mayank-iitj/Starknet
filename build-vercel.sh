#!/bin/bash

# Vercel Build Script for StarkNet Ultra DeFi
echo "🚀 Starting Vercel build for StarkNet Ultra DeFi..."

# Set environment based on Vercel environment
if [ "$VERCEL_ENV" = "production" ]; then
    echo "📦 Building for PRODUCTION environment"
    export NODE_ENV=production
    export NEXT_PUBLIC_APP_ENV=production
    export NEXT_PUBLIC_STARKNET_NETWORK=mainnet-alpha
elif [ "$VERCEL_ENV" = "preview" ]; then
    echo "🧪 Building for PREVIEW environment"
    export NODE_ENV=staging
    export NEXT_PUBLIC_APP_ENV=staging
    export NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
else
    echo "🛠️ Building for DEVELOPMENT environment"
    export NODE_ENV=development
    export NEXT_PUBLIC_APP_ENV=development
    export NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
fi

# Navigate to frontend directory
cd frontend

# Install dependencies
echo "📦 Installing dependencies..."
npm ci

# Run type checking
echo "🔍 Running type checking..."
npm run type-check

# Build the application
echo "🔨 Building Next.js application..."
npm run build

echo "✅ Vercel build completed successfully!"