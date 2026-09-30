// Shared setup for the screen smoke tests: every provider a screen reads is
// fed sample data, and every repository is a fake, so screens can be opened
// and clicked through in debug mode (where Flutter's framework checks run,
// like on a phone running `flutter run`) without touching Firebase.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/core/l10n/app_strings.dart';
import 'package:palahi/core/utils/date_utils.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/breeder/models/review_model.dart';
import 'package:palahi/features/breeder/models/stud_pig_model.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/repositories/favorite_repository.dart';
import 'package:palahi/features/breeder/repositories/review_repository.dart';
import 'package:palahi/features/breeder/repositories/stud_pig_repository.dart';
import 'package:palahi/features/breeder/repositories/trip_repository.dart';
import 'package:palahi/features/communication/models/notification_model.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/features/map/repositories/farmer_location_repository.dart';
import 'package:palahi/features/map/repositories/location_service.dart';
import 'package:palahi/features/map/repositories/route_service.dart';
import 'package:palahi/features/tracker/models/breeding_record.dart';
import 'package:palahi/features/tracker/repositories/breeding_record_repository.dart';

/// Phone text size for the smoke tests (1.0 = default). Set with
/// `--dart-define=TEXT_SCALE=1.3` to check the "Large" font setting.
final testTextScale = double.parse(
  const String.fromEnvironment('TEXT_SCALE', defaultValue: '1.0'),
);

/// App language for the smoke tests: `--dart-define=LANG=fil` or `bcl`.
const testLanguage = String.fromEnvironment('LANG', defaultValue: 'en');

const farmerUid = 'F';
const breederUid = 'B';

