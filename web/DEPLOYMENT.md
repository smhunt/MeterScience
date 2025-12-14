# MeterScience Landing Page - Deployment Guide

## Quick Start

```bash
cd /Users/seanhunt/Code/MeterScience/web
npm install
npm run dev
```

Visit: **http://10.10.10.24:3011**

## What Was Built

A complete marketing landing page for MeterScience positioned as a potential Kickstarter project. The page emphasizes citizen science, community-driven utility monitoring, and the "your data is always free" philosophy.

### Key Sections

1. **Navigation** - Fixed header with smooth scroll links
2. **Hero Section**
   - "Coming to Kickstarter 2025" badge
   - Main headline: "Your Utility Data, Finally Yours"
   - CTA buttons for waitlist and learning more
   - Placeholder for app preview image

3. **Stats Bar** - 4 key metrics highlighting core value props

4. **Problem Section** - 3 pain points:
   - Hidden costs (monthly billing lag)
   - Environmental impact (real-time awareness)
   - Data monopoly (democratizing access)

5. **Solution Section** - 3-step process:
   - **Scan**: Point phone at meter, instant OCR
   - **Track**: Charts, goals, gamification
   - **Compare**: Community verification, neighborhood data

6. **Features Section**
   - iOS/Android app (free forever)
   - MeterPi hardware kit ($79+)
   - Citizen science value proposition

7. **Pricing Section**
   - 4 tiers: Free / Neighbor ($2.99) / Block ($4.99) / District ($9.99)
   - Referral rewards program
   - "Your data is always free" messaging

8. **Kickstarter Section**
   - Early bird pricing ($59 for MeterPi Basic)
   - Lifetime Pro features for backers
   - Founder badge rewards

9. **Email Signup**
   - Waitlist form with validation
   - Success state animation
   - Privacy assurance

10. **Footer**
    - Brand/tagline
    - Product links
    - Resources placeholders
    - Social media placeholders

### Design Features

- Clean, modern aesthetic (Stripe/Linear inspired)
- Mobile-responsive design
- Smooth scroll navigation
- Gradient accents and hover states
- Accessible color contrast
- Fast performance (minimal dependencies)

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Fonts**: Inter (Google Fonts)
- **Icons**: Emoji placeholders (replace with custom SVGs later)

## File Structure

```
web/
├── app/
│   ├── globals.css         # Tailwind imports + custom styles
│   ├── layout.tsx          # Root layout with metadata
│   └── page.tsx            # Landing page (all sections)
├── public/                 # Static assets (empty for now)
├── .env.local              # Environment variables
├── package.json            # Dependencies + scripts
├── tailwind.config.ts      # Tailwind customization
├── tsconfig.json           # TypeScript config
├── README.md               # Setup instructions
├── DEPLOYMENT.md           # This file
└── start.sh                # Quick start script

```

## Port Assignment

- **Port**: 3011
- **Configured in**: `package.json` scripts
- **LAN Access**: http://10.10.10.24:3011
- **Documented in**: `~/.claude/PORTS.md` (needs manual update)

## Next Steps

### 1. Start the Server

```bash
cd /Users/seanhunt/Code/MeterScience/web
./start.sh
```

Or manually:
```bash
npm run dev
```

### 2. Configure Email Collection

The form currently logs to console. To enable real email collection:

**Option A: Formspree (Easiest)**
1. Sign up at https://formspree.io
2. Create a form, get endpoint URL
3. Update `.env.local` with your endpoint
4. Uncomment the fetch code in the form handler

**Option B: Mailchimp**
1. Use Mailchimp's embedded form
2. Replace the custom form with Mailchimp's code

**Option C: Custom Backend**
1. Add a POST endpoint to the FastAPI backend
2. Update form action to point to your API

### 3. Add Real Images

Replace emoji placeholders with:
- App screenshots (iPhone mockups)
- MeterPi hardware photos
- Meter scanning demo GIF/video
- User testimonials with headshots

Tools for mockups:
- https://mockuphone.com
- https://www.figma.com
- https://www.canva.com

### 4. Customize Content

Edit `app/page.tsx` to:
- Refine copy based on user feedback
- Add social proof (user count, testimonials)
- Include press mentions if available
- Add FAQ section if needed

### 5. SEO Optimization

- Add OpenGraph images (`public/og-image.png`)
- Create favicon set (`public/favicon.ico`, etc.)
- Update meta descriptions
- Add structured data (JSON-LD)
- Create sitemap.xml

### 6. Analytics

Add tracking before launch:
- Google Analytics 4
- Plausible (privacy-friendly alternative)
- Fathom Analytics
- Custom event tracking on CTA clicks

### 7. Update PORTS.md

Manually add to `~/.claude/PORTS.md`:

```markdown
⚡ **MeterScience** - http://10.10.10.24:3011

![QR](https://api.qrserver.com/v1/create-qr-code/?size=50x50&data=http://10.10.10.24:3011)
```

And update the project assignments table:

```markdown
### MeterScience
| Service | Port | Type |
|---------|------|------|
| Marketing Website | 3011 | Next.js |
```

Update "Available Ports" from `3011-3019` to `3012-3019`.

## Production Deployment

### Vercel (Recommended)

```bash
npm install -g vercel
vercel login
vercel
```

- Automatic HTTPS
- Global CDN
- Preview deployments
- Environment variables in dashboard

### Custom Server

```bash
npm run build
npm start
```

- Runs on port 3011
- Requires reverse proxy (nginx/caddy) for HTTPS
- Set up process manager (pm2/systemd)

## Environment Variables for Production

```env
# Analytics
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX

# Email Collection
NEXT_PUBLIC_FORMSPREE_ENDPOINT=https://formspree.io/f/YOUR_ID

# Optional: Feature Flags
NEXT_PUBLIC_SHOW_KICKSTARTER=true
NEXT_PUBLIC_LAUNCH_DATE=2025-03-01
```

## Performance Checklist

- [ ] Optimize images (use Next.js Image component)
- [ ] Enable font optimization (already configured)
- [ ] Minimize JavaScript bundle
- [ ] Add loading states for images
- [ ] Enable caching headers in production
- [ ] Test on slow 3G connection
- [ ] Lighthouse score > 90

## Accessibility Checklist

- [ ] Keyboard navigation works
- [ ] Focus indicators visible
- [ ] Alt text for images
- [ ] ARIA labels where needed
- [ ] Color contrast WCAG AA compliant
- [ ] Screen reader tested
- [ ] Semantic HTML structure

## Mobile Optimization

Currently responsive, but test on:
- iPhone SE (small screen)
- iPhone 15 Pro (current gen)
- iPad (tablet view)
- Android phones (various sizes)

## QR Code for Testing

Scan this on your phone to access the site:

![MeterScience QR](https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=http://10.10.10.24:3011)

---

**Built**: December 14, 2025
**Framework**: Next.js 14 + TypeScript + Tailwind CSS
**Port**: 3011
**LAN URL**: http://10.10.10.24:3011
