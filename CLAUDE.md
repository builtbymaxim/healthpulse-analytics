# HealthPulse — Developer Instructions

## Tech Stack & Architecture
- **iOS:** SwiftUI, target iOS 17.0+. Uses HealthKit, EventKit, and Keychain. 
- **Backend:** Python 3.11, FastAPI, Supabase (PostgreSQL with RLS). 
- **AI/ML:** Server-side scoring, XGBoost, CoreML + Cloud Vision for food scanning.

## Coding Rules
- **Verify Before Committing:** Always run `pytest` for backend changes before saying you are done. For iOS, give me the exact files changed so I can build it in Xcode to verify.
- **UI/UX Consistency:** We use `MotionTokens` for animations, `ultraThinMaterial` for glass UI, and **zero emojis** anywhere in the app. 
- **Token Efficiency:** Do not write long apologies or generic explanations. Output only the necessary code, brief explanations, and exact file paths.
- **TestFlight Focus:** Do not suggest new features. Our only goal is stability, App Store compliance, and bug fixing for our TestFlight launch.