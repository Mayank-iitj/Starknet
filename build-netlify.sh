#!/bin/bash

# Netlify Build Script for StarkNet Ultra DeFi
echo "🚀 Starting Netlify build for StarkNet Ultra DeFi..."

# Set Netlify environment flag
export NETLIFY=true

# Set environment based on Netlify context
if [ "$CONTEXT" = "production" ]; then
    echo "📦 Building for PRODUCTION environment"
    export NODE_ENV=production
    export NEXT_PUBLIC_APP_ENV=production
    export NEXT_PUBLIC_STARKNET_NETWORK=mainnet-alpha
elif [ "$CONTEXT" = "deploy-preview" ]; then
    echo "🧪 Building for DEPLOY PREVIEW environment"
    export NODE_ENV=staging
    export NEXT_PUBLIC_APP_ENV=staging
    export NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
else
    echo "🛠️ Building for BRANCH DEPLOY environment"
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

# Build and export for static hosting
echo "🔨 Building and exporting Next.js application..."
npm run build:netlify

echo "✅ Netlify build completed successfully!"

# List output directory for verification
echo "📂 Build output:"
ls -la out/