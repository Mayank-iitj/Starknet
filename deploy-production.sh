#!/bin/bash

# StarkNet Ultra DeFi - Production Deployment Script
echo "🚀 StarkNet Ultra DeFi - Production Deployment"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if environment is provided
if [ -z "$1" ]; then
    error "Usage: $0 <environment> [platform]
    
Environments: development, staging, production
Platforms: frontend, mobile, contracts, all (default)"
fi

ENVIRONMENT=$1
PLATFORM=${2:-all}

log "🚀 Starting deployment for environment: $ENVIRONMENT, platform: $PLATFORM"

# Validate environment
case $ENVIRONMENT in
    development|staging|production)
        log "✅ Environment '$ENVIRONMENT' is valid"
        ;;
    *)
        error "❌ Invalid environment '$ENVIRONMENT'. Use: development, staging, or production"
        ;;
esac

# Frontend deployment
deploy_frontend() {
    log "📱 Deploying frontend..."
    
    cd frontend
    
    # Install dependencies
    log "📦 Installing dependencies..."
    npm ci
    
    # Run type checking
    log "🔍 Running type checking..."
    npm run type-check
    
    # Build for environment
    log "🔨 Building for $ENVIRONMENT..."
    if [ "$ENVIRONMENT" = "production" ]; then
        npm run build:production
    elif [ "$ENVIRONMENT" = "staging" ]; then
        npm run build:staging
    else
        npm run build
    fi
    
    # Deploy based on environment
    case $ENVIRONMENT in
        production)
            log "🌍 Deploying to production..."
            # Add your production deployment commands here
            # e.g., vercel --prod, aws amplify publish, etc.
            warn "⚠️  Production deployment commands need to be configured"
            ;;
        staging)
            log "🧪 Deploying to staging..."
            # Add your staging deployment commands here
            warn "⚠️  Staging deployment commands need to be configured"
            ;;
        development)
            log "🛠️  Starting development server..."
            npm run dev
            ;;
    esac
    
    cd ..
    log "✅ Frontend deployment completed"
}

# Mobile deployment
deploy_mobile() {
    log "📱 Deploying mobile app..."
    
    cd mobile
    
    # Install dependencies
    log "📦 Installing dependencies..."
    npm ci
    
    # Build for environment
    case $ENVIRONMENT in
        production)
            log "🏗️  Building production mobile app..."
            npx eas build --platform all --profile production
            ;;
        staging)
            log "🧪 Building preview mobile app..."
            npx eas build --platform all --profile preview
            ;;
        development)
            log "🛠️  Starting development build..."
            npx expo start
            ;;
    esac
    
    cd ..
    log "✅ Mobile deployment completed"
}

# Smart contracts deployment
deploy_contracts() {
    log "📜 Deploying smart contracts..."
    
    cd contracts
    
    # Build contracts
    log "🔨 Building Cairo contracts..."
    scarb build
    
    # Deploy based on environment
    case $ENVIRONMENT in
        production)
            log "🌍 Deploying to Starknet Mainnet..."
            warn "⚠️  Mainnet deployment requires careful configuration"
            # Add mainnet deployment commands
            ;;
        staging|development)
            log "🧪 Deploying to Starknet Sepolia..."
            warn "⚠️  Testnet deployment commands need to be configured"
            # Add testnet deployment commands
            ;;
    esac
    
    cd ..
    log "✅ Contracts deployment completed"
}

# Main deployment logic
case $PLATFORM in
    frontend)
        deploy_frontend
        ;;
    mobile)
        deploy_mobile
        ;;
    contracts)
        deploy_contracts
        ;;
    all)
        deploy_frontend
        deploy_mobile
        deploy_contracts
        ;;
    *)
        error "❌ Invalid platform '$PLATFORM'. Use: frontend, mobile, contracts, or all"
        ;;
esac

log "🎉 Deployment completed successfully for $ENVIRONMENT environment!"
log "📋 Next steps:"
log "   1. Verify deployments are working correctly"
log "   2. Run smoke tests"
log "   3. Monitor application performance"
log "   4. Update documentation if needed"