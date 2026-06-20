# DollDex Collector - Firebase Setup

## Firebase Project

1. Create a Firebase project.
2. Add Android app.
3. Add Web app.
4. Enable Authentication > Google.
5. Enable Cloud Firestore.
6. Enable Cloud Messaging.
7. Enable Functions.
8. Add SHA-1 and SHA-256 fingerprints for Android Google sign-in.

## FlutterFire

Run locally:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`.

After that, initialize Firebase in `lib/main.dart` before `runApp`.

## Firestore Rules

Deploy rules:

```bash
firebase deploy --only firestore:rules
```

## Cloud Functions

Install dependencies:

```bash
cd functions
npm install
npm run build
```

Deploy:

```bash
firebase deploy --only functions
```

## Google Play Billing Verification

The `verifyGooglePlayPurchase` function is intentionally blocked until Google Play Developer API access is connected.

Before enabling Pro:

- Create Play Console app.
- Create subscription products:
  - `dolldex_pro_monthly`
  - `dolldex_pro_yearly`
- Link Google Play Console to Google Cloud project.
- Enable Android Publisher API.
- Configure service account permissions.
- Update Cloud Function to verify purchase token with Google Play Developer API.
- Only then write active Pro entitlement to Firestore.

## AdMob

The app currently uses Google's test banner ID in the service scaffold. Replace it with the real AdMob unit ID before production.
