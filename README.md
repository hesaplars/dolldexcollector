# DollDex Collector

DollDex Collector is an unofficial catalog, collection tracker, and community app for doll collectors.

## Current Status

This repository now contains the first Flutter app shell:

- Catalog screen
- Collection screen
- Profile screen with Google sign-in wiring
- Pro membership screen placeholder
- Admin screen with secure image URL preview
- Admin catalog entry form
- Shared image URL validator
- Catalog and collection data models
- Google sign-in service
- Firestore catalog repository
- Collection repository scaffold
- Pro entitlement and billing service scaffold
- AdMob service scaffold
- Push notification service scaffold
- Android Firebase configuration for `dolldex-collector`
- Cloud Functions scaffold for reports, notifications and purchase verification
- Clean DollDex visual theme
- Product and compliance plan in `DOLLDEX_COLLECTOR_PLAN.md`
- Google Play checklist in `docs/google_play_checklist.md`
- Firebase setup guide in `docs/firebase_setup.md`
- Current project status in `docs/project_status.md`
- Store listing draft in `docs/store_listing_draft.md`
- Data Safety draft in `docs/data_safety_draft.md`
- Owner TODO checklist in `docs/owner_todo.md`

## Current Run Mode

The Flutter app now has Android Firebase configuration and Google sign-in wiring. Some visible screens still use local fallback state while the Firestore-backed UI is finished.

Keep day-to-day work in `C:\Projeler\MonsterKoleksiyon` to avoid Windows path encoding issues from the user profile path. Google Play Billing, AdMob and Firebase Cloud Messaging are still scaffolds until their console setup and device tests are completed.

## Image URL Rule

Admins and users will paste secure image URLs. The app shows those URLs as images, not as raw text links.

Accepted image URL basics:

- Must start with `https://`
- Must point to `.png`, `.jpg`, `.jpeg`, or `.webp`
- Broken URLs show a clean placeholder

## Recommended Image Hosting

Recommended first option: Cloudinary free plan.

Reason: It is designed for images, has CDN delivery, upload tools, transformations, and a free plan. Later, if the app needs fully controlled uploads, Firebase Storage can be added.

## Local Setup

When Flutter commands are available locally:

```bash
flutter pub get
flutter run -d chrome
```

For Android:

```bash
flutter run
```

For Android debug APK:

```bash
flutter build apk --debug
```

## Next Build Steps

1. Test Google sign-in on Android.
2. Make the signed-in owner account an admin in Firestore.
3. Test admin catalog saves to Firestore.
4. Keep replacing local fallback state with Firestore-backed state.
5. Connect collection save states to the signed-in user and Firestore.
6. Connect comments and reports end to end.
7. Add AdMob and Play Billing console IDs after Google Play setup.
8. Test Firebase Cloud Messaging token sync on Android.

## Firebase Setup Notes

If Firebase options need to be regenerated:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Android already has `android/app/google-services.json`. Web sign-in still needs Firebase web configuration before production web use.

Cloud Functions setup is documented in `docs/firebase_setup.md`.

## Latest App Flow Additions

- Catalog cards open detail pages.
- Catalog detail pages include image, metadata, tags, comments, report action and collection action.
- Collection action sheet supports owned, wanted, trade and selling states.
- Comment model and Firestore repository scaffold are included.
- Turkish is the default UI language, with a TR/EN language toggle in the app bar.
- Profile Google button calls the Google sign-in service.
- Admin form saves through the catalog repository when Firebase is ready and the user has admin permission.
