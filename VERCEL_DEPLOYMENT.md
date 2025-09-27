# 🚀 VERCEL DEPLOYMENT GUIDE - StarkNet Ultra DeFi

## 📋 **Pre-Deployment Checklist**

### **1. Vercel Project Setup**
1. Create account at [vercel.com](https://vercel.com)
2. Import your GitHub repository
3. Configure project settings
4. Set up custom domain (optional)

### **2. Environment Variables Setup**
Configure these in your Vercel dashboard under Settings > Environment Variables:

#### **Production Environment:**
```env
NEXT_PUBLIC_APP_ENV=production
NEXT_PUBLIC_API_URL=https://api.starknet-ultra-defi.com
NEXT_PUBLIC_STARKNET_NETWORK=mainnet-alpha
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_project_id
NEXT_PUBLIC_SENTRY_DSN=your_production_sentry_dsn
```

#### **Preview Environment:**
```env
NEXT_PUBLIC_APP_ENV=staging
NEXT_PUBLIC_API_URL=https://api-staging.starknet-ultra-defi.com
NEXT_PUBLIC_STARKNET_NETWORK=sepolia-alpha
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_staging_wallet_connect_project_id
NEXT_PUBLIC_SENTRY_DSN=your_staging_sentry_dsn
```

### **3. Build Configuration**
Your project includes:
- ✅ `vercel.json` - Vercel deployment configuration
- ✅ `build-vercel.sh` - Custom build script
- ✅ Enhanced `next.config.js` with Vercel optimizations
- ✅ `vercel-build` npm script in package.json

---

## 🚀 **Deployment Methods**

### **Method 1: GitHub Integration (Recommended)**
1. Connect your GitHub repository to Vercel
2. Push to `main` branch → Production deployment
3. Push to `develop` branch → Preview deployment
4. Pull requests → Preview deployments

### **Method 2: Vercel CLI**
```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Deploy to production
vercel --prod

# Deploy preview
vercel
```

### **Method 3: GitHub Actions**
Your project includes `.github/workflows/vercel.yml` for automated deployments.

**Required GitHub Secrets:**
- `VERCEL_TOKEN` - Vercel API token
- `VERCEL_ORG_ID` - Your Vercel organization ID
- `VERCEL_PROJECT_ID` - Your Vercel project ID

---

## ⚙️ **Vercel Configuration Details**

### **vercel.json Configuration:**
```json
{
  "version": 2,
  "name": "starknet-ultra-defi",
  "framework": "nextjs",
  "buildCommand": "cd frontend && npm run vercel-build",
  "outputDirectory": "frontend/.next",
  "regions": ["iad1", "sfo1"]
}
```

### **Build Optimizations:**
- ✅ **Standalone output** for faster cold starts
- ✅ **TypeScript checking** before build
- ✅ **Environment-specific builds**
- ✅ **Security headers** and CSP
- ✅ **Performance optimizations**

### **Custom Build Script:**
The `build-vercel.sh` script automatically:
- Detects Vercel environment (production/preview/development)
- Sets appropriate environment variables
- Runs type checking
- Builds optimized Next.js application

---

## 🔧 **Advanced Configuration**

### **Custom Domains**
1. Go to Vercel Dashboard → Your Project → Settings → Domains
2. Add your custom domain: `starknet-ultra-defi.com`
3. Configure DNS records as instructed
4. SSL certificates are automatically managed

### **Performance Optimization**
```javascript
// next.config.js includes:
- Image optimization for Vercel domains
- Bundle optimization
- Static asset caching
- Compression enabled
```

### **Security Headers**
Your middleware includes production-ready security headers:
- Content Security Policy (CSP)
- HSTS, X-Frame-Options, X-Content-Type-Options
- Cross-Origin policies

---

## 📊 **Monitoring & Analytics**

### **Vercel Analytics**
Add to your dashboard:
```bash
npm install @vercel/analytics
```

### **Performance Monitoring**
- ✅ **Lighthouse CI** included in GitHub Actions
- ✅ **Bundle analyzer** available with `npm run analyze`
- ✅ **Performance metrics** in Vercel dashboard

---

## 🚀 **Quick Deployment Steps**

### **1. Initial Setup**
```bash
# Clone your repository
git clone https://github.com/yourusername/starknet-ultra-defi

# Install Vercel CLI
npm i -g vercel

# Login and link project
vercel login
vercel link
```

### **2. Environment Variables**
```bash
# Set production environment variables
vercel env add NEXT_PUBLIC_APP_ENV production
vercel env add NEXT_PUBLIC_STARKNET_NETWORK mainnet-alpha
vercel env add NEXT_PUBLIC_API_URL https://api.starknet-ultra-defi.com

# Set preview environment variables  
vercel env add NEXT_PUBLIC_APP_ENV preview
vercel env add NEXT_PUBLIC_STARKNET_NETWORK sepolia-alpha
```

### **3. Deploy**
```bash
# Deploy to production
vercel --prod

# Deploy preview
vercel
```

---

## ✅ **Deployment Verification**

After deployment, verify:
1. ✅ **Frontend loads correctly** at your Vercel URL
2. ✅ **"Encoded by MS" watermark** is visible
3. ✅ **Welcome screen animations** work smoothly
4. ✅ **StarkNet wallet connection** functions
5. ✅ **All tabs and features** are accessible
6. ✅ **Performance scores** are optimal in Lighthouse
7. ✅ **Security headers** are properly set

---

## 🎯 **Expected Results**

### **Performance Metrics:**
- ✅ **First Load JS**: ~728 kB (optimized)
- ✅ **Lighthouse Score**: 90+ Performance
- ✅ **Cold Start**: < 1 second
- ✅ **Build Time**: < 2 minutes

### **URLs:**
- **Production**: `https://starknet-ultra-defi.vercel.app`
- **Preview**: `https://starknet-ultra-defi-git-develop.vercel.app`
- **Custom Domain**: `https://starknet-ultra-defi.com` (if configured)

---

## 🎉 **Ready for Vercel Deployment!**

Your **StarkNet Ultra DeFi** project is now fully configured for Vercel with:
- ✅ **Optimized build configuration**
- ✅ **Environment management** for all stages  
- ✅ **Automated CI/CD** with GitHub Actions
- ✅ **Performance monitoring** and analytics
- ✅ **Security best practices** implemented
- ✅ **Custom domain** support ready

**Deploy with confidence!** 🚀✨