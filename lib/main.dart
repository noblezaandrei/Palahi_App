import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'firebase_options.dart';
import 'core/services/push_notification_service.dart';
import 'core/l10n/app_strings.dart';
import 'features/auth/repositories/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Web only: keep the login for the current browser tab, so closing it
    // signs out and the next visit starts at the login screen. Mobile keeps
    // the default of staying signed in (setPersistence is web-only anyway).
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    }
  } catch (e) {
    debugPrint(
      'Firebase not initialized fully yet, proceeding without it for UI testing.',
    );
  }
  runApp(const ProviderScope(child: PalahiApp()));
}

class PalahiApp extends ConsumerWidget {
  const PalahiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show the app in the language saved on the user's profile (English
    // when signed out).
    ref.listen(currentUserProfileProvider, (_, next) {
      if (next.hasValue) applyProfileLanguage(next.value);
    });
    return MaterialApp.router(
      title: 'PALAHI',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
