# 🚀 DEPLOYMENT CONFIGURATIONS

## Environment Variables

### Frontend Environment Variables
```env
# Production
NEXT_PUBLIC_APP_ENV=production
NEXT_PUBLIC_API_URL=https://api.starknet-ultra-defi.com
NEXT_PUBLIC_STARKNET_NETWORK=mainnet-alpha
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_project_id
NEXT_PUBLIC_SENTRY_DSN=your_sentry_dsn

# Staging
NEXT_PUBLIC_APP_ENV=staging
NEXT_PUBLIC_API_URL=https://api-staging.starknet-ultra-defi.com
NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_staging_wallet_connect_project_id
NEXT_PUBLIC_SENTRY_DSN=your_staging_sentry_dsn

# Development
NEXT_PUBLIC_APP_ENV=development
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_dev_wallet_connect_project_id
```

### Mobile Environment Variables
```env
# Production
EXPO_PUBLIC_APP_ENV=production
EXPO_PUBLIC_API_URL=https://api.starknet-ultra-defi.com
EXPO_PUBLIC_STARKNET_NETWORK=mainnet-alpha

# Staging
EXPO_PUBLIC_APP_ENV=staging
EXPO_PUBLIC_API_URL=https://api-staging.starknet-ultra-defi.com
EXPO_PUBLIC_STARKNET_NETWORK=sepolia-alpha

# Development
EXPO_PUBLIC_APP_ENV=development
EXPO_PUBLIC_API_URL=http://localhost:8000
EXPO_PUBLIC_STARKNET_NETWORK=sepolia-alpha
```

## Deployment Targets

### 1. Frontend (Next.js)
- **Vercel** (Recommended)
- **Netlify**
- **AWS Amplify**
- **Docker + AWS ECS/EKS**

### 2. Mobile (React Native/Expo)
- **Expo Application Services (EAS)**
- **App Store Connect (iOS)**
- **Google Play Console (Android)**

### 3. Smart Contracts (Cairo)
- **Starknet Mainnet**
- **Starknet Sepolia (Testnet)**

## Build Commands

### Frontend Production Build
```bash
cd frontend
npm run build
npm run start  # Production server
```

### Mobile Production Build
```bash
cd mobile
npx eas build --platform all --profile production
```

### Smart Contract Deployment
```bash
cd contracts
scarb build
starkli declare target/dev/starknet_ultra_defi_Payment.contract_class.json
starkli deploy [class_hash] [constructor_args]
```