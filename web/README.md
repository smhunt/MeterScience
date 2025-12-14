# MeterScience Landing Page

Marketing website for MeterScience - a citizen science platform for crowdsourced utility meter reading.

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Start the dev server:
```bash
npm run dev
```

The site will be available at:
- Local: http://localhost:3011
- LAN: http://10.10.10.24:3011 (access from phone)

## Configuration

### Email Collection

The landing page includes an email signup form. To enable actual email collection:

1. Create a free account at [Formspree](https://formspree.io)
2. Create a new form and get your endpoint URL
3. Update `.env.local`:
```
NEXT_PUBLIC_FORMSPREE_ENDPOINT=https://formspree.io/f/YOUR_FORM_ID
```

4. Update the form submission handler in `app/page.tsx`:
```typescript
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault()

  const endpoint = process.env.NEXT_PUBLIC_FORMSPREE_ENDPOINT

  await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email })
  })

  setSubscribed(true)
}
```

Alternatively, you can use:
- Mailchimp
- ConvertKit
- Your own backend API endpoint

## Pages & Sections

### Home Page (`app/page.tsx`)

1. **Hero** - Main value proposition with email CTA
2. **Stats Bar** - Key metrics (100% free, 1 min to scan, etc.)
3. **Problem** - Why utility monitoring matters
4. **Solution** - How MeterScience works (3-step process)
5. **Features** - App vs MeterPi hardware comparison
6. **Pricing** - 4 subscription tiers + referral rewards
7. **Kickstarter** - Campaign teaser with early bird benefits
8. **Email Signup** - Waitlist form
9. **Footer** - Links and social placeholders

## Customization

### Colors

Edit `tailwind.config.ts` to change the primary color scheme:
```typescript
colors: {
  primary: {
    // Customize these shades
    500: '#0ea5e9',
    600: '#0284c7',
    // ...
  }
}
```

### Content

All content is in `app/page.tsx`. Key sections to customize:
- Hero headline and subhead
- Problem/solution copy
- Feature descriptions
- Pricing tiers and amounts
- Kickstarter rewards

### Images

Currently using emoji placeholders. Replace with actual images:
- App screenshots
- MeterPi hardware photos
- User testimonials
- Meter scanning demo

## Build for Production

```bash
npm run build
npm start
```

## Port Configuration

This project runs on port **3011** (configured in `package.json`).

Port assignment tracked in `~/.claude/PORTS.md`.

## Tech Stack

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- React 18

## Design Philosophy

- Clean, modern aesthetic (inspired by Stripe/Linear)
- Mobile-first responsive design
- Fast loading times
- Conversion-optimized (clear CTAs)
- Accessibility compliant

## QR Code for Phone Access

Scan this to access from your phone on the same LAN:

![QR Code](https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=http://10.10.10.24:3011)

http://10.10.10.24:3011
