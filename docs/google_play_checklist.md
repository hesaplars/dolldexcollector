# DollDex Collector - Google Play Checklist

## Before Closed Testing

- Create Google Play developer account.
- Create Firebase project.
- Add Android app package name.
- Enable Google Sign-In in Firebase Authentication.
- Configure SHA-1 and SHA-256 fingerprints.
- Add `google-services.json` to Android app folder.
- Enable Firestore.
- Deploy Firestore rules.
- Prepare privacy policy URL.
- Prepare account deletion URL.
- Prepare support email.
- Prepare app icon and store graphics without official brand assets.

## Store Listing

- App name: DollDex Collector
- Avoid official brand logos, names in icon, and official artwork.
- Clearly state that the app is unofficial.
- Do not imply partnership, license, endorsement, or ownership by any toy brand.
- Use original screenshots from the app.
- Use original icon artwork.

## Data Safety

Expected collected data:

- Name or display name
- Email address from Google sign-in
- Profile photo from Google sign-in
- User-generated collection entries
- Comments and reports
- Purchase/subscription status
- Device/app identifiers used by Firebase, analytics, ads, and crash tools

Expected purposes:

- App functionality
- Account management
- User communication
- Moderation and safety
- Fraud prevention
- Analytics
- Advertising for non-Pro users

## Permissions

Keep first version minimal:

- Internet
- Notifications

Avoid in first version:

- Camera
- Contacts
- Location
- Microphone
- Storage/media permissions

## Monetization

- Android Pro membership must use Google Play Billing.
- Pro status must be verified on the server.
- Non-Pro users may see ads.
- Pro users must not see ads.
- Ads must not block normal use.
- Do not show interstitial ads during search, messaging, collection saving, or app launch.

## User Safety

- Report user
- Report profile
- Report comment
- Report image
- Block user before private messaging launches
- Admin moderation queue
- Account deletion from app
- Account deletion from web

## Testing

- Internal testing first.
- Closed testing with at least 12 opted-in testers for 14 continuous days if required by the account.
- Collect tester feedback.
- Fix crashes and major usability issues before production.

## Release Gates

- Login works.
- Catalog loads.
- Admin-only editing works.
- Users cannot edit catalog data.
- Collection save works.
- Image URL preview works.
- Broken image URLs do not crash UI.
- Account deletion request works.
- Privacy policy URL is live.
- Data Safety form matches real app behavior.
