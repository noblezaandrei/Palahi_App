import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// The languages the app's text can be shown in.
enum AppLanguage {
  english('en', 'English'),
  filipino('fil', 'Filipino'),
  bikol('bcl', 'Bikol');

  final String code;
  final String label;

  const AppLanguage(this.code, this.label);

  static AppLanguage fromCode(String? code) => values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage.english,
  );
}

/// The language the app is showing now. Set from the user's profile
/// (`users/{uid}.language`) by [LanguageScope], so it follows them to any
/// phone.
AppLanguage appLanguage = AppLanguage.english;

/// [english] in the user's language, with each `{name}` in it replaced by
/// [args]'s value. Text without a translation yet stays in English.
String tr(String english, [Map<String, Object> args = const {}]) {
  var text = _translations[appLanguage]?[english] ?? english;
  args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  return text;
}

/// Saves [language] as [uid]'s choice and shows the app in it right away.
Future<void> setAppLanguage(String uid, AppLanguage language) async {
  _apply(language);
  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'language': language.code,
  });
}

/// Applies the language from a user profile (null when signed out).
void applyProfileLanguage(Map<String, dynamic>? profile) {
  _apply(AppLanguage.fromCode(profile?['language'] as String?));
}

void _apply(AppLanguage language) {
  if (language == appLanguage) return;
  appLanguage = language;
  // Every widget reads its text through tr() as it builds, so rebuilding
  // the whole tree switches everything over, including const widgets.
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;
  void rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(rebuild);
  }

  root.visitChildren(rebuild);
}

