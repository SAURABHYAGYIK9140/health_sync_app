# Health Sync App

A production-grade cross-platform mobile application (Android & iOS) for secure health data synchronization.

## Features

### 🔐 **Authentication**
- Secure login with email and password
- Bearer token authentication
- Automatic token storage and retrieval
- Auto-login on app launch if token exists

### 📱 **Health Data Integration**
- **Android**: Health Connect integration
- **iOS**: Apple HealthKit integration
- Track: Steps, Heart Rate (30-day history), Sleep (30-day history), Calories (30-day history)
- Monthly aggregated statistics
- Incremental data synchronization (only new data)

### 🔄 **Data Synchronization**
- Manual sync button on dashboard
- Automatic background sync every 24 hours
- Retry mechanism for failed syncs
- Sync status and history tracking

### 🎯 **User Experience**
- Clean and modern UI
- Step-by-step permissions flow
- Real-time sync status
- Sync history and logs viewer
- Settings and logout options

## API Endpoints

### Authentication
```
POST /api/auth/login
Content-Type: application/json
Accept: application/json

{
  "email": "effety@gmail.com",
  "password": "741852741"
}

Response:
{
  "access_token": "...",
  "id": "3996",
  ...
}
```

### Health Data Submission
```
POST /api/submissions
Authorization: Bearer {access_token}
Content-Type: multipart/form-data

{
  "type": "health_data_upload",
  "device_id": "...",
  "payload": {
    "records_count": 150,
    "timestamp": "2026-04-26T15:30:00.000Z",
    "health_data": [
      {
        "type": "STEPS",
        "value": 8234,
        "unit": "COUNT",
        "from": "...",
        "to": "...",
        "source_id": "com.google.android.apps.fitness",
        "source_name": "Google Fit"
      },
      ...
    ],
    "summary": {
      "heart_rate_bpm": 72,           // Latest BPM from last 30 days
      "calories_burned": 2450,        // Total calories from last 30 days
      "latitude": 40.7128,            // Current location
      "longitude": -74.0060           // Current location
    }
  }
}
```

## Test Credentials

```
Email: effety@gmail.com
Password: 741852741
```

## Getting Started

### Prerequisites
- Flutter 3.11.4 or higher
- Android SDK 24 or higher
- Xcode 12 or higher (for iOS)
- Health Connect app on Android (auto-prompts user if not installed)

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd health_sync_app
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## App Flow

1. **Login Screen**: User enters credentials
2. **Permissions Flow**: Request health, location, camera, and microphone permissions (4 steps)
3. **Dashboard**: 
   - View today's steps
   - See sync status and last sync time
   - Manual sync button
   - Access settings
4. **Settings**: 
   - Manage permissions
   - View sync logs
   - Logout

## Security Features

- ✅ HTTPS only for all API communications
- ✅ Secure token storage with Flutter Secure Storage
- ✅ No sensitive data stored unencrypted
- ✅ Automatic logout on 401 Unauthorized
- ✅ User permission consent required

## Platform-Specific Configuration

### Android
- Minimum SDK: 24
- Target SDK: 36
- Required permissions:
  - ACTIVITY_RECOGNITION
  - BODY_SENSORS
  - FOREGROUND_SERVICE
  - FOREGROUND_SERVICE_HEALTH
  - Health Connect permissions (steps, heart rate, sleep, calories)

### iOS
- Minimum target: iOS 12.0
- Health Kit permissions:
  - HKQuantityTypeIdentifierStepCount
  - HKQuantityTypeIdentifierHeartRate
  - HKCategoryTypeIdentifierSleepAnalysis
  - HKQuantityTypeIdentifierActiveEnergyBurned

## Background Sync

The app syncs health data automatically every 24 hours in the background:
- Works on battery optimization
- Respects network availability
- Automatic retry on failure
- No notification unless sync fails

## Troubleshooting

### Health Connect Not Found (Android)
- App will automatically prompt to install Health Connect
- User can continue without it, but health data won't be collected

### Permission Denied
- Ensure Health Connect (Android) or HealthKit (iOS) is installed
- Grant permissions when prompted
- Check app settings if permissions were previously denied

### Sync Failures
- Check internet connectivity
- Verify credentials
- Check sync logs in settings
- App will retry automatically

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── bindings/            # GetX bindings
│   ├── controllers/         # App lifecycle
│   ├── network/             # API client
│   ├── storage/             # Local storage
│   ├── theme/               # App theming
│   └── widgets/             # Reusable widgets
├── features/
│   ├── auth/               # Login feature
│   ├── dashboard/          # Home feature
│   ├── permissions/        # Permissions flow
│   └── settings/           # Settings feature
└── services/
    ├── auth_service.dart       # Authentication
    ├── health_service.dart     # Health data
    └── background_sync_service.dart # Background sync
```

## License

This project is proprietary and confidential.

## Support

For issues or questions, contact the development team.
