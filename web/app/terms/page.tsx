'use client'

import Link from 'next/link'

export default function TermsOfService() {
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
          <h1 className="text-4xl md:text-5xl font-bold mb-4">Terms of Service</h1>
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
            <a href="#agreement" className="text-primary-600 hover:underline">1. Agreement to Terms</a>
            <a href="#service-description" className="text-primary-600 hover:underline">2. Service Description</a>
            <a href="#account" className="text-primary-600 hover:underline">3. Account Registration</a>
            <a href="#subscriptions" className="text-primary-600 hover:underline">4. Subscriptions and Billing</a>
            <a href="#acceptable-use" className="text-primary-600 hover:underline">5. Acceptable Use Policy</a>
            <a href="#content" className="text-primary-600 hover:underline">6. User Content and Data</a>
            <a href="#intellectual-property" className="text-primary-600 hover:underline">7. Intellectual Property</a>
            <a href="#disclaimers" className="text-primary-600 hover:underline">8. Disclaimers and Warranties</a>
            <a href="#limitation" className="text-primary-600 hover:underline">9. Limitation of Liability</a>
            <a href="#indemnification" className="text-primary-600 hover:underline">10. Indemnification</a>
            <a href="#termination" className="text-primary-600 hover:underline">11. Termination</a>
            <a href="#governing-law" className="text-primary-600 hover:underline">12. Governing Law</a>
            <a href="#dispute-resolution" className="text-primary-600 hover:underline">13. Dispute Resolution</a>
            <a href="#changes" className="text-primary-600 hover:underline">14. Changes to Terms</a>
            <a href="#miscellaneous" className="text-primary-600 hover:underline">15. Miscellaneous</a>
            <a href="#contact" className="text-primary-600 hover:underline">16. Contact Information</a>
          </div>
        </div>
      </section>

      {/* Content */}
      <section className="py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto prose prose-lg">

          {/* Agreement */}
          <div id="agreement" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">1. Agreement to Terms</h2>
            <p className="text-gray-600 leading-relaxed mb-4">
              These Terms of Service ("Terms") constitute a legally binding agreement between you and MeterScience Inc. ("MeterScience," "we," "us," "our") governing your use of our mobile application, website, and services (collectively, the "Service").
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              <strong>By accessing or using the Service, you agree to be bound by these Terms.</strong> If you do not agree to these Terms, you may not use the Service.
            </p>
            <p className="text-gray-600 leading-relaxed">
              These Terms apply to all users, including those who contribute content, data, or other materials to the Service.
            </p>
          </div>

          {/* Service Description */}
          <div id="service-description" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">2. Service Description</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              MeterScience provides a platform for monitoring and analyzing utility consumption through:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Mobile Application:</strong> iOS and Android apps with optical character recognition (OCR) for scanning utility meters</li>
              <li><strong>Data Tracking:</strong> Tools to record, visualize, and analyze your electric, gas, and water consumption</li>
              <li><strong>Community Features:</strong> Neighborhood comparisons, verification systems, and citizen science participation</li>
              <li><strong>MeterPi Hardware:</strong> Optional Raspberry Pi-based automated meter reading device</li>
              <li><strong>API Access:</strong> For premium subscribers, programmatic access to your data</li>
            </ul>

            <p className="text-gray-600 leading-relaxed mb-4">
              <strong>Service Availability:</strong> We strive for 99.9% uptime but cannot guarantee uninterrupted service. We reserve the right to modify, suspend, or discontinue any feature at any time with reasonable notice.
            </p>

            <p className="text-gray-600 leading-relaxed">
              <strong>Beta Features:</strong> Some features may be labeled as "beta" or "experimental." These features are provided as-is and may not function as expected.
            </p>
          </div>

          {/* Account Registration */}
          <div id="account" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">3. Account Registration</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.1 Eligibility</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              You must be at least 13 years old (or 16 in the EU) to use the Service. By creating an account, you represent that you meet this age requirement and that all information you provide is accurate and complete.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.2 Account Security</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              You are responsible for:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Maintaining the confidentiality of your password and account credentials</li>
              <li>All activities that occur under your account</li>
              <li>Notifying us immediately of any unauthorized access or security breach</li>
              <li>Using strong, unique passwords and enabling two-factor authentication</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.3 Account Accuracy</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              You agree to provide accurate, current, and complete information during registration and to update it as necessary. Providing false information may result in account suspension or termination.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">3.4 One Account Per Person</h3>
            <p className="text-gray-600 leading-relaxed">
              You may only create one account. Multiple accounts created by the same person may be merged or deleted.
            </p>
          </div>

          {/* Subscriptions and Billing */}
          <div id="subscriptions" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">4. Subscriptions and Billing</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.1 Subscription Tiers</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              MeterScience offers the following subscription tiers:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Free:</strong> Core features with personal data access only (no subscription required)</li>
              <li><strong>Neighbor ($2.99/month):</strong> Neighborhood comparisons within your postal code</li>
              <li><strong>Block ($4.99/month):</strong> Expanded data access within a 5km radius</li>
              <li><strong>District ($9.99/month):</strong> Full data access (25km radius) plus API access</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.2 Billing and Payments</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Recurring Charges:</strong> Subscriptions automatically renew monthly unless canceled</li>
              <li><strong>Payment Processing:</strong> Payments are processed securely through Stripe</li>
              <li><strong>Price Changes:</strong> We will notify you 30 days before any price increases</li>
              <li><strong>Taxes:</strong> Prices do not include applicable taxes, which will be added at checkout</li>
              <li><strong>Failed Payments:</strong> If payment fails, we will retry. Continued failure may result in downgrade to Free tier</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.3 Cancellation and Refunds</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li><strong>Cancel Anytime:</strong> You may cancel your subscription at any time from your account settings</li>
              <li><strong>Access Until End of Period:</strong> After cancellation, you retain access until the end of your current billing period</li>
              <li><strong>No Partial Refunds:</strong> We do not provide refunds for partial months</li>
              <li><strong>Refund Policy:</strong> Refunds may be granted within 7 days of initial subscription at our discretion</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.4 Free Trial</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              We may offer free trials of premium tiers. You will be charged when the trial ends unless you cancel before the trial period expires.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">4.5 MeterPi Hardware Purchase</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>MeterPi hardware is sold separately as a one-time purchase</li>
              <li>Shipping costs and customs duties are the buyer's responsibility</li>
              <li>Hardware returns accepted within 30 days in original condition</li>
              <li>Hardware warranty covers manufacturing defects for 1 year</li>
            </ul>
          </div>

          {/* Acceptable Use */}
          <div id="acceptable-use" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">5. Acceptable Use Policy</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              You agree NOT to use the Service to:
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">5.1 Prohibited Activities</h3>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Violate any laws, regulations, or third-party rights</li>
              <li>Impersonate any person or entity, or falsely claim an affiliation</li>
              <li>Submit false, inaccurate, or misleading meter readings</li>
              <li>Interfere with or disrupt the Service or servers/networks connected to it</li>
              <li>Attempt to gain unauthorized access to any part of the Service</li>
              <li>Use automated scripts, bots, or scrapers without permission</li>
              <li>Reverse engineer, decompile, or disassemble the Service</li>
              <li>Remove, circumvent, or alter any security or access control measures</li>
              <li>Upload viruses, malware, or other malicious code</li>
              <li>Harass, abuse, or harm other users</li>
              <li>Spam or send unsolicited communications to other users</li>
              <li>Collect or store personal data of other users without consent</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">5.2 Community Standards</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              When participating in community features (verification, forums, etc.):
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Be respectful and constructive</li>
              <li>Provide honest and accurate verifications</li>
              <li>Do not abuse the gamification or referral systems</li>
              <li>Report inappropriate content or behavior</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">5.3 Enforcement</h3>
            <p className="text-gray-600 leading-relaxed">
              Violations may result in warnings, content removal, account suspension, or permanent ban. We reserve the right to take appropriate action at our discretion.
            </p>
          </div>

          {/* User Content */}
          <div id="content" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">6. User Content and Data</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.1 Your Data Ownership</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              <strong>You retain all ownership rights to your meter readings and personal data.</strong> We do not claim ownership of your data.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.2 License to MeterScience</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              By using the Service, you grant us a limited, non-exclusive, royalty-free license to:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Store and process your data to provide the Service</li>
              <li>Create anonymized, aggregated statistics for research and product improvement</li>
              <li>Display your data to you across devices and platforms</li>
              <li>Back up your data for disaster recovery</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.3 Shared Content</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              If you submit content for community verification or share data publicly:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>You grant us the right to display that content to other users</li>
              <li>You represent that you have the right to share this content</li>
              <li>You understand that shared content may be viewed by other users</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">6.4 Research Data Use</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              With your explicit consent, we may use anonymized data for:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Academic research and scientific publications</li>
              <li>Open data initiatives (always anonymized and aggregated)</li>
              <li>Public policy analysis and environmental research</li>
            </ul>
            <p className="text-gray-600 leading-relaxed">
              You can opt out of research data sharing at any time in your privacy settings.
            </p>
          </div>

          {/* Intellectual Property */}
          <div id="intellectual-property" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">7. Intellectual Property</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.1 MeterScience Property</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              The Service and its content (excluding user data) are owned by MeterScience and protected by copyright, trademark, and other intellectual property laws. This includes:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Software code, algorithms, and architecture</li>
              <li>MeterScience name, logo, and branding</li>
              <li>User interface designs and graphics</li>
              <li>Documentation and marketing materials</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.2 Trademarks</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              "MeterScience," the MeterScience logo, and related marks are trademarks of MeterScience Inc. You may not use these without our written permission.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.3 Open Source</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              Portions of our Service use open-source software. Applicable open-source licenses are available upon request.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">7.4 DMCA Compliance</h3>
            <p className="text-gray-600 leading-relaxed">
              If you believe content on our Service infringes your copyright, please contact us at support@meterscience.com with details of the alleged infringement.
            </p>
          </div>

          {/* Disclaimers */}
          <div id="disclaimers" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">8. Disclaimers and Warranties</h2>

            <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-6">
              <p className="text-gray-800 font-semibold mb-2">IMPORTANT DISCLAIMER</p>
              <p className="text-gray-700 text-sm">
                THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.
              </p>
            </div>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">8.1 No Warranty</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              To the fullest extent permitted by law, MeterScience disclaims all warranties, including but not limited to:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Warranties of merchantability, fitness for a particular purpose, and non-infringement</li>
              <li>That the Service will be uninterrupted, secure, or error-free</li>
              <li>That data will be accurate, complete, or reliable</li>
              <li>That defects will be corrected</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">8.2 OCR Accuracy</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              <strong>OCR technology is not 100% accurate.</strong> While our system provides confidence scores, you should verify critical readings. We are not responsible for billing errors resulting from incorrect OCR readings.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">8.3 Not Utility Advice</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              MeterScience provides informational tools only. We do not provide:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Professional utility billing or meter reading services</li>
              <li>Official meter readings for billing purposes</li>
              <li>Guarantees about cost savings or consumption reduction</li>
              <li>Legal, financial, or professional advice</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">8.4 Third-Party Content</h3>
            <p className="text-gray-600 leading-relaxed">
              Community-generated content (verifications, comparisons) is provided by users. We do not endorse or guarantee its accuracy.
            </p>
          </div>

          {/* Limitation of Liability */}
          <div id="limitation" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">9. Limitation of Liability</h2>

            <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-6">
              <p className="text-gray-700 text-sm">
                TO THE MAXIMUM EXTENT PERMITTED BY LAW, METERSCIENCE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES.
              </p>
            </div>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">9.1 Maximum Liability</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              Our total liability to you for all claims arising from or related to the Service is limited to the greater of:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>$100 USD, or</li>
              <li>The amount you paid us in the 12 months before the claim arose</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">9.2 Exclusions</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              We are not liable for:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Incorrect meter readings or OCR errors</li>
              <li>Utility billing disputes or overcharges</li>
              <li>Data loss due to device failure, user error, or service interruption</li>
              <li>Actions of third-party service providers</li>
              <li>Unauthorized access to your account due to your failure to secure credentials</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">9.3 Jurisdictional Variations</h3>
            <p className="text-gray-600 leading-relaxed">
              Some jurisdictions do not allow limitations on implied warranties or liability. In such cases, the above limitations may not apply in full, and you may have additional rights.
            </p>
          </div>

          {/* Indemnification */}
          <div id="indemnification" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">10. Indemnification</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              You agree to indemnify, defend, and hold harmless MeterScience, its officers, directors, employees, and agents from any claims, liabilities, damages, losses, or expenses (including legal fees) arising from:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Your use or misuse of the Service</li>
              <li>Your violation of these Terms</li>
              <li>Your violation of any third-party rights, including intellectual property or privacy rights</li>
              <li>Content you submit or share through the Service</li>
              <li>Your negligence or willful misconduct</li>
            </ul>
          </div>

          {/* Termination */}
          <div id="termination" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">11. Termination</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">11.1 Termination by You</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              You may terminate your account at any time by:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Using the "Delete Account" feature in app settings</li>
              <li>Emailing us at support@meterscience.com</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">11.2 Termination by MeterScience</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              We may suspend or terminate your account if:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>You violate these Terms or our Acceptable Use Policy</li>
              <li>Your use of the Service creates legal or security risks</li>
              <li>Your account has been inactive for over 2 years</li>
              <li>We are required to do so by law</li>
              <li>We discontinue the Service (with 30 days' notice)</li>
            </ul>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">11.3 Effect of Termination</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              Upon termination:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>Your access to the Service ends immediately</li>
              <li>You may download your data within 30 days (if account is in good standing)</li>
              <li>Your personal data will be deleted per our Privacy Policy</li>
              <li>Anonymized aggregated data may be retained for research</li>
              <li>No refunds for unused subscription time (except as required by law)</li>
            </ul>
          </div>

          {/* Governing Law */}
          <div id="governing-law" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">12. Governing Law</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              These Terms are governed by the laws of Canada and the province of Ontario, without regard to conflict of law provisions.
            </p>
            <p className="text-gray-600 leading-relaxed mb-4">
              For users outside Canada, local consumer protection laws may also apply and may provide additional rights.
            </p>
          </div>

          {/* Dispute Resolution */}
          <div id="dispute-resolution" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">13. Dispute Resolution</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">13.1 Informal Resolution</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              Before filing a claim, you agree to contact us at support@meterscience.com to attempt to resolve the dispute informally. We commit to responding within 10 business days.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">13.2 Arbitration (if applicable)</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              For users in jurisdictions where arbitration is permitted, disputes may be resolved through binding arbitration rather than in court, except where prohibited by law.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">13.3 Class Action Waiver</h3>
            <p className="text-gray-600 leading-relaxed">
              Where permitted by law, you agree to resolve disputes on an individual basis and waive the right to participate in class actions, except where such waivers are prohibited.
            </p>
          </div>

          {/* Changes to Terms */}
          <div id="changes" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">14. Changes to Terms</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              We may update these Terms from time to time. When we make changes:
            </p>
            <ul className="list-disc pl-6 mb-6 text-gray-600 space-y-2">
              <li>We will update the "Last updated" date</li>
              <li>We will notify you via email or in-app notification for material changes</li>
              <li>We will provide at least 30 days' notice for changes that reduce your rights</li>
              <li>Continued use after changes take effect constitutes acceptance</li>
              <li>If you don't agree to changes, you may terminate your account</li>
            </ul>
          </div>

          {/* Miscellaneous */}
          <div id="miscellaneous" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">15. Miscellaneous</h2>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.1 Entire Agreement</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              These Terms, together with our Privacy Policy, constitute the entire agreement between you and MeterScience regarding the Service.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.2 Severability</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              If any provision is found unenforceable, the remaining provisions remain in full effect.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.3 No Waiver</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              Our failure to enforce any right or provision does not constitute a waiver of that right or provision.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.4 Assignment</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              You may not assign or transfer these Terms without our consent. We may assign these Terms to an affiliate or in connection with a merger or sale.
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.5 Force Majeure</h3>
            <p className="text-gray-600 leading-relaxed mb-4">
              We are not liable for delays or failures due to events beyond our reasonable control (natural disasters, war, pandemics, internet outages, etc.).
            </p>

            <h3 className="text-2xl font-semibold mb-3 text-gray-800">15.6 Export Controls</h3>
            <p className="text-gray-600 leading-relaxed">
              You may not use or export the Service in violation of Canadian or international export laws and regulations.
            </p>
          </div>

          {/* Contact */}
          <div id="contact" className="mb-12">
            <h2 className="text-3xl font-bold mb-4 text-gray-900">16. Contact Information</h2>

            <p className="text-gray-600 leading-relaxed mb-4">
              If you have questions about these Terms, please contact us:
            </p>

            <div className="bg-gray-50 rounded-lg p-6 mb-6">
              <p className="text-gray-800 font-semibold mb-2">MeterScience Inc.</p>
              <p className="text-gray-600 mb-1">Email: <a href="mailto:support@meterscience.com" className="text-primary-600 hover:underline">support@meterscience.com</a></p>
              <p className="text-gray-600 mb-1">Legal: <a href="mailto:legal@meterscience.com" className="text-primary-600 hover:underline">legal@meterscience.com</a></p>
              <p className="text-gray-600">Location: Canada</p>
            </div>

            <p className="text-gray-600 leading-relaxed text-sm">
              <strong>Acknowledgment:</strong> By using MeterScience, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.
            </p>
          </div>

        </div>
      </section>

      {/* Footer CTA */}
      <section className="py-12 px-4 sm:px-6 lg:px-8 bg-gradient-to-br from-primary-50 to-white border-t border-gray-200">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-2xl font-bold mb-4">Questions About Our Terms?</h2>
          <p className="text-gray-600 mb-6">
            We're here to help. Contact us if you need clarification on any of these terms.
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
