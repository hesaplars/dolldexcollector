# DollDex Collector - Project Status

## Completed In Repository

- Product direction and launch plan.
- Google Play checklist.
- Firebase setup guide.
- Privacy policy draft.
- Account deletion page draft.
- Flutter app shell.
- DollDex visual theme.
- Catalog screen.
- Catalog detail screen.
- Clickable catalog cards.
- Collection screen.
- Collection action sheet for owned, wanted, trade and selling states.
- Profile screen.
- Pro screen.
- Admin screen.
- Notifications screen.
- Legal placeholder screens.
- Admin catalog entry form.
- Image URL validation and preview.
- Catalog models.
- Collection models.
- User model.
- Report models.
- Comment models.
- Notification models.
- Social models for follows, friends and chat.
- Google sign-in service scaffold.
- Firestore catalog repository scaffold.
- Firestore collection repository scaffold.
- Firestore notification repository scaffold.
- Firestore comment repository scaffold.
- Report Cloud Function client service.
- Push notification service scaffold.
- AdMob service scaffold.
- Google Play Billing service scaffold.
- Pro entitlement model.
- Firestore security rules draft.
- Firebase hosting config.
- Firestore indexes config.
- Cloud Functions TypeScript project.
- Callable Cloud Function for reports.
- Callable Cloud Function for push token registration.
- Callable Cloud Function for admin notification sending.
- Safe placeholder Cloud Function for Google Play purchase verification.
- Static privacy page for web build.
- Static account deletion page for web build.
- Store listing draft.
- Data Safety draft.
- Owner TODO checklist.
- Git ignore rules for generated files and secrets.
- Flutter platform folders are generated.
- Android app is connected to Firebase project `dolldex-collector`.
- Android package name is `com.dolldex.collector`.
- Debug SHA-1 fingerprint is present in `android/app/google-services.json`.
- Android `MainActivity` package now matches `com.dolldex.collector`.
- Firebase-enabled app mode is restored after fixing the Android `MainActivity` package mismatch.
- Admin catalog form saves into the in-memory catalog and newly saved entries appear in the catalog list.
- Catalog search and type filters work.
- Collection actions save into in-memory collection state and appear on the Collection screen.
- Report actions save into an in-memory moderation queue visible on the Admin screen.
- Comments are stored per catalog entry in in-memory state during the app session.
- Profile screen shows stats for collection entries, catalog entries, comments and reports.
- Admin screen includes a catalog management list with detail navigation and delete action for non-template entries.
- Collection screen includes status filters and remove-from-collection actions.
- Admin catalog management includes edit mode, preview update and cancel edit flow.
- Pro screen includes a monetization readiness card for planned ad placements and server-verified Pro status.
- Notifications screen displays in-app notifications for catalog saves, collection updates, comments and reports.
- Collection screen includes condition filters for boxed, unboxed, complete, incomplete and damaged items.
- Profile screen includes a showcase grid built from the user's collection entries.
- Admin report cards show report details and can open catalog-entry targets.

## Intentionally Not Completed Yet

- `lib/firebase_options.dart` is not generated yet.
- Firebase, Firestore, Firebase Auth and Google Sign-In packages are enabled in `pubspec.yaml`.
- Firebase Android Gradle plugin is enabled.
- Google sign-in still needs a controlled Android device/emulator test.
- Firebase web configuration still needs to be generated for web sign-in.
- Catalog list reads from Firestore when available and falls back to seed entries if Firestore is empty or unavailable.
- Collection save state writes to Firestore for signed-in users and falls back to local state when signed out.
- Comments are still local UI state and not connected to Firestore.
- Reports UI is scaffolded, but end-to-end moderation testing is not complete.
- Admin role assignment flow is not built yet.
- Pro purchase cannot activate Pro yet.
- Google Play Developer API is not connected yet.
- Real AdMob unit IDs are not added yet.
- FCM is not tested on Android yet.
- Real app icon is not designed yet.
- Store screenshots are not prepared yet.
- Public privacy policy page is not published yet.
- Public account deletion page is not published yet.
- Closed testing is not started yet.
- iOS support is not configured yet.
- Final support email is not selected yet.
- Final Pro prices are not selected yet.
- Final app icon is not designed yet.

## Blocked By Local Environment

Flutter/Dart verification commands are currently unreliable in this environment. `flutter analyze` and `dart format` can hang or time out, likely because of local toolchain/process issues.

Earlier Windows path encoding issues were also seen around the Turkish character in the user profile path. Keep day-to-day work inside:

```text
C:\Projeler\MonsterKoleksiyon
```

## Next Recommended Steps

1. Test Google sign-in on Android from VS Code.
2. Create or update the signed-in user's `users/{uid}` document with `role: admin`.
3. Test admin catalog save to Firestore.
4. Keep replacing local fallback states with Firestore-backed state where needed.
5. Connect collection entries to Firebase Auth user IDs and Firestore.
6. Run a debug APK build from the project folder.

## Owner Checklist

See `docs/owner_todo.md`.
