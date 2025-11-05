# xs_user

A new Flutter project.

### Prerequisites
- Firebase project configured for Android (google-services.json) and iOS (GoogleService-Info.plist).
- Google OAuth 2.0 Web Client ID (used for Google Sign-In on mobile).
- Optional: comma-separated list of allowed Google domains.

### Environment
Create a `.env` file at the project root based on `.env.example`:

```
SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
ALLOWED_GOOGLE_DOMAINS=example.edu,example.com
```

Notes:
- `SERVER_CLIENT_ID` should point to the Web Client ID created alongside your Firebase project.
- `ALLOWED_GOOGLE_DOMAINS` is optional; leave blank to allow any verified Google account.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
