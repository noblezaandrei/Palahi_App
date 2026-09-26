import 'package:flutter/material.dart';

/// What PALAHI collects, who can see it, and how to delete it. Keep this in
/// step with the app: it describes firestore.rules and the delete-account
/// flow as they actually work.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, List<String>)>[
    (
      'What we collect',
      [
        'Account details: your name, username, email address, and whether '
            'you are a farmer or a breeder. If you sign in with Google, your '
            'Google name, email and profile photo.',
        'Profile details you add: phone number, municipality, profile or '
            'farm photo, and for breeders, farm name, address, description, '
            'services, available dates and stud pig listings.',
        'Location: the farm location you pin on the map. For breeders who '
            'start a trip, the phone\'s live location while the trip is '
            'running (only while the app is open).',
        'Activity: booking requests, chat messages, reviews, favorites and '
            'notifications.',
      ],
    ),
    (
      'Who can see it',
      [
        'Breeder farm profiles, stud pig listings and reviews are visible to '
            'everyone signed in to PALAHI.',
        'A farmer\'s pinned farm location is private. Only that farmer can '
            'see it, and breeders can look it up for directions to a booking. '
            'Other farmers cannot see it.',
        'Bookings are visible only to the farmer and breeder involved. Chats '
            'are visible only to the two people in them.',
        'A breeder\'s live trip location is visible only to the farmer on '
            'that booking.',
        'Your email, phone number and the rest of your profile are not shown '
            'to other users.',
      ],
    ),
    (
      'Where it is stored',
      [
        'Your data is stored with Google Firebase (authentication and '
            'database). Photos you upload are stored with Cloudinary. Maps are '
            'provided by Google Maps and road routes by the OSRM routing '
            'service, which receive map coordinates but not your identity.',
      ],
    ),
    (
      'Why we use it',
      [
        'Only to run PALAHI: to let farmers find breeders, request and manage '
            'bookings, chat, get directions and leave reviews. We do not sell '
            'your data or use it for advertising.',
      ],
    ),
    (
      'Deleting your account',
      [
        'You can delete your account at any time in Settings → Delete '
            'Account. This deletes your profile, photo reference, username, '
            'login, farm location, breeder listings, favorites, notifications '
            'and the messages you sent.',
        'Reviews you wrote stay (shown as "Deleted user") so breeder ratings '
            'remain accurate. Booking records stay with the other farmer or '
            'breeder as their transaction history.',
        'Photos already uploaded to Cloudinary are not removed automatically.',
      ],
    ),
    (
      'Your rights',
      [
        'Under the Philippine Data Privacy Act of 2012 you may ask to access, '
            'correct or delete your personal data. You can edit your profile '
            'in the app, delete your account in Settings, or contact the '
            'PALAHI team for anything else.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final (title, paragraphs) in _sections) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final paragraph in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(paragraph),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
