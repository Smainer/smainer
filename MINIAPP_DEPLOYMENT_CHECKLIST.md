# Telegram Miniapp Production Deployment Checklist

## 🚀 IMMEDIATE DEPLOYMENT STEPS

### 1. Environment Configuration (15 mins)
```bash
cd /home/smainer/Smainer/telegram/miniapp

# Create production environment
cat > .env.production << EOF
VITE_RELAYER_URL=https://your-relayer-domain.com
VITE_STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io
VITE_SMAINER_CONTRACT_ADDRESS=0x[YOUR_DEPLOYED_CONTRACT]
VITE_NFT_CONTRACT_ADDRESS=0x[YOUR_NFT_CONTRACT]
EOF
```

### 2. Code Quality Setup (10 mins)
```bash
# Create ESLint configuration
npm init @eslint/config
# Select: React, TypeScript, Browser

# Add to package.json scripts:
# "lint:fix": "eslint . --ext ts,tsx --fix"
```

### 3. Vercel Deployment (20 mins)
```bash
# Install Vercel CLI if needed
npm i -g vercel

# Deploy to staging first
vercel

# Deploy to production
vercel --prod
```

### 4. Telegram Bot Configuration (10 mins)
- Open [@BotFather](https://t.me/BotFather)
- `/setmenubutton`
- Select your bot
- Set URL to: `https://your-domain.vercel.app`
- Set button text: "Open Smainer AI"

## 📋 PRE-DEPLOYMENT VERIFICATION

### Build & Quality Checks
- [ ] `npm run build` completes without errors
- [ ] Bundle size under 500KB total
- [ ] All environment variables set correctly
- [ ] Contract addresses are production values
- [ ] HTTPS domain configured

### Functional Tests
- [ ] Wallet connection works in miniapp environment
- [ ] Starknet transactions can be signed
- [ ] Relayer API connectivity confirmed  
- [ ] Chat interface responds correctly
- [ ] NFT generation flow functional

### Security Validation
- [ ] No private keys in code or environment
- [ ] CORS configured correctly
- [ ] CSP headers set appropriately
- [ ] Rate limiting configured on backend

## 🔒 SECURITY CONSIDERATIONS

### Environment Variables (Production)
```bash
# Required for production
VITE_RELAYER_URL=https://relayer.smainer.io
VITE_STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io
VITE_SMAINER_CONTRACT_ADDRESS=0x[REAL_CONTRACT]
VITE_NFT_CONTRACT_ADDRESS=0x[REAL_NFT_CONTRACT]

# Optional analytics/monitoring
VITE_ANALYTICS_ID=YOUR_ANALYTICS_ID
VITE_SENTRY_DSN=YOUR_SENTRY_URL
```

### Vercel Configuration Updates
Update `vercel.json`:
```json
{
  "env": {
    "VITE_RELAYER_URL": "@relayer-url",
    "VITE_STARKNET_RPC_URL": "@starknet-rpc",
    "VITE_SMAINER_CONTRACT_ADDRESS": "@smainer-contract",
    "VITE_NFT_CONTRACT_ADDRESS": "@nft-contract"
  }
}
```

## 📱 POST-DEPLOYMENT TESTING

### Manual Testing Checklist
- [ ] Open miniapp in Telegram mobile
- [ ] Connect wallet (Argent X/Braavos)
- [ ] Submit test inference request
- [ ] Verify transaction signing
- [ ] Check response time < 10 seconds
- [ ] Test on different device types

### Automated Monitoring
```bash
# Add health check endpoint
curl https://your-miniapp.vercel.app/health

# Monitor bundle loading
curl -I https://your-miniapp.vercel.app/assets/index-*.js
```

## 🚨 ROLLBACK PLAN

### If Issues Arise
```bash
# Rollback to previous Vercel deployment
vercel rollback [deployment-url]

# Or quickly disable miniapp
# In @BotFather: /setmenubutton -> Remove button
```

### Emergency Contacts
- Vercel deployment logs: `vercel logs [deployment-url]`  
- Telegram Bot API issues: Check @BotFather logs
- Contract issues: Use Starknet explorer

## ✅ SUCCESS CRITERIA

### Performance Targets
- [ ] Initial load time < 3 seconds
- [ ] Wallet connection < 5 seconds  
- [ ] Transaction signing < 10 seconds
- [ ] Chat response time < 8 seconds

### User Experience Goals
- [ ] Seamless Telegram integration
- [ ] Intuitive wallet connection flow
- [ ] Clear transaction status indicators
- [ ] Responsive mobile interface

### Technical Health
- [ ] 99.9% uptime (Vercel SLA)
- [ ] Error rate < 1%
- [ ] Bundle size optimized
- [ ] Security headers present

## 🔄 MAINTENANCE SCHEDULE

### Daily Checks
- Monitor Vercel deployment status
- Check error rates in analytics
- Verify relayer API connectivity

### Weekly Updates  
- Review bundle size changes
- Update dependency versions
- Test new Telegram features

### Monthly Reviews
- Performance optimization
- Security audit
- User feedback integration