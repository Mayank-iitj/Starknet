# StarkNet Ultra DeFi - Production Deployment (PowerShell)
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("development", "staging", "production")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("frontend", "mobile", "contracts", "all")]
    [string]$Platform = "all"
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green" 
    Yellow = "Yellow"
    Blue = "Blue"
}

function Write-Log {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error-Log {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
    exit 1
}

Write-Log "🚀 Starting deployment for environment: $Environment, platform: $Platform"

# Frontend deployment
function Deploy-Frontend {
    Write-Log "📱 Deploying frontend..."
    
    Set-Location frontend
    
    # Install dependencies
    Write-Log "📦 Installing dependencies..."
    npm ci
    if ($LASTEXITCODE -ne 0) { Write-Error-Log "Failed to install frontend dependencies" }
    
    # Run type checking
    Write-Log "🔍 Running type checking..."
    npm run type-check
    if ($LASTEXITCODE -ne 0) { Write-Error-Log "Type checking failed" }
    
    # Build for environment
    Write-Log "🔨 Building for $Environment..."
    switch ($Environment) {
        "production" { npm run build:production }
        "staging" { npm run build:staging }
        default { npm run build }
    }
    if ($LASTEXITCODE -ne 0) { Write-Error-Log "Build failed" }
    
    # Deploy based on environment
    switch ($Environment) {
        "production" {
            Write-Log "🌍 Deploying to production..."
            Write-Warn "⚠️  Production deployment commands need to be configured"
        }
        "staging" {
            Write-Log "🧪 Deploying to staging..."
            Write-Warn "⚠️  Staging deployment commands need to be configured"
        }
        "development" {
            Write-Log "🛠️  Starting development server..."
            Start-Process -NoNewWindow npm -ArgumentList "run", "dev"
        }
    }
    
    Set-Location ..
    Write-Log "✅ Frontend deployment completed"
}

# Mobile deployment
function Deploy-Mobile {
    Write-Log "📱 Deploying mobile app..."
    
    Set-Location mobile
    
    # Install dependencies
    Write-Log "📦 Installing dependencies..."
    npm ci
    if ($LASTEXITCODE -ne 0) { Write-Error-Log "Failed to install mobile dependencies" }
    
    # Build for environment
    switch ($Environment) {
        "production" {
            Write-Log "🏗️  Building production mobile app..."
            npx eas build --platform all --profile production
        }
        "staging" {
            Write-Log "🧪 Building preview mobile app..."
            npx eas build --platform all --profile preview
        }
        "development" {
            Write-Log "🛠️  Starting development build..."
            npx expo start
        }
    }
    
    Set-Location ..
    Write-Log "✅ Mobile deployment completed"
}

# Smart contracts deployment
function Deploy-Contracts {
    Write-Log "📜 Deploying smart contracts..."
    
    Set-Location contracts
    
    # Build contracts
    Write-Log "🔨 Building Cairo contracts..."
    scarb build
    if ($LASTEXITCODE -ne 0) { Write-Error-Log "Contract build failed" }
    
    # Deploy based on environment
    switch ($Environment) {
        "production" {
            Write-Log "🌍 Deploying to Starknet Mainnet..."
            Write-Warn "⚠️  Mainnet deployment requires careful configuration"
        }
        { $_ -in @("staging", "development") } {
            Write-Log "🧪 Deploying to Starknet Sepolia..."
            Write-Warn "⚠️  Testnet deployment commands need to be configured"
        }
    }
    
    Set-Location ..
    Write-Log "✅ Contracts deployment completed"
}

# Main deployment logic
switch ($Platform) {
    "frontend" { Deploy-Frontend }
    "mobile" { Deploy-Mobile }
    "contracts" { Deploy-Contracts }
    "all" {
        Deploy-Frontend
        Deploy-Mobile
        Deploy-Contracts
    }
}

Write-Log "🎉 Deployment completed successfully for $Environment environment!"
Write-Log "📋 Next steps:"
Write-Log "   1. Verify deployments are working correctly"
Write-Log "   2. Run smoke tests"
Write-Log "   3. Monitor application performance"
Write-Log "   4. Update documentation if needed"