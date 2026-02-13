# HealthPulse Privacy Policy

**Last updated:** February 13, 2026

## Overview

HealthPulse is a personal fitness and wellness companion app. We take your privacy seriously. This policy explains what data we collect, how we use it, and your rights.

## What We Collect

When you use HealthPulse, we collect and store:

- **Account information**: Email address and display name
- **Profile data**: Age, height, weight, gender, activity level, fitness goal
- **Workout data**: Exercise logs, sets, reps, weights, personal records, training plan selections
- **Nutrition data**: Food entries, calorie and macro tracking, meal plans
- **Sleep data**: Bed time, wake time, sleep quality, optional sleep stages
- **Health metrics**: Steps, heart rate, HRV, resting heart rate (read from Apple Health with your permission)
- **Social data**: Training partner connections and invite codes (only if you opt in to social features)

## What We Don't Collect

- We do **not** use any third-party analytics, advertising, or tracking SDKs
- We do **not** sell, share, or provide your data to any third parties
- We do **not** store GPS coordinates — running workouts calculate distance locally on your device; only aggregate distance is saved
- We do **not** collect device identifiers, IP addresses, or browsing behavior

## Apple Health (HealthKit)

HealthPulse requests **read-only** access to Apple Health data including steps, heart rate, heart rate variability, resting heart rate, active calories, weight, body fat percentage, and sleep analysis. We never write data to Apple Health. Health data read from HealthKit is used solely to power your dashboard and insights within the app.

## Location Data

HealthPulse requests location access only during running workouts to track your route and calculate distance in real-time. GPS coordinates are processed locally on your device and are **never** transmitted to or stored on our servers. Only the total distance is saved.

## Data Storage & Security

- Your data is stored in **Supabase** (PostgreSQL hosted on AWS), encrypted at rest
- All API communication uses **HTTPS** (TLS 1.2+)
- Authentication tokens are stored in the **iOS Keychain**, not in plain storage
- Row-Level Security (RLS) is enabled on all database tables — users can only access their own data
- Backend authentication uses **JWT verification** with ES256 signature validation

## Your Rights

Under GDPR and applicable privacy laws, you have the right to:

### Export Your Data (Article 20 — Data Portability)
You can export all your data as a JSON file at any time from **Profile > Data & Privacy > Export My Data**. This includes your profile, workouts, nutrition logs, sleep records, training plans, meal plans, personal records, and all other user data.

### Delete Your Data (Article 17 — Right to Erasure)
You can permanently delete your account and all associated data from **Profile > Data & Privacy > Delete Account**. This action:
- Deletes your profile and all related data (workouts, nutrition, sleep, plans, records, social connections)
- Removes your authentication record
- Is **irreversible** — deleted data cannot be recovered

### Access Your Data (Article 15)
All your data is visible within the app. You can also use the export feature to get a complete copy.

## Data Retention

- Your data is retained as long as your account is active
- When you delete your account, all data is permanently removed immediately
- We do not retain backups of deleted user data

## No Third-Party Sharing

We do not share your personal data with any third parties. The only external service accessed is **Open Food Facts** (open-source food database) when you scan product barcodes — this is an anonymous lookup that does not transmit any of your personal information.

## Children's Privacy

HealthPulse is not intended for children under 13. We do not knowingly collect personal information from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be reflected in the "Last updated" date at the top.

## Contact

If you have questions about this privacy policy or your data, please open an issue on our GitHub repository or contact the development team.
