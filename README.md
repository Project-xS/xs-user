# xs_user

A new Flutter project.

### Prerequisites
- Supabase project URL and anon key
- Google OAuth 2.0 Web Client ID (from GCP Console)
- Platform config for `google_sign_in` (Info.plist on iOS, Gradle config on Android)

### Environment
Create a `.env` file at the project root based on `.env.example`:

```
SUPABASE_URL=...
SUPABASE_PUBLISHABLE_KEY=...
SERVER_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com
```

Notes:
- `SUPABASE_PUBLISHABLE_KEY` is the new public key (replaces legacy anon key). Keep using it in clients.
- `SERVER_CLIENT_ID` must be the Web Client ID, not iOS/Android IDs.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
