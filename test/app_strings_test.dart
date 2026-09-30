import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/l10n/app_strings.dart';
import 'package:palahi/features/home/views/farmer_dashboard_screen.dart';

void main() {
  tearDown(() => appLanguage = AppLanguage.english);

  test('text follows the chosen language, with placeholders filled in', () {
    appLanguage = AppLanguage.filipino;
    expect(tr('My Bookings'), 'Aking mga Booking');
    expect(tr('Hello, {name}', {'name': 'Juan'}), 'Kumusta, Juan');
    expect(bookingStatusLabel('pending'), 'Naghihintay');

    appLanguage = AppLanguage.bikol;
    expect(tr('Pregnant'), 'Burod');
    expect(tr('in {n} days', {'n': 5}), 'sa laog nin 5 aldaw');
  });

  test('English, and anything not translated yet, shows as written', () {
    expect(tr('My Bookings'), 'My Bookings');
    appLanguage = AppLanguage.filipino;
    expect(tr('Some brand new text'), 'Some brand new text');
  });

  test('every translation keeps the placeholders of its English text', () {
    final placeholder = RegExp(r'\{\w+\}');
    for (final language in [AppLanguage.filipino, AppLanguage.bikol]) {
      appLanguage = language;
      for (final english in [
        'Hello, {name}',
        '{km} km away · arrives in {eta}',
        'Book {pig}',
        'Farrowing due {due} ({when}). Day {day} of about {total}.',
      ]) {
        final wanted = placeholder.allMatches(english).map((m) => m[0]).toSet();
        final got = placeholder
            .allMatches(tr(english))
            .map((m) => m[0])
            .toSet();
        expect(got, wanted, reason: '$language: $english');
      }
    }
  });

  test('saved language codes load back, unknown ones fall back to English', () {
    expect(AppLanguage.fromCode('fil'), AppLanguage.filipino);
    expect(AppLanguage.fromCode('bcl'), AppLanguage.bikol);
    expect(AppLanguage.fromCode(null), AppLanguage.english);
    expect(AppLanguage.fromCode('xx'), AppLanguage.english);
  });
}