class FakeUser implements User {
  FakeUser(this.uid);
  @override
  final String uid;
  @override
  String? get photoURL => null;
  @override
  String? get email => '$uid@example.com';
  @override
  bool get emailVerified => true;
  @override
  String? get displayName =>
      uid == farmerUid ? 'Juan Dela Cruz' : 'Green Valley';
  @override
  List<UserInfo> get providerData => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements AuthRepository {
  FakeAuth(this.uid);
  final String uid;
  @override
  User? get currentUser => FakeUser(uid);
  @override
  Stream<User?> get authStateChanges => Stream.value(FakeUser(uid));
  @override
  Future<void> signOut() async {}
  @override
  bool get isGoogleAccount => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the calls screens make, answering them with harmless values.
class Calls {
  final list = <String>[];
  void add(String call) => list.add(call);
}

class FakeBookings implements BreedingRequestRepository {
  FakeBookings(this.calls);
  final Calls calls;
  @override
  Future<Set<String>> getBookedDatesForPig(
    String id, {
    String? exceptBookingId,
  }) async => {dateKey(DateTime.now().add(const Duration(days: 3)))};
  @override
  Future<void> updateRequestStatus(String id, String status) async =>
      calls.add('status $id $status');
  @override
  Future<int> countActiveBookingsForPig(String id) async => 1;
  @override
  Future<BookingConflict?> checkBookingConflict({
    required String studPigId,
    required String breederId,
    required String date,
    required String time,
    String? exceptBookingId,
  }) async => null;
  @override
  Future<void> sendRequest(BreedingRequestModel r) async => calls.add('book');
  @override
  Future<void> rescheduleRequest(
    BreedingRequestModel b, {
    required String date,
    required String time,
  }) async => calls.add('reschedule $date $time');
  @override
  Future<String?> getRequestStatus(String id) async => 'pending';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChat implements ChatRepository {
  @override
  Future<void> syncOwnPhoto(String a, String b, List<ChatRoomModel> c) async {}
  @override
  Future<void> markSeen(String a, String b) async {}
  @override
  Future<String> getOrCreateChatRoom({
    required String farmerId,
    required String farmerName,
    required String breederId,
    required String breederName,
    String farmerImageUrl = '',
    String breederImageUrl = '',
  }) async => '${breederUid}_$farmerUid';
  @override
  Future<void> sendMessage(String a, String b, String c, String d) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotifications implements NotificationRepository {
  @override
  Future<void> markChatRoomNotificationsAsRead(String a, String b) async {}
  @override
  Future<void> markChatNotificationsAsRead(String a) async {}
  @override
  Future<void> markAsRead(String a) async {}
  @override
  Future<void> clearAll(String a) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecords implements BreedingRecordRepository {
  FakeRecords(this.calls);
  final Calls calls;
  @override
  Future<void> saveOutcome(
    BreedingRequestModel b,
    BreedingOutcome o, {
    int? litterSize,
    String? farrowedOn,
  }) async => calls.add('outcome ${b.id} ${o.key}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBreederRepo implements BreederRepository {
  FakeBreederRepo(this.calls);
  final Calls calls;
  @override
  Stream<List<BreederModel>> getBreeders() => Stream.value([breeder]);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add('breederRepo ${invocation.memberName}');
    return Future<void>.value();
  }
}

class FakeGeneric
    implements
        StudPigRepository,
        FavoriteRepository,
        ReviewRepository,
        FarmerLocationRepository,
        TripRepository {
  FakeGeneric(this.calls);
  final Calls calls;
  @override
  Future<ReviewModel?> getReviewForBooking(String bookingId) async => null;
  @override
  Future<FarmerLocation?> getLocation(String farmerId) async =>
      const FarmerLocation(13.175, 123.667);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add('repo ${invocation.memberName}');
    return Future<void>.value();
  }
}

final today = DateTime.now();
String inDays(int d) => dateKey(today.add(Duration(days: d)));

final breeder = BreederModel(
  id: breederUid,
  userId: breederUid,
  farmName: 'Green Valley Farm',
  location: 'Palanog, Camalig',
  latitude: 13.185,
  longitude: 123.655,
  rating: 4.8,
  reviewCount: 1,
  imageUrl: '',
  about: 'Family farm',
  services: const ['Natural Breeding'],
  availableDates: [for (var i = 1; i < 20; i++) inDays(i)],
);

final pig = StudPigModel(
  id: 'p1',
  breederId: breederUid,
  name: 'Duroc King',
  breed: 'Duroc',
  ageMonths: 18,
  weight: 205,
  price: 1500,
  imageUrl: '',
  isAvailable: true,
  description: 'Calm, proven sire',
  serviceType: 'Both',
  vaccinations: 'Hog cholera',
  lastHealthCheck: '2026-09-15',
  pedigree: 'PIC Duroc',
);

BreedingRequestModel booking(
  String id,
  String status,
  int inDaysFromNow, [
  String time = '09:00 AM',
]) => BreedingRequestModel(
  id: id,
  farmerId: farmerUid,
  farmerName: 'Juan Dela Cruz',
  farmerImageUrl: '',
  breederId: breederUid,
  breederName: 'Green Valley Farm',
  breederImageUrl: '',
  studPigId: 'p1',
  studPigName: 'Duroc King',
  studPigImageUrl: '',
  status: status,
  breedingType: 'Manual Breeding',
  bookingDate: inDays(inDaysFromNow),
  bookingTime: time,
  notes: 'Two sows',
  createdAt: today,
);

final bookings = [
  booking('pending', 'pending', 4),
  booking('accepted', 'accepted', 2),
  booking('done', 'done_breeding', -1),
  booking('heat', 'completed', -20),
  booking('preg', 'completed', -60),
  booking('cancelled', 'cancelled', 5),
];

final records = {
  'preg': const BreedingRecord(
    bookingId: 'preg',
    farmerId: farmerUid,
    breederId: breederUid,
    studPigId: 'p1',
    outcome: BreedingOutcome.pregnant,
  ),
};

final review = ReviewModel(
  id: 'heat',
  bookingId: 'heat',
  breederId: breederUid,
  farmerId: farmerUid,
  farmerName: 'Juan Dela Cruz',
  rating: 5,
  review: 'Great boar',
  studPigId: 'p1',
  studPigName: 'Duroc King',
  createdAt: today,
);

ChatRoomModel get room => ChatRoomModel(
  id: '${breederUid}_$farmerUid',
  farmerId: farmerUid,
  farmerName: 'Juan Dela Cruz',
  breederId: breederUid,
  breederName: 'Green Valley Farm',
  lastMessage: 'See you tomorrow',
  lastMessageTime: today,
  participants: const [breederUid, farmerUid],
  seenBy: {breederUid: today},
);

List<ChatMessageModel> get messages => [
  ChatMessageModel(
    id: 'm1',
    senderId: farmerUid,
    senderName: 'Juan',
    text: 'Is Duroc King free?',
    timestamp: today.subtract(const Duration(days: 1)),
  ),
  ChatMessageModel(
    id: 'm2',
    senderId: breederUid,
    senderName: 'Green Valley',
    text: 'Yes, tomorrow at 9.',
    timestamp: today,
  ),
];

List<NotificationModel> get notifications => [
  NotificationModel(
    id: 'n1',
    userId: farmerUid,
    title: 'Booking Accepted',
    body: 'Green Valley Farm accepted your booking.',
    type: 'booking',
    referenceId: 'accepted',
    isRead: false,
    createdAt: today,
  ),
  NotificationModel(
    id: 'n2',
    userId: farmerUid,
    title: 'New message',
    body: 'Yes, tomorrow at 9.',
    type: 'chat',
    referenceId: '${breederUid}_$farmerUid',
    isRead: true,
    createdAt: today,
  ),
];

List overridesFor(String role, Calls calls) {
  final uid = role == 'farmer' ? farmerUid : breederUid;
  return [
    authRepositoryProvider.overrideWithValue(FakeAuth(uid)),
    authStateProvider.overrideWith((ref) => Stream.value(FakeUser(uid))),
    currentUserProfileProvider.overrideWith(
      (ref) => Stream.value({
        'id': uid,
        'role': role,
        'name': role == 'farmer' ? 'Juan Dela Cruz' : 'Green Valley',
        'email': '$uid@example.com',
        'username': role,
      }),
    ),
    breedersStreamProvider.overrideWith((ref) => Stream.value([breeder])),
    allAvailablePigsProvider.overrideWith((ref) => Stream.value([pig])),
    breederStudPigsProvider.overrideWith((ref, id) => Stream.value([pig])),
    farmerRequestsProvider.overrideWith((ref, id) => Stream.value(bookings)),
    breederRequestsProvider.overrideWith((ref, id) => Stream.value(bookings)),
    farmerHistoryProvider.overrideWith(
      (ref, id) => Stream.value([bookings.last, bookings[3]]),
    ),
    breederHistoryProvider.overrideWith(
      (ref, id) => Stream.value([bookings.last, bookings[3]]),
    ),
    completedRequestsForBreederProvider.overrideWith(
      (ref, id) => Stream.value([bookings[3]]),
    ),
    farmerCompletedRequestsProvider.overrideWith(
      (ref, id) => Stream.value([bookings[3]]),
    ),
    farmerPendingRequestsProvider.overrideWith(
      (ref, id) => Stream.value([bookings.first]),
    ),
    breederPigBookedDatesProvider.overrideWith(
      (ref, id) => Stream.value({
        'p1': {inDays(2)},
      }),
    ),
    breederTakenTimesProvider.overrideWith(
      (ref, day) => Stream.value({'09:00 AM'}),
    ),
    farmerBreedingRecordsProvider.overrideWith(
      (ref, id) => Stream.value(records),
    ),
    breederBreedingRecordsProvider.overrideWith(
      (ref, id) => Stream.value(records),
    ),
    userFavoritesProvider.overrideWith((ref) => Stream.value([breederUid])),
    breederReviewsProvider.overrideWith((ref, id) => Stream.value([review])),
    farmerReviewsProvider.overrideWith((ref, id) => Stream.value([review])),
    tripLocationStreamProvider.overrideWith((ref, id) => Stream.value(null)),
    tripRouteProvider.overrideWith(
      (ref, key) async => const RoadRoute(
        points: [LatLng(13.185, 123.655), LatLng(13.175, 123.667)],
        distanceKm: 3.4,
        duration: Duration(minutes: 9),
      ),
    ),
    farmerLocationProvider.overrideWith(
      (ref, id) => Stream.value(const FarmerLocation(13.175, 123.667)),
    ),
    currentLocationProvider.overrideWith((ref) => Completer<Never>().future),
    userNotificationsProvider.overrideWith(
      (ref, id) => Stream.value(notifications),
    ),
    unreadNotificationCountProvider.overrideWith((ref, id) => Stream.value(1)),
    unreadChatNotificationCountProvider.overrideWith(
      (ref, id) => Stream.value(1),
    ),
    chatRoomsStreamProvider.overrideWith((ref, id) => Stream.value([room])),
    chatRoomStreamProvider.overrideWith((ref, id) => Stream.value(room)),
    chatMessagesStreamProvider.overrideWith(
      (ref, id) => Stream.value(messages),
    ),
    breedingRequestRepositoryProvider.overrideWithValue(FakeBookings(calls)),
    chatRepositoryProvider.overrideWithValue(FakeChat()),
    notificationRepositoryProvider.overrideWithValue(FakeNotifications()),
    breedingRecordRepositoryProvider.overrideWithValue(FakeRecords(calls)),
    breederRepositoryProvider.overrideWithValue(FakeBreederRepo(calls)),
    studPigRepositoryProvider.overrideWithValue(FakeGeneric(calls)),
    favoriteRepositoryProvider.overrideWithValue(FakeGeneric(calls)),
    reviewRepositoryProvider.overrideWithValue(FakeGeneric(calls)),
    farmerLocationRepositoryProvider.overrideWithValue(FakeGeneric(calls)),
    tripRepositoryProvider.overrideWithValue(FakeGeneric(calls)),
  ];
}

/// Routes screens may push to; each shows a placeholder naming the route.
GoRouter routerFor(Widget screen) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    for (final path in [
      '/home',
      '/login',
      '/messages',
      '/notifications',
      '/breeding-requests',
      '/breeding-tracker',
      '/manage-pig',
      '/breeder/:id',
      '/reviews/:id',
    ])
      GoRoute(
        path: path,
        builder: (_, s) => Scaffold(body: Text('route ${s.uri}')),
      ),
  ],
);

/// Opens [screen] as [role] and lets it load.
Future<Calls> openScreen(
  WidgetTester tester,
  Widget screen, {
  required String role,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Print each framework error in full (which widget, where) before the
  // test framework records it.
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
    report?.call(details);
  };
  addTearDown(() => FlutterError.onError = report);
  appLanguage = AppLanguage.fromCode(testLanguage);
  final calls = Calls();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overridesFor(role, calls)],
      child: MaterialApp.router(
        routerConfig: routerFor(screen),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(testTextScale)),
          child: child!,
        ),
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            },
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  return calls;
}

/// Lets animations and streams run for a while. Not pumpAndSettle: the
/// pig loader animates forever while something is loading.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps the first widget showing [text], scrolling it into view first.
Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    // Further down a list that only builds what's on screen.
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await settle(tester);
}

/// Closes the top dialog, sheet or page with the system back button.
Future<void> back(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  navigator.maybePop();
  await settle(tester);
}

/// Loads Verdana as the test font. Flutter's default test font draws every
/// letter as a wide square, which makes text look far longer than on a
/// phone; Verdana is a little wider than the app's Poppins, so text that
/// fits here fits on phones.
Future<void> loadRealFont() async {
  const places = [
    'C:/Windows/Fonts/verdana.ttf', // Windows
    'C:/Windows/Fonts/verdanab.ttf',
    '/System/Library/Fonts/Supplemental/Verdana.ttf', // macOS
    '/System/Library/Fonts/Supplemental/Verdana Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', // Linux
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ];
  final files = places.map(File.new).where((f) => f.existsSync()).toList();
  if (files.isEmpty) {
    fail(
      'No Verdana/DejaVu font found for the smoke tests; add its path to '
      'loadRealFont() in test/smoke/harness.dart.',
    );
  }
  final loader = FontLoader('Roboto');
  for (final file in files) {
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
