'use client'

import Link from 'next/link'

export default function PrivacyPolicy() {
  return (
    <main className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link href="/" className="flex items-center space-x-2">
              <div className="text-3xl">⚡</div>
              <span className="text-xl font-bold text-gradient">MeterScience</span>
            </Link>
            <Link
              href="/"
              className="text-gray-600 hover:text-primary-600 transition"
            >
              Back to Home
            </Link>
          </div>
        </div>
      </nav>

      {/* Header */}
      <section className="pt-32 pb-12 px-4 sm:px-6 lg:px-8 bg-gradient-to-br from-primary-50 to-white">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-4xl md:text-5xl font-bold mb-4">Privacy Policy</h1>
          <p className="text-xl text-gray-600">
            Last updated: December 15, 2025
          </p>
        </div>
      </section>

      {/* Table of Contents */}
      <section className="py-8 px-4 sm:px-6 lg:px-8 bg-gray-50 border-y border-gray-200">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-lg font-semibold mb-4">Table of Contents</h2>
          <div className="grid md:grid-cols-2 gap-2 text-sm">
            <a href="#introduction" className="text-primary-600 hover:underline">1. Introduction</a>
            <a href="#information-collected" className="text-primary-600 hover:underline">2. Information We Collect</a>
            <a href="#how-we-use" className="text-primary-600 hover:underline">3. How We Use Your Information</a>
            <a href="#data-sharing" className="text-primary-600 hover:underline">4. Data Sharing and Disclosure</a>
            <a href="#data-retention" className="text-primary-600 hover:underline">5. Data Retention</a>
            <a href="#your-rights" className="text-primary-600 hover:underline">6. Your Privacy Rights</a>
            <a href="#data-security" className="text-primary-600 hover:underline">7. Data Security</a>
            <a href="#childrens-privacy" className="text-primary-600 hover:underline">8. Children's Privacy</a>
            <a href="#international" className="text-primary-600 hover:underline">9. International Data Transfers</a>
            <a href="#changes" className="text-primary-600 hover:underline">10. Changes to This Policy</a>
            <a href="#contact" className="text-primary-600 hover:underline">11. Contact Us</a>
          </div>
        </div>
      </section>

      {/* Content */}
      <section className="py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto prose prose-lg">

          {/* Introduction */}
          <div id="introduction" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">1. Introduction</h2>
            <p className="text-gray-600 leading-relaxed mb-4">
              MeterScience Inc. ("we," "us," "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services (collectively, the "Service").
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              Our Service allows you to scan and monitor your utility meters, track your consumption, and participate in a citizen science community. We take your privacy seriously and are committed to transparency in how we handle your data.
            </p>
            <p className="text-gray-600 leading-relaxed">
              Please read this Privacy Policy carefully. By using the Service, you agree to the collection and use of information in accordance with this policy.
            </p>
          </div>

          {/* Information Collected */}
          <div id="information-collected" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">2. Information We Collect</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">2.1 Information You Provide</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Account Information:</strong> Email address, username, password, and profile information</li>
              <li><strong>Meter Configuration:</strong> Meter type (electric, gas, water), location, unit preferences, and custom meter settings</li>
              <li><strong>Subscription Information:</strong> Billing details, subscription tier, and payment information (processed securely through Stripe)</li>
              <li><strong>Communications:</strong> Support requests, feedback, and correspondence with us</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">2.2 Meter Reading Data</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Reading Values:</strong> Numeric meter readings you scan or manually enter</li>
              <li><strong>Timestamps:</strong> Date and time of each reading</li>
              <li><strong>Confidence Scores:</strong> OCR accuracy metrics for scanned readings</li>
              <li><strong>Images:</strong> Photos of your meters (processed locally on-device, not uploaded to our servers unless you choose to share for community verification)</li>
              <li><strong>Usage Calculations:</strong> Derived consumption data based on your readings</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">2.3 Location Data</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Approximate Location:</strong> Postal code, city, and region for neighborhood comparisons</li>
              <li><strong>GPS Coordinates:</strong> If you enable location services, we collect GPS coordinates to verify meter location and enable geo-based features (optional)</li>
              <li><strong>Location Precision:</strong> We use "fuzzy" location data for privacy - your exact address is never required or stored</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">2.4 Automatically Collected Information</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Device Information:</strong> Device type, operating system, unique device identifiers</li>
              <li><strong>Usage Analytics:</strong> App features used, session duration, crash reports, performance metrics</li>
              <li><strong>Network Information:</strong> IP address, internet service provider (anonymized for analytics)</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">2.5 MeterPi Hardware Data</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              If you use our MeterPi hardware device:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Local Processing:</strong> All OCR processing happens on-device; images are not transmitted unless you enable cloud sync</li>
              <li><strong>Device Status:</strong> Hardware health metrics, uptime, capture success rates</li>
              <li><strong>Configuration:</strong> Your device settings and preferences</li>
            </ul>
          </div>

          {/* How We Use Information */}
          <div id="how-we-use" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">3. How We Use Your Information</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.1 Core Service Delivery</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Process and store your meter readings</li>
              <li>Calculate consumption trends and generate usage insights</li>
              <li>Provide personalized recommendations and alerts</li>
              <li>Enable community features (comparisons, verification, campaigns)</li>
              <li>Synchronize data across your devices</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.2 Citizen Science and Research</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Create anonymized, aggregated datasets for research purposes</li>
              <li>Generate neighborhood and regional consumption statistics</li>
              <li>Contribute to environmental research and policy analysis</li>
              <li>Publish open data sets (always anonymized, minimum 5 homes per aggregate)</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.3 Product Improvement</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Analyze usage patterns to improve OCR accuracy</li>
              <li>Debug issues and improve app performance</li>
              <li>Develop new features based on user behavior</li>
              <li>Conduct A/B testing for user experience optimization</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.4 Communications</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Send important service notifications and updates</li>
              <li>Provide customer support</li>
              <li>Send promotional communications (you can opt out anytime)</li>
              <li>Request feedback and participation in surveys</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.5 Legal and Security</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Comply with legal obligations and enforce our Terms of Service</li>
              <li>Detect and prevent fraud, abuse, and security threats</li>
              <li>Protect the rights and safety of our users and the public</li>
            </ul>
          </div>

          {/* Data Sharing */}
          <div id="data-sharing" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">4. Data Sharing and Disclosure</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.1 We Do NOT Sell Your Data</h3>
            <p className="text-gray-600 leading-relaxed mb-6">
              <strong>Your personal data is never sold to third parties.</strong> This is a core principle of MeterScience.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.2 Data We Share</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              We may share your information in the following limited circumstances:
            </p>

            <h4 className="text-xl font-semibold mb-2 text-gray-700">Service Providers</h4>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Payment Processing:</strong> Stripe (payment processing) - they receive only necessary billing information</li>
              <li><strong>Cloud Infrastructure:</strong> AWS or similar providers for hosting and data storage</li>
              <li><strong>Analytics:</strong> Privacy-focused analytics providers (anonymized data only)</li>
              <li><strong>Customer Support:</strong> Support ticketing systems to help resolve your issues</li>
            </ul>

            <h4 className="text-xl font-semibold mb-2 text-gray-700">Community Features</h4>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Aggregated Statistics:</strong> Your data contributes to neighborhood averages (minimum 5 homes, fully anonymized)</li>
              <li><strong>Verification:</strong> If you submit a reading for community verification, anonymized reading details are shared with other users</li>
              <li><strong>Public Leaderboards:</strong> Your username and XP (if you opt in to public profiles)</li>
            </ul>

            <h4 className="text-xl font-semibold mb-2 text-gray-700">Research Partners</h4>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Universities and research institutions may receive anonymized, aggregated datasets</li>
              <li>All research data sharing requires explicit opt-in consent</li>
              <li>Published datasets follow strict privacy standards (k-anonymity with k ≥ 5)</li>
            </ul>

            <h4 className="text-xl font-semibold mb-2 text-gray-700">Legal Requirements</h4>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>When required by law, court order, or government regulation</li>
              <li>To protect our legal rights or defend against legal claims</li>
              <li>To prevent fraud or investigate security incidents</li>
            </ul>

            <h4 className="text-xl font-semibold mb-2 text-gray-700">Business Transfers</h4>
            <p className="text-gray-600 leading-relaxed mb-6">
              In the event of a merger, acquisition, or sale of assets, your data may be transferred. We will notify you and ensure the new entity honors this Privacy Policy.
            </p>
          </div>

          {/* Data Retention */}
          <div id="data-retention" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">5. Data Retention</h2>

            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Active Accounts:</strong> We retain your data as long as your account is active</li>
              <li><strong>Deleted Accounts:</strong> Personal data is deleted within 30 days of account deletion</li>
              <li><strong>Meter Readings:</strong> You can delete individual readings at any time; they are removed immediately</li>
              <li><strong>Aggregated Data:</strong> Anonymized statistics may be retained indefinitely for research purposes</li>
              <li><strong>Backups:</strong> Deleted data may persist in backups for up to 90 days, then permanently erased</li>
              <li><strong>Legal Hold:</strong> Data subject to legal obligations may be retained longer as required by law</li>
            </ul>

            <p className="text-gray-600 leading-relaxed">
              <strong>Your right to deletion:</strong> You can request complete deletion of your data at any time by contacting us at support@meterscience.com.
            </p>
          </div>

          {/* Your Rights */}
          <div id="your-rights" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">6. Your Privacy Rights</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.1 All Users</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Access:</strong> Request a copy of all personal data we hold about you</li>
              <li><strong>Correction:</strong> Update or correct inaccurate information</li>
              <li><strong>Deletion:</strong> Request deletion of your account and personal data</li>
              <li><strong>Export:</strong> Download your data in CSV or JSON format (available in-app)</li>
              <li><strong>Opt-Out:</strong> Unsubscribe from marketing emails; disable data sharing for research</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.2 GDPR Rights (EU/UK Users)</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              If you are in the European Union or United Kingdom, you have additional rights under GDPR:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Right to Restriction:</strong> Request we limit processing of your data</li>
              <li><strong>Right to Object:</strong> Object to processing based on legitimate interests</li>
              <li><strong>Right to Portability:</strong> Receive your data in a machine-readable format</li>
              <li><strong>Right to Withdraw Consent:</strong> Withdraw consent for data processing at any time</li>
              <li><strong>Right to Complain:</strong> Lodge a complaint with your local data protection authority</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.3 CCPA Rights (California Users)</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              If you are a California resident, you have rights under the California Consumer Privacy Act (CCPA):
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Right to Know:</strong> Request disclosure of data collected, sources, purposes, and third parties we share with</li>
              <li><strong>Right to Delete:</strong> Request deletion of personal information</li>
              <li><strong>Right to Opt-Out:</strong> Opt out of the "sale" of personal information (note: we don't sell data)</li>
              <li><strong>Right to Non-Discrimination:</strong> We will not discriminate against you for exercising your rights</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.4 How to Exercise Your Rights</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              To exercise any of these rights:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Email us at <a href="mailto:support@meterscience.com" className="text-primary-600 hover:underline">support@meterscience.com</a></li>
              <li>Use the in-app "Privacy Settings" or "Delete Account" features</li>
              <li>We will respond within 30 days (or as required by applicable law)</li>
            </ul>
          </div>

          {/* Data Security */}
          <div id="data-security" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">7. Data Security</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              We implement industry-standard security measures to protect your data:
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.1 Technical Safeguards</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Encryption:</strong> Data in transit uses TLS 1.3; data at rest is encrypted using AES-256</li>
              <li><strong>Authentication:</strong> Password hashing with bcrypt; optional two-factor authentication</li>
              <li><strong>Access Controls:</strong> Role-based access; minimal employee access to user data</li>
              <li><strong>Monitoring:</strong> 24/7 security monitoring and intrusion detection</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.2 Privacy by Design</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Local Processing:</strong> OCR happens on your device; images are not uploaded unless you choose verification</li>
              <li><strong>Anonymization:</strong> Aggregated data is anonymized before sharing</li>
              <li><strong>Data Minimization:</strong> We only collect what's necessary for the Service</li>
              <li><strong>Secure Defaults:</strong> Privacy-protective settings enabled by default</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.3 Your Responsibility</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              While we implement strong security measures, you also play a role:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Use a strong, unique password</li>
              <li>Enable two-factor authentication</li>
              <li>Keep your device and app updated</li>
              <li>Don't share your account credentials</li>
              <li>Report suspected security issues immediately</li>
            </ul>

            <p className="text-gray-600 leading-relaxed">
              <strong>Data Breach Notification:</strong> In the unlikely event of a data breach affecting your personal information, we will notify you within 72 hours as required by law.
            </p>
          </div>

          {/* Children's Privacy */}
          <div id="childrens-privacy" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">8. Children's Privacy</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              Our Service is not intended for children under 13 years of age (or 16 in the EU). We do not knowingly collect personal information from children.
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately at support@meterscience.com. We will delete such information promptly.
            </p>
          </div>

          {/* International Transfers */}
          <div id="international" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">9. International Data Transfers</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              MeterScience is based in Canada. Your data may be transferred to and processed in Canada, the United States, or other countries where our service providers operate.
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              For EU/UK users, we ensure adequate protection for international transfers through:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Standard Contractual Clauses (SCCs) approved by the European Commission</li>
              <li>Adequacy decisions where applicable</li>
              <li>Other legally approved transfer mechanisms</li>
            </ul>
            <p className="text-gray-600 leading-relaxed">
              We ensure all international data transfers comply with GDPR and other applicable data protection laws.
            </p>
          </div>

          {/* Changes to Policy */}
          <div id="changes" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">10. Changes to This Privacy Policy</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              We may update this Privacy Policy from time to time to reflect changes in our practices, technology, legal requirements, or other factors.
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              When we make changes:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>We will update the "Last updated" date at the top of this policy</li>
              <li>We will notify you via email or in-app notification for material changes</li>
              <li>Continued use of the Service after changes constitutes acceptance of the updated policy</li>
              <li>You can always review the current policy at meterscience.com/privacy</li>
            </ul>
          </div>

          {/* Contact */}
          <div id="contact" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">11. Contact Us</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              If you have questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:
            </p>

            <div className="bg-gray-50 rounded-lg p-6 mb-6">
              <p className="text-gray-800 font-semibold mb-2">MeterScience Inc.</p>
              <p className="text-gray-600 mb-1">Email: <a href="mailto:support@meterscience.com" className="text-primary-600 hover:underline">support@meterscience.com</a></p>
              <p className="text-gray-600 mb-1">Privacy Officer: <a href="mailto:privacy@meterscience.com" className="text-primary-600 hover:underline">privacy@meterscience.com</a></p>
              <p className="text-gray-600">Location: Canada</p>
            </div>

            <p className="text-gray-600 leading-relaxed">
              For EU/UK users, you also have the right to lodge a complaint with your local supervisory authority if you believe we have violated your data protection rights.
            </p>
          </div>

        </div>
      </section>

      {/* Footer CTA */}
      <section className="py-12 px-4 sm:px-6 lg:px-8 bg-gradient-to-br from-primary-50 to-white border-t border-gray-200">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-2xl font-bold mb-4">Your Data, Your Rights</h2>
          <p className="text-gray-600 mb-6">
            We believe your utility data should belong to you. That's our commitment.
          </p>
          <Link
            href="/"
            className="inline-block bg-primary-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-primary-700 transition"
          >
            Back to Home
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-400 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto text-center">
          <div className="flex items-center justify-center space-x-2 mb-4">
            <div className="text-2xl">⚡</div>
            <span className="text-xl font-bold text-white">MeterScience</span>
          </div>
          <p className="text-sm mb-4">© 2025 MeterScience Inc. Your data is always yours.</p>
          <div className="text-sm">
            <Link href="/privacy" className="hover:text-white transition">Privacy Policy</Link>
            {' · '}
            <Link href="/terms" className="hover:text-white transition">Terms of Service</Link>
          </div>
        </div>
      </footer>
    </main>
  )
}
