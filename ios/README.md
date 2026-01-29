# HealthPulse iOS App

SwiftUI-based iOS app for HealthPulse fitness tracking.

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Apple Developer account (for HealthKit)

### Creating the Xcode Project

1. **Open Xcode** and create a new project:
   - Select "App" template
   - Product Name: `HealthPulse`
   - Organization Identifier: `com.yourname`
   - Interface: SwiftUI
   - Language: Swift

2. **Add Capabilities** in Signing & Capabilities:
   - HealthKit
   - Background Modes → Background fetch
   - Push Notifications (optional)

3. **Add Swift Package Dependencies**:
   ```
   File → Add Package Dependencies
   ```

   Add these packages:
   - `https://github.com/supabase-community/supabase-swift` (Supabase SDK)
   - `https://github.com/danielgindi/Charts` (Charts library)

4. **Configure Info.plist**:
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>HealthPulse needs access to your health data to track your fitness progress and provide personalized insights.</string>

   <key>NSHealthUpdateUsageDescription</key>
   <string>HealthPulse can save your workout data to Apple Health.</string>
   ```

### Project Structure

```
HealthPulse/
├── App/
│   ├── HealthPulseApp.swift
│   └── ContentView.swift
├── Models/
├── Views/
├── ViewModels/
├── Services/
└── Utilities/
```

### Environment Variables

Create a `Config.xcconfig` file (do not commit):
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
API_BASE_URL = https://your-api-url.com
```

### Running the App

1. Select a simulator or physical device
2. Press `Cmd + R` to build and run

### HealthKit Data Types

The app reads the following HealthKit data:
- Steps (`HKQuantityTypeIdentifier.stepCount`)
- Active Energy (`HKQuantityTypeIdentifier.activeEnergyBurned`)
- Heart Rate (`HKQuantityTypeIdentifier.heartRate`)
- Resting Heart Rate (`HKQuantityTypeIdentifier.restingHeartRate`)
- HRV (`HKQuantityTypeIdentifier.heartRateVariabilitySDNN`)
- Sleep Analysis (`HKCategoryTypeIdentifier.sleepAnalysis`)
- Workouts (`HKWorkoutType.workoutType()`)
- Weight (`HKQuantityTypeIdentifier.bodyMass`)
