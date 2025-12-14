import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'MeterScience - Citizen Science for Utility Monitoring',
  description: 'Scan your meters, track your usage, help science. Join the crowdsourced utility data revolution.',
  keywords: 'utility meter, energy monitoring, citizen science, smart meter, OCR, sustainability',
  openGraph: {
    title: 'MeterScience - Citizen Science for Utility Monitoring',
    description: 'Scan your meters, track your usage, help science.',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
