# Component Architecture

This landing page is currently a single-page component (`app/page.tsx`). As it grows, consider breaking it into reusable components.

## Suggested Component Structure

```
components/
├── layout/
│   ├── Navigation.tsx       # Fixed header with scroll links
│   └── Footer.tsx           # Footer with links
├── sections/
│   ├── Hero.tsx             # Main hero with CTA
│   ├── StatsBar.tsx         # 4 key metrics
│   ├── Problem.tsx          # Pain points (3 cards)
│   ├── Solution.tsx         # How it works (3 steps)
│   ├── Features.tsx         # App vs Hardware
│   ├── Pricing.tsx          # Subscription tiers
│   ├── Kickstarter.tsx      # Campaign teaser
│   └── EmailSignup.tsx      # Waitlist form
├── ui/
│   ├── Button.tsx           # Reusable button component
│   ├── Card.tsx             # Card container
│   ├── Badge.tsx            # Badge/pill component
│   └── Input.tsx            # Form input
└── icons/
    └── [various SVG icons]
```

## Current Structure (Single File)

Everything is in `app/page.tsx` as a single component. This works well for:
- Initial development speed
- Easy global changes
- Simple deployment
- No prop drilling

## When to Refactor

Refactor into components when:
- Adding A/B testing variants
- Creating multiple landing pages
- Building a component library
- Adding complex interactions
- Team collaboration grows

## Styling Patterns Used

### Layout
- `max-w-7xl mx-auto` - Content container
- `px-4 sm:px-6 lg:px-8` - Responsive padding
- `py-20` - Section spacing

### Typography
- `text-4xl md:text-5xl font-bold` - Section headings
- `text-xl md:text-2xl text-gray-600` - Subheadings
- `text-lg` - Body copy

### Buttons
- Primary: `bg-primary-600 text-white hover:bg-primary-700`
- Secondary: `border-2 border-gray-300 hover:border-primary-600`
- States: `transition` for smooth hovers

### Cards
- `bg-white rounded-xl shadow-lg border`
- `p-8` for padding
- `hover:` states for interactivity

### Gradients
- Text: `bg-clip-text text-transparent bg-gradient-to-r`
- Background: `bg-gradient-to-br from-primary-50 to-white`

### Responsive Grid
- `grid md:grid-cols-2 gap-8` - 2 columns on desktop
- `grid md:grid-cols-3 gap-8` - 3 columns for cards
- `grid md:grid-cols-4 gap-6` - 4 columns for pricing

## Animation Opportunities

Current page has minimal animations. Consider adding:

### On Scroll Animations
```typescript
// Using framer-motion
import { motion } from 'framer-motion'

<motion.div
  initial={{ opacity: 0, y: 20 }}
  whileInView={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.5 }}
>
  {content}
</motion.div>
```

### Hover Effects
- Card lift on hover
- Button scale on click
- Image zoom on hover
- Icon bounce on hover

### Loading States
- Skeleton screens while loading
- Form submission spinners
- Progressive image loading

## Accessibility Patterns

Already implemented:
- Semantic HTML (`<nav>`, `<section>`, `<footer>`)
- Descriptive link text
- Form labels (implicit via placeholder)
- Color contrast (primary-600 passes WCAG AA)

To improve:
- Add `aria-label` to icon buttons
- Add `alt` text when images are added
- Add skip-to-content link
- Add focus-visible styles
- Test with screen reader

## Performance Optimizations

### Images (when added)
```typescript
import Image from 'next/image'

<Image
  src="/hero-screenshot.png"
  alt="MeterScience app screenshot"
  width={800}
  height={600}
  priority // for above-the-fold images
/>
```

### Font Loading
Already optimized via `next/font/google` in `globals.css`

### Code Splitting
Next.js automatically code-splits by route.
For client components, use dynamic imports:

```typescript
import dynamic from 'next/dynamic'

const HeavyComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <p>Loading...</p>
})
```

## Testing Considerations

### Unit Tests (Jest + React Testing Library)
```typescript
// Example: EmailSignup.test.tsx
test('submits email on form submit', async () => {
  render(<EmailSignup />)
  const input = screen.getByPlaceholderText('Enter your email')
  const button = screen.getByText('Sign Up')

  fireEvent.change(input, { target: { value: 'test@example.com' } })
  fireEvent.click(button)

  await waitFor(() => {
    expect(screen.getByText('Thanks!')).toBeInTheDocument()
  })
})
```

### E2E Tests (Playwright)
```typescript
// Example: landing.spec.ts
test('full signup flow', async ({ page }) => {
  await page.goto('http://10.10.10.24:3011')
  await page.fill('input[type="email"]', 'test@example.com')
  await page.click('button:has-text("Sign Up")')
  await expect(page.locator('text=Thanks!')).toBeVisible()
})
```

### Visual Regression (Percy/Chromatic)
- Capture screenshots of each section
- Compare on every PR
- Catch unintended visual changes

## Content Management

For dynamic content updates without code changes:

### Option 1: JSON Content
```typescript
// content/landing.json
{
  "hero": {
    "title": "Your Utility Data, Finally Yours",
    "subtitle": "Scan your meters..."
  }
}

// Load in component
import content from '@/content/landing.json'
```

### Option 2: Markdown Files
```typescript
// Use gray-matter + markdown-it
import fs from 'fs'
import matter from 'gray-matter'

const content = matter(fs.readFileSync('content/hero.md'))
```

### Option 3: Headless CMS
- Contentful
- Sanity
- Strapi
- Payload CMS

Benefits:
- Non-technical team can edit
- Preview before publish
- Version history
- Multi-language support

## Internationalization (i18n)

If planning to support multiple languages:

```typescript
// Use next-intl
import { useTranslations } from 'next-intl'

export default function Hero() {
  const t = useTranslations('Hero')
  return <h1>{t('title')}</h1>
}
```

## Analytics Events to Track

```typescript
// Track key user actions
const trackEvent = (event: string, data?: object) => {
  if (typeof window !== 'undefined' && window.gtag) {
    window.gtag('event', event, data)
  }
}

// Usage
trackEvent('cta_click', { location: 'hero' })
trackEvent('email_signup', { source: 'footer' })
trackEvent('pricing_view', { tier: 'block' })
```

## Mobile-Specific Features

Consider adding:
- Touch-optimized tap targets (min 44px)
- Swipeable sections (react-swipeable)
- Mobile-specific CTAs (call, SMS)
- Progressive Web App (PWA) manifest
- Add to home screen prompt

## Future Enhancements

### Blog/News Section
- Add `/blog` route with posts
- Show latest 3 posts on landing page
- RSS feed for subscribers

### Testimonials
- Carousel of user quotes
- Video testimonials
- Trust badges (press logos)

### Interactive Demo
- Embedded meter scanning simulator
- Live data visualization
- Interactive pricing calculator

### Social Proof
- Real-time signup counter
- Map of user locations
- Recent activity feed

### Comparison Table
- MeterScience vs Manual tracking
- MeterScience vs Smart meters
- Feature comparison matrix

---

**Note**: This is a reference guide for future development. The current implementation is intentionally simple to ship fast. Refactor incrementally as needed.
