# Polar App

A native iOS health monitoring app built with SwiftUI.

## Overview

Polar is a productivity and health monitoring application that helps users track their health metrics, set goals, and maintain a healthy lifestyle.

## Features

- **Dashboard**: Quick overview of your key health metrics
- **Health Metrics**: Detailed tracking of:
  - Heart Rate
  - Steps
  - Sleep
  - Activity/Calories
- **Settings**: Configure app preferences and sync with HealthKit

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
polarApp/
├── Sources/
│   ├── PolarApp.swift          # Main app entry point
│   ├── Views/                  # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── HealthMetricsView.swift
│   │   └── SettingsView.swift
│   ├── Models/                 # Data models
│   │   └── HealthMetric.swift
│   ├── ViewModels/            # View models (MVVM)
│   └── Services/              # Business logic & API services
├── Resources/                  # Assets, fonts, etc.
└── Supporting Files/          # Info.plist, etc.
```

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd polarApp
```

### 2. Open in Xcode

Since this is a native iOS project, you'll need to create an Xcode project:

1. Open Xcode
2. Create a new project: File → New → Project
3. Choose "App" template under iOS
4. Set the following:
   - Product Name: `polarApp`
   - Organization Identifier: Your identifier (e.g., `com.yourname`)
   - Interface: `SwiftUI`
   - Language: `Swift`
5. Save the project in this directory

### 3. Add Source Files to Xcode

1. Delete the default `ContentView.swift` and `polarAppApp.swift` files Xcode created
2. Drag and drop the `polarApp/Sources` folder into your Xcode project
3. Make sure "Copy items if needed" is unchecked
4. Select "Create groups"

### 4. Configure Info.plist

Add the following privacy descriptions if you plan to integrate HealthKit:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Polar needs access to read your health data to display your metrics.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Polar needs access to update your health data.</string>
```

### 5. Build and Run

1. Select a simulator or your device
2. Press `⌘ + R` to build and run

## Development

### Adding New Features

- **Views**: Add new SwiftUI views in `Sources/Views/`
- **Models**: Add data models in `Sources/Models/`
- **View Models**: Add view models in `Sources/ViewModels/`
- **Services**: Add business logic in `Sources/Services/`

### Integrating HealthKit

To integrate with Apple HealthKit:

1. Add the HealthKit framework to your project
2. Enable HealthKit capability in Xcode
3. Create a `HealthKitService.swift` in `Sources/Services/`
4. Request appropriate permissions

## Future Enhancements

- [ ] HealthKit integration for real data
- [ ] Charts and data visualization
- [ ] Goal setting and tracking
- [ ] Notifications and reminders
- [ ] Data export functionality
- [ ] Widget support
- [ ] Apple Watch companion app

## License

Copyright © 2025. All rights reserved.

## Contributing

This is a personal project. Contributions are welcome!
