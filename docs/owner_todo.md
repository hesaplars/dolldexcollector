# DollDex Collector - Owner TODO

## Accounts To Create

1. Firebase project.
2. Google Play Console developer account.
3. Google Cloud billing setup if Firebase Functions requires it.
4. AdMob account.
5. Image hosting account, recommended first option: Cloudinary.

## Decisions To Make

1. Support email address.
2. Privacy contact email address.
3. Public website/domain or Firebase Hosting domain.
4. Final app icon direction.
5. Pro monthly price.
6. Pro yearly price.
7. Minimum target age.

Recommended target age direction: not a children-directed app. Position for teen/adult collectors because the product includes profiles, comments, ads and future messaging.

## Local Commands To Run

From the project folder:

```bash
flutter pub get
flutter run -d chrome
```

For Android debug APK:

```bash
flutter build apk --debug
```

For Firebase:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

For Cloud Functions:

```bash
cd functions
npm install
npm run build
```

## Firebase Setup

1. Enable Google sign-in. Done if the Firebase console toggle is saved.
2. Add Android app. Done for package `com.dolldex.collector`.
3. Add SHA-1 and SHA-256 fingerprints. Debug SHA-1 is present in the current Android config.
4. Enable Firestore.
5. Create the owner `users/{uid}` document after first Google sign-in and set `role: admin`.
6. Add Web app before testing web Google sign-in.
7. Enable Cloud Functions.
8. Enable Cloud Messaging.
9. Deploy Firestore rules and indexes.
10. Deploy Functions.
11. Deploy Hosting after web build.

## Google Play Setup

1. Create app in Play Console.
2. Add package name from Flutter Android project.
3. Create subscriptions:
   - `dolldex_pro_monthly`
   - `dolldex_pro_yearly`
4. Link Play Console with Google Cloud.
5. Enable Android Publisher API.
6. Create service account for purchase verification.
7. Complete Data Safety form.
8. Add privacy policy URL.
9. Add account deletion URL.
10. Prepare closed testing.

## Before Production Release

1. Replace test AdMob ID with real AdMob ad unit ID.
2. Publish privacy policy page.
3. Publish account deletion page.
4. Add final support email.
5. Add original app icon.
6. Add original screenshots.
7. Test Google sign-in on Android and web.
8. Test Pro purchase with Play test account.
9. Test push notifications on Android.
10. Test report flow.
11. Test Firestore rules.
12. Run closed testing.

## Current Immediate Next Steps

1. Run the app on Android and test Google sign-in.
2. Copy the signed-in user's UID from Firebase Authentication.
3. In Firestore, create `users/{uid}` with `role: admin`, display name and email.
4. Open the app Admin tab and save one test catalog item with an HTTPS image URL.
5. Build a debug APK from VS Code.
