'use client'

import { useState } from 'react'

export default function Home() {
  const [email, setEmail] = useState('')
  const [subscribed, setSubscribed] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    // For now, just log to console. User can configure Formspree later
    console.log('Email signup:', email)
    setSubscribed(true)
    setTimeout(() => {
      setSubscribed(false)
      setEmail('')
    }, 3000)
  }

  return (
    <main className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-2">
              <div className="text-3xl">⚡</div>
              <span className="text-xl font-bold text-gradient">MeterScience</span>
            </div>
            <div className="hidden md:flex space-x-8">
              <a href="#problem" className="text-gray-600 hover:text-primary-600 transition">Why</a>
              <a href="#solution" className="text-gray-600 hover:text-primary-600 transition">How</a>
              <a href="#features" className="text-gray-600 hover:text-primary-600 transition">Features</a>
              <a href="#pricing" className="text-gray-600 hover:text-primary-600 transition">Pricing</a>
              <a href="#kickstarter" className="text-gray-600 hover:text-primary-600 transition">Kickstarter</a>
            </div>
            <a
              href="#signup"
              className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition"
            >
              Get Updates
            </a>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto text-center">
          <div className="inline-block mb-4 px-4 py-2 bg-primary-50 text-primary-600 rounded-full text-sm font-semibold">
            Coming to Kickstarter 2025
          </div>
          <h1 className="text-5xl md:text-7xl font-bold mb-6 leading-tight">
            Your Utility Data,
            <br />
            <span className="text-gradient">Finally Yours</span>
          </h1>
          <p className="text-xl md:text-2xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Scan your meters, track your usage, compare with neighbors.
            Join the citizen science revolution making utility data free and accessible.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a
              href="#signup"
              className="bg-primary-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-primary-700 transition glow"
            >
              Join the Waitlist
            </a>
            <a
              href="#features"
              className="border-2 border-gray-300 text-gray-700 px-8 py-4 rounded-lg text-lg font-semibold hover:border-primary-600 hover:text-primary-600 transition"
            >
              Learn More
            </a>
          </div>

          {/* Hero Image Placeholder */}
          <div className="mt-16 rounded-2xl overflow-hidden shadow-2xl max-w-4xl mx-auto">
            <div className="bg-gradient-to-br from-primary-50 to-primary-100 aspect-video flex items-center justify-center">
              <div className="text-center">
                <div className="text-8xl mb-4">📱⚡📊</div>
                <p className="text-gray-600 text-lg">iOS App Preview Coming Soon</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats Bar */}
      <section className="py-12 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
            <div>
              <div className="text-4xl font-bold text-primary-600">100%</div>
              <div className="text-gray-600 mt-2">Free Core App</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600">1 min</div>
              <div className="text-gray-600 mt-2">To First Scan</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600">24/7</div>
              <div className="text-gray-600 mt-2">Auto Monitoring</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600">Open</div>
              <div className="text-gray-600 mt-2">Your Data</div>
            </div>
          </div>
        </div>
      </section>

      {/* Problem Section */}
      <section id="problem" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              Why Utility Monitoring Matters
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Utility companies have all the data. You pay the bills.
              That needs to change.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100">
              <div className="text-5xl mb-4">💸</div>
              <h3 className="text-2xl font-bold mb-3">Hidden Costs</h3>
              <p className="text-gray-600">
                You only see your usage once a month on your bill. By then, it's too late to adjust your habits or catch billing errors.
              </p>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100">
              <div className="text-5xl mb-4">🌍</div>
              <h3 className="text-2xl font-bold mb-3">Environmental Impact</h3>
              <p className="text-gray-600">
                Real-time awareness drives conservation. Studies show monitoring reduces consumption by 10-15% without lifestyle changes.
              </p>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100">
              <div className="text-5xl mb-4">📊</div>
              <h3 className="text-2xl font-bold mb-3">Data Monopoly</h3>
              <p className="text-gray-600">
                Utilities own the data. Researchers can't access it. Communities can't compare. It's time to democratize utility data.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Solution Section */}
      <section id="solution" className="py-20 px-4 sm:px-6 lg:px-8 bg-gradient-to-br from-primary-50 to-white">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              How MeterScience Works
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              From manual scans to automated monitoring, we meet you where you are
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-12 items-center mb-16">
            <div>
              <div className="inline-block mb-4 px-4 py-2 bg-primary-600 text-white rounded-full text-sm font-semibold">
                Step 1: Scan
              </div>
              <h3 className="text-3xl font-bold mb-4">Point Your Phone</h3>
              <p className="text-gray-600 text-lg mb-4">
                Open the app, point at your meter, tap. Our Vision AI reads the digits in seconds.
                Works with electric, gas, and water meters.
              </p>
              <ul className="space-y-2 text-gray-600">
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Works offline - no internet required</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>95%+ accuracy with confidence scoring</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Track multiple meters per home</span>
                </li>
              </ul>
            </div>
            <div className="bg-white p-8 rounded-2xl shadow-xl">
              <div className="aspect-square bg-gradient-to-br from-primary-100 to-primary-50 rounded-xl flex items-center justify-center">
                <div className="text-9xl">📱</div>
              </div>
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-12 items-center mb-16">
            <div className="order-2 md:order-1">
              <div className="bg-white p-8 rounded-2xl shadow-xl">
                <div className="aspect-square bg-gradient-to-br from-primary-100 to-primary-50 rounded-xl flex items-center justify-center">
                  <div className="text-9xl">📊</div>
                </div>
              </div>
            </div>
            <div className="order-1 md:order-2">
              <div className="inline-block mb-4 px-4 py-2 bg-primary-600 text-white rounded-full text-sm font-semibold">
                Step 2: Track
              </div>
              <h3 className="text-3xl font-bold mb-4">See Your Patterns</h3>
              <p className="text-gray-600 text-lg mb-4">
                Beautiful charts show your daily, weekly, and monthly usage.
                Set goals, track streaks, earn XP for consistent monitoring.
              </p>
              <ul className="space-y-2 text-gray-600">
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Gamification - badges, streaks, leaderboards</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Bill predictions and anomaly alerts</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Export your data anytime (CSV, JSON)</span>
                </li>
              </ul>
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <div className="inline-block mb-4 px-4 py-2 bg-primary-600 text-white rounded-full text-sm font-semibold">
                Step 3: Compare
              </div>
              <h3 className="text-3xl font-bold mb-4">Join Your Community</h3>
              <p className="text-gray-600 text-lg mb-4">
                See how your usage compares to similar homes in your neighborhood.
                Verify readings for neighbors, earn rewards, contribute to science.
              </p>
              <ul className="space-y-2 text-gray-600">
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Privacy-first - minimum 5 homes for aggregates</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Community verification for accuracy</span>
                </li>
                <li className="flex items-start">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Neighborhood campaigns and coordination</span>
                </li>
              </ul>
            </div>
            <div className="bg-white p-8 rounded-2xl shadow-xl">
              <div className="aspect-square bg-gradient-to-br from-primary-100 to-primary-50 rounded-xl flex items-center justify-center">
                <div className="text-9xl">🏘️</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              From App to Automation
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Start with manual scans, upgrade to 24/7 automated monitoring
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 mb-12">
            <div className="bg-white p-8 rounded-xl shadow-lg border-2 border-primary-200">
              <div className="text-5xl mb-4">📱</div>
              <h3 className="text-2xl font-bold mb-3">iOS & Android App</h3>
              <p className="text-gray-600 mb-4">
                Free forever. Manual scanning with Vision AI, gamification, and community features.
                Your data is always free and exportable.
              </p>
              <div className="space-y-2 text-sm text-gray-600">
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> Offline OCR scanning</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> XP, badges, streaks</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> Community verification</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> Basic usage tracking</div>
              </div>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg border-2 border-primary-600 relative overflow-hidden">
              <div className="absolute top-4 right-4 bg-primary-600 text-white px-3 py-1 rounded-full text-xs font-bold">
                HARDWARE
              </div>
              <div className="text-5xl mb-4">🔌</div>
              <h3 className="text-2xl font-bold mb-3">MeterPi Kit</h3>
              <p className="text-gray-600 mb-4">
                Raspberry Pi-powered auto-reader. Set it once, get readings every minute.
                Local API, Home Assistant integration, optional cloud sync.
              </p>
              <div className="space-y-2 text-sm text-gray-600">
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> 1-minute reading intervals</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> On-device OCR (no cloud)</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> Local REST API</div>
                <div className="flex items-center"><span className="text-primary-600 mr-2">✓</span> Home Assistant ready</div>
              </div>
              <div className="mt-4 pt-4 border-t border-gray-200">
                <p className="text-sm font-semibold text-primary-600">Starting at $79</p>
              </div>
            </div>
          </div>

          <div className="bg-gradient-to-r from-primary-600 to-primary-500 rounded-2xl p-8 md:p-12 text-white">
            <div className="max-w-4xl mx-auto text-center">
              <h3 className="text-3xl font-bold mb-4">Citizen Science at Scale</h3>
              <p className="text-lg mb-6 text-primary-50">
                Every reading you contribute helps researchers, policymakers, and communities
                understand energy consumption patterns. Your anonymized data powers insights
                that utilities can't provide.
              </p>
              <div className="grid md:grid-cols-3 gap-6 text-center">
                <div>
                  <div className="text-3xl font-bold mb-2">10,000+</div>
                  <div className="text-primary-100 text-sm">Target Readings/Day</div>
                </div>
                <div>
                  <div className="text-3xl font-bold mb-2">100%</div>
                  <div className="text-primary-100 text-sm">Anonymous Aggregates</div>
                </div>
                <div>
                  <div className="text-3xl font-bold mb-2">Open</div>
                  <div className="text-primary-100 text-sm">Research API</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="py-20 px-4 sm:px-6 lg:px-8 bg-gray-50">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              Your Data Is Always Free
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Core features free forever. Premium tiers unlock neighborhood comparisons and advanced analytics.
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-6">
            {/* Free Tier */}
            <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-gray-200">
              <div className="text-center mb-6">
                <h3 className="text-2xl font-bold mb-2">Free</h3>
                <div className="text-4xl font-bold mb-2">$0</div>
                <div className="text-gray-600 text-sm">Forever</div>
              </div>
              <ul className="space-y-3 mb-6">
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Your data only</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Manual scanning</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Basic charts</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Gamification</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Data export</span>
                </li>
              </ul>
              <button className="w-full bg-gray-100 text-gray-600 py-3 rounded-lg font-semibold">
                Always Free
              </button>
            </div>

            {/* Neighbor Tier */}
            <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-gray-200">
              <div className="text-center mb-6">
                <h3 className="text-2xl font-bold mb-2">Neighbor</h3>
                <div className="text-4xl font-bold mb-2">$2.99</div>
                <div className="text-gray-600 text-sm">/month</div>
              </div>
              <ul className="space-y-3 mb-6">
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Everything in Free</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Same postal code</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Usage comparisons</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Bill predictions</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Anomaly alerts</span>
                </li>
              </ul>
              <button className="w-full bg-primary-600 text-white py-3 rounded-lg font-semibold hover:bg-primary-700 transition">
                Coming Soon
              </button>
            </div>

            {/* Block Tier */}
            <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-primary-600 relative">
              <div className="absolute top-0 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-primary-600 text-white px-4 py-1 rounded-full text-xs font-bold">
                POPULAR
              </div>
              <div className="text-center mb-6">
                <h3 className="text-2xl font-bold mb-2">Block</h3>
                <div className="text-4xl font-bold mb-2">$4.99</div>
                <div className="text-gray-600 text-sm">/month</div>
              </div>
              <ul className="space-y-3 mb-6">
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Everything in Neighbor</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>5km radius data</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Advanced analytics</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Priority verification</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Time-of-use tips</span>
                </li>
              </ul>
              <button className="w-full bg-primary-600 text-white py-3 rounded-lg font-semibold hover:bg-primary-700 transition">
                Coming Soon
              </button>
            </div>

            {/* District Tier */}
            <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-gray-200">
              <div className="text-center mb-6">
                <h3 className="text-2xl font-bold mb-2">District</h3>
                <div className="text-4xl font-bold mb-2">$9.99</div>
                <div className="text-gray-600 text-sm">/month</div>
              </div>
              <ul className="space-y-3 mb-6">
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Everything in Block</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>25km radius data</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>API access</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Custom webhooks</span>
                </li>
                <li className="flex items-start text-sm">
                  <span className="text-primary-600 mr-2">✓</span>
                  <span>Research datasets</span>
                </li>
              </ul>
              <button className="w-full bg-primary-600 text-white py-3 rounded-lg font-semibold hover:bg-primary-700 transition">
                Coming Soon
              </button>
            </div>
          </div>

          {/* Referral Rewards */}
          <div className="mt-12 bg-white rounded-xl shadow-lg p-8 border-2 border-primary-200">
            <h3 className="text-2xl font-bold mb-4 text-center">Referral Rewards</h3>
            <div className="grid md:grid-cols-4 gap-6 text-center">
              <div>
                <div className="text-3xl font-bold text-primary-600 mb-2">1</div>
                <div className="text-sm text-gray-600">referral = 1 month Neighbor free</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary-600 mb-2">5</div>
                <div className="text-sm text-gray-600">referrals = 25% off forever</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary-600 mb-2">10</div>
                <div className="text-sm text-gray-600">referrals = Block tier for life</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary-600 mb-2">25</div>
                <div className="text-sm text-gray-600">referrals = District tier for life</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Kickstarter Section */}
      <section id="kickstarter" className="py-20 px-4 sm:px-6 lg:px-8 bg-gradient-to-br from-primary-600 to-primary-700 text-white">
        <div className="max-w-4xl mx-auto text-center">
          <div className="inline-block mb-4 px-4 py-2 bg-white/20 backdrop-blur rounded-full text-sm font-semibold">
            Crowdfunding Campaign
          </div>
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Coming to Kickstarter
          </h2>
          <p className="text-xl text-primary-50 mb-8">
            We're considering launching MeterScience on Kickstarter in 2025.
            Early backers will get exclusive hardware discounts, lifetime Pro features,
            and founder badges in the app.
          </p>

          <div className="grid md:grid-cols-3 gap-6 mb-12">
            <div className="bg-white/10 backdrop-blur rounded-xl p-6">
              <div className="text-4xl mb-3">🎁</div>
              <h3 className="font-bold mb-2">Early Bird Pricing</h3>
              <p className="text-sm text-primary-100">
                MeterPi Basic at $59 (reg $79) for first 100 backers
              </p>
            </div>
            <div className="bg-white/10 backdrop-blur rounded-xl p-6">
              <div className="text-4xl mb-3">⭐</div>
              <h3 className="font-bold mb-2">Lifetime Pro</h3>
              <p className="text-sm text-primary-100">
                District tier features free forever for campaign backers
              </p>
            </div>
            <div className="bg-white/10 backdrop-blur rounded-xl p-6">
              <div className="text-4xl mb-3">🏆</div>
              <h3 className="font-bold mb-2">Founder Badge</h3>
              <p className="text-sm text-primary-100">
                Exclusive in-app badge and early access to new features
              </p>
            </div>
          </div>

          <p className="text-primary-100 mb-6">
            Want to know when we launch? Join the waitlist to get notified first.
          </p>
          <a
            href="#signup"
            className="inline-block bg-white text-primary-600 px-8 py-4 rounded-lg text-lg font-semibold hover:bg-gray-100 transition"
          >
            Get Early Access
          </a>
        </div>
      </section>

      {/* Email Signup Section */}
      <section id="signup" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto text-center">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Join the Waitlist
          </h2>
          <p className="text-xl text-gray-600 mb-8">
            Be the first to know when we launch the app and Kickstarter campaign.
            Plus get exclusive early bird offers.
          </p>

          <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-4 max-w-md mx-auto">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email"
              required
              className="flex-1 px-6 py-4 rounded-lg border-2 border-gray-300 focus:border-primary-600 focus:outline-none text-lg"
            />
            <button
              type="submit"
              className="bg-primary-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-primary-700 transition whitespace-nowrap"
            >
              {subscribed ? 'Thanks!' : 'Sign Up'}
            </button>
          </form>

          {subscribed && (
            <div className="mt-4 text-primary-600 font-semibold">
              Thanks for signing up! We'll be in touch soon.
            </div>
          )}

          <p className="mt-6 text-sm text-gray-500">
            No spam, ever. Unsubscribe anytime. We respect your privacy.
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-400 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid md:grid-cols-4 gap-8 mb-8">
            <div>
              <div className="flex items-center space-x-2 mb-4">
                <div className="text-2xl">⚡</div>
                <span className="text-xl font-bold text-white">MeterScience</span>
              </div>
              <p className="text-sm">
                Democratizing utility data through citizen science.
              </p>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Product</h4>
              <ul className="space-y-2 text-sm">
                <li><a href="#features" className="hover:text-white transition">Features</a></li>
                <li><a href="#pricing" className="hover:text-white transition">Pricing</a></li>
                <li><a href="#kickstarter" className="hover:text-white transition">Kickstarter</a></li>
              </ul>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Resources</h4>
              <ul className="space-y-2 text-sm">
                <li><a href="#" className="hover:text-white transition">API Docs</a></li>
                <li><a href="#" className="hover:text-white transition">GitHub</a></li>
                <li><a href="#" className="hover:text-white transition">Community</a></li>
              </ul>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Connect</h4>
              <ul className="space-y-2 text-sm">
                <li><a href="#" className="hover:text-white transition">Twitter</a></li>
                <li><a href="#" className="hover:text-white transition">Discord</a></li>
                <li><a href="#" className="hover:text-white transition">Email</a></li>
              </ul>
            </div>
          </div>

          <div className="border-t border-gray-800 pt-8 text-center text-sm">
            <p>© 2025 MeterScience. Your data is always yours.</p>
            <p className="mt-2">
              <a href="#" className="hover:text-white transition">Privacy Policy</a>
              {' · '}
              <a href="#" className="hover:text-white transition">Terms of Service</a>
            </p>
          </div>
        </div>
      </footer>
    </main>
  )
}
