# DollDex Collector - Google Play Data Safety Draft

This is a draft to help complete the Play Console Data Safety form. It must be checked against the final app before launch.

## Data Types Likely Collected

Personal info:

- Name
- Email address
- User IDs
- Profile photo

User-generated content:

- Profile bio
- Collection entries
- Wishlist entries
- Trade or selling labels
- Comments
- Reports
- Image URLs

App activity:

- App interactions
- Search and catalog interactions if analytics are enabled

App info and performance:

- Crash logs
- Diagnostics

Device or other IDs:

- Firebase installation IDs
- Advertising ID for non-Pro ads where applicable
- Push notification tokens

Purchase history:

- Pro subscription status
- Product ID
- Server-verified purchase state

## Purposes

- App functionality
- Account management
- User-generated content
- User communication
- Moderation and safety
- Fraud prevention
- Analytics
- Advertising for non-Pro users
- Developer communications where needed

## Sharing

Data may be processed by service providers required to operate the app:

- Firebase
- Google Sign-In
- Google Play Billing
- Firebase Cloud Messaging
- Google Mobile Ads if ads are enabled
- Crash/analytics services if enabled

Do not say data is not shared if advertising, analytics, crash reporting or payment services are active.

## Security Practices

- Data is transmitted over HTTPS.
- Users can request deletion.
- Firestore Security Rules restrict access.
- Pro status is server verified.
- Admin-only operations are protected.

## Final Review Before Release

- Match this form to the exact SDKs enabled in the production build.
- Update if analytics or crash reporting are added.
- Update if private messaging launches.
- Update if user image upload launches.