// Translations of the farmer's main screens. The Bikol is Central Bikol and
// should be checked by a native speaker from Albay before release. Keys are
// the English text; `{name}` placeholders must be kept.
const _translations = <AppLanguage, Map<String, String>>{
  AppLanguage.filipino: {
    // Navigation
    'Map': 'Mapa',
    'Favorites': 'Paborito',
    'My Pigs': 'Aking Baboy',
    'Requests': 'Mga Request',
    'Calendar': 'Kalendaryo',
    // Home
    'Hello, {name}': 'Kumusta, {name}',
    'Find trusted stud pig breeders near you':
        'Maghanap ng mapagkakatiwalaang breeder ng barako malapit sa iyo',
    'NEXT BOOKING': 'SUSUNOD NA BOOKING',
    'No upcoming bookings. Browse the stud pigs below to book one.':
        'Wala pang paparating na booking. Tingnan ang mga barako sa ibaba para mag-book.',
    'Search breeders, breeds, or location':
        'Maghanap ng breeder, lahi, o lugar',
    'Trusted Breeders': 'Mapagkakatiwalaang Breeder',
    'Available Stud Pigs': 'Mga Available na Barako',
    'My Bookings': 'Aking mga Booking',
    'Message Breeder': 'I-message ang Breeder',
    'Confirm Booking': 'Kumpirmahin',
    'Reschedule': 'Ilipat ang Oras',
    'No active bookings': 'Walang aktibong booking',
    'Pick an available stud pig above to book your first breeding.':
        'Pumili ng available na barako sa itaas para sa unang booking mo.',
    // Booking statuses and progress
    'Waiting': 'Naghihintay',
    'Accepted': 'Tinanggap',
    'Breeding': 'Pagpapalahi',
    'Completed': 'Tapos na',
    'Declined': 'Tinanggihan',
    'Cancelled': 'Kinansela',
    'Requested': 'Na-request',
    // Trip banner
    'ON THE WAY TO YOUR FARM': 'PAPUNTA NA SA IYONG BUKID',
    'Tap to track the trip': 'I-tap para subaybayan ang biyahe',
    '{km} km away · arrives in {eta}':
        '{km} km ang layo · darating sa loob ng {eta}',
    'Track': 'Subaybayan',
    // Booking sheet
    'Book {pig}': 'I-book si {pig}',
    'Reschedule {pig}': 'Ilipat ang booking ni {pig}',
    'Breeding type': 'Uri ng pagpapalahi',
    'Choose a date': 'Pumili ng petsa',
    'Choose a time': 'Pumili ng oras',
    'Open': 'Bakante',
    'Booked': 'Nakuha na',
    'Passed': 'Lumipas na',
    'Notes for the breeder': 'Mensahe para sa breeder',
    'Optional': 'Opsyonal',
    'Pick a date first to see which times are still open.':
        'Pumili muna ng petsa para makita ang mga bakanteng oras.',
    'Every time on this day is already booked. Please pick another date.':
        'Puno na ang lahat ng oras sa araw na ito. Pumili ng ibang petsa.',
    'No time chosen yet': 'Wala pang napiling oras',
    '{fee} stud fee · pay cash': '{fee} bayad sa barako · cash',
    'Book': 'I-book',
    'Vaccinations': 'Bakuna',
    'Health check': 'Huling check-up',
    'Pedigree': 'Lahi',
    // Breeding tracker
    'Breeding Tracker': 'Tracker ng Pagpapalahi',
    'See all': 'Tingnan lahat',
    'Your sows': 'Iyong mga inahin',
    'Follow each breeding through to farrowing':
        'Subaybayan ang bawat pagpapalahi hanggang sa panganganak',
    'Pregnant': 'Buntis',
    'Farrowed': 'Nanganak na',
    'Check for heat': 'Tingnan kung nag-iinit',
    'Farrowing soon': 'Malapit nang manganak',
    "Didn't conceive": 'Hindi nabuntis',
    'Came back in heat': 'Nag-init ulit',
    'No heat — pregnant': 'Hindi nag-init — buntis',
    'She farrowed': 'Nanganak na siya',
    'Book again': 'Mag-book ulit',
    'Breeding with {pig}': 'Pinalahian kay {pig}',
    'Heat check': 'Heat check',
    'Farrowing {date}': 'Panganganak {date}',
    "Watch for heat {range} ({when}). If she doesn't come back into heat, she has most likely conceived. Farrowing would be about {due}.":
        'Bantayan kung mag-iinit siya sa {range} ({when}). Kung hindi siya mag-init ulit, malamang ay buntis siya. Manganganak siya bandang {due}.',
    'Check her for heat every day until {date}: restlessness, a swollen red vulva, or standing still when you press on her back.':
        'Tingnan araw-araw hanggang {date} kung nag-iinit siya: hindi mapakali, namamaga at mapulang ari, o hindi gumagalaw kapag diniinan ang likod.',
    'The heat check window has passed. Did she come back into heat?':
        'Tapos na ang panahon ng heat check. Nag-init ba ulit siya?',
    'Farrowing due {due} ({when}). Day {day} of about {total}.':
        'Manganganak bandang {due} ({when}). Ika-{day} na araw sa mga {total}.',
    'Farrowing due {due} ({when}). Get a clean, dry, warm farrowing pen ready.':
        'Manganganak bandang {due} ({when}). Ihanda ang malinis, tuyo, at mainit na kulungan.',
    "She didn't conceive this time. You can book another breeding.":
        'Hindi siya nabuntis ngayon. Puwede kang mag-book ulit.',
    'today': 'ngayon',
    'tomorrow': 'bukas',
    'in {n} days': 'sa loob ng {n} araw',
    // Settings
    'Language': 'Wika',
  },
  AppLanguage.bikol: {
    // Navigation
    'Map': 'Mapa',
    'Favorites': 'Paborito',
    'My Pigs': 'Mga Baboy Ko',
    'Requests': 'Mga Request',
    'Calendar': 'Kalendaryo',
    // Home
    'Hello, {name}': 'Kumusta, {name}',
    'Find trusted stud pig breeders near you':
        'Maghanap nin mapagkakatiwalaan na breeder nin barako harani saimo',
    'NEXT BOOKING': 'SUNOD NA BOOKING',
    'No upcoming bookings. Browse the stud pigs below to book one.':
        'Mayo pang maabot na booking. Hilingon an mga barako sa ibaba tanganing mag-book.',
    'Search breeders, breeds, or location':
        'Maghanap nin breeder, lahi, o lugar',
    'Trusted Breeders': 'Mapagkakatiwalaan na Breeder',
    'Available Stud Pigs': 'Mga Available na Barako',
    'My Bookings': 'Mga Booking Ko',
    'Message Breeder': 'I-message an Breeder',
    'Confirm Booking': 'Kumpirmaron',
    'Reschedule': 'Ibalyo an Oras',
    'No active bookings': 'Mayong aktibong booking',
    'Pick an available stud pig above to book your first breeding.':
        'Magpili nin available na barako sa itaas para sa enot mong booking.',
    // Booking statuses and progress
    'Waiting': 'Naghahalat',
    'Accepted': 'Inako',
    'Breeding': 'Pagpalahi',
    'Completed': 'Tapos na',
    'Declined': 'Dai inako',
    'Cancelled': 'Kinansela',
    'Requested': 'Na-request',
    // Trip banner
    'ON THE WAY TO YOUR FARM': 'PADUMAN NA SA SAIMONG UMA',
    'Tap to track the trip': 'I-tap tanganing subaybayan an biyahe',
    '{km} km away · arrives in {eta}':
        '{km} km an rayo · maabot sa laog nin {eta}',
    'Track': 'Subaybayan',
    // Booking sheet
    'Book {pig}': 'I-book si {pig}',
    'Reschedule {pig}': 'Ibalyo an booking ni {pig}',
    'Breeding type': 'Klase kan pagpalahi',
    'Choose a date': 'Magpili nin aldaw',
    'Choose a time': 'Magpili nin oras',
    'Open': 'Bakante',
    'Booked': 'Kinua na',
    'Passed': 'Nakalihis na',
    'Notes for the breeder': 'Mensahe para sa breeder',
    'Optional': 'Opsyonal',
    'Pick a date first to see which times are still open.':
        'Magpili muna nin aldaw tanganing mahiling an mga bakanteng oras.',
    'Every time on this day is already booked. Please pick another date.':
        'Puno na an gabos na oras sa aldaw na ini. Magpili nin ibang aldaw.',
    'No time chosen yet': 'Mayo pang napiling oras',
    '{fee} stud fee · pay cash': '{fee} bayad sa barako · cash',
    'Book': 'I-book',
    'Vaccinations': 'Bakuna',
    'Health check': 'Huring check-up',
    'Pedigree': 'Lahi',
    // Breeding tracker
    'Breeding Tracker': 'Tracker kan Pagpalahi',
    'See all': 'Hilingon gabos',
    'Your sows': 'Mga inahin mo',
    'Follow each breeding through to farrowing':
        'Subaybayan an kada pagpalahi sagkod sa pag-anak',
    'Pregnant': 'Burod',
    'Farrowed': 'Nag-anak na',
    'Check for heat': 'Hilingon kun nag-iinit',
    'Farrowing soon': 'Harani nang mag-anak',
    "Didn't conceive": 'Dai nagburod',
    'Came back in heat': 'Nag-init giraray',
    'No heat — pregnant': 'Dai nag-init — burod',
    'She farrowed': 'Nag-anak na siya',
    'Book again': 'Mag-book giraray',
    'Breeding with {pig}': 'Pinalahian ki {pig}',
    'Heat check': 'Heat check',
    'Farrowing {date}': 'Pag-anak {date}',
    "Watch for heat {range} ({when}). If she doesn't come back into heat, she has most likely conceived. Farrowing would be about {due}.":
        'Bantayan kun mag-iinit siya sa {range} ({when}). Kun dai siya mag-init giraray, posibleng burod siya. Mag-aanak siya mga {due}.',
    'Check her for heat every day until {date}: restlessness, a swollen red vulva, or standing still when you press on her back.':
        'Hilingon aroaldaw sagkod {date} kun nag-iinit siya: dai mapakagdanan, namamaga asin mapulang kinatawo, o dai naghihiro pag diniin an likod.',
    'The heat check window has passed. Did she come back into heat?':
        'Tapos na an panahon kan heat check. Nag-init daw giraray siya?',
    'Farrowing due {due} ({when}). Day {day} of about {total}.':
        'Mag-aanak mga {due} ({when}). Ika-{day} na aldaw sa mga {total}.',
    'Farrowing due {due} ({when}). Get a clean, dry, warm farrowing pen ready.':
        'Mag-aanak mga {due} ({when}). Andamon an malinig, marang, asin mainit na kulungan.',
    "She didn't conceive this time. You can book another breeding.":
        'Dai siya nagburod ngonyan. Pwede kang mag-book giraray.',
    'today': 'ngonyan',
    'tomorrow': 'sa aga',
    'in {n} days': 'sa laog nin {n} aldaw',
    // Settings
    'Language': 'Tataramon',
  },
};
