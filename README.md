# Palahi

Palahi is a Flutter app that connects farmers with livestock breeders. It supports
breeding requests, in-app messaging between farmers and breeders, and a map view for
finding nearby breeders.

## Features

- Farmer and breeder accounts with role-based dashboards
- Breeding request creation and management
- In-app chat between farmers and breeders
- Map view for locating breeders
- Firebase-backed auth, data, and storage

## Tech Stack

- [Flutter](https://flutter.dev/) / Dart
- [Firebase](https://firebase.google.com/) (Auth, Cloud Firestore, Storage)
- [Riverpod](https://riverpod.dev/) for state management
- [go_router](https://pub.dev/packages/go_router) for navigation
- [flutter_map](https://pub.dev/packages/flutter_map) for maps

## Getting Started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Install dependencies:

   ```
   flutter pub get
   ```

3. Run the app:

   ```
   flutter run
   ```

This project uses Firebase; see `firebase.json` and `firestore.rules` for the
current project configuration.
