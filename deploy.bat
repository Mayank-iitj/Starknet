@echo off
REM StarkNet Ultra DeFi - Windows Deployment Script

echo 🚀 StarkNet Ultra DeFi - Deployment Script
echo ==========================================

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Node.js is not installed. Please install Node.js 18+ first.
    exit /b 1
)

REM Display Node version
echo ✅ Node.js version:
node -v

REM Install frontend dependencies
echo 📦 Installing frontend dependencies...
cd frontend
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install frontend dependencies
    exit /b 1
)

REM Build frontend
echo 🔨 Building frontend application...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Frontend build failed
    exit /b 1
)

REM Install mobile dependencies
echo 📱 Installing mobile dependencies...
cd ..\mobile
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install mobile dependencies
    exit /b 1
)

echo 🎉 Deployment completed successfully!
echo.
echo 📋 Next Steps:
echo 1. Start development server: cd frontend ^&^& npm run dev
echo 2. Open browser: http://localhost:3000
echo 3. Start mobile app: cd mobile ^&^& npm start
echo.
echo 🌟 StarkNet Ultra DeFi is ready for hackathon submission!