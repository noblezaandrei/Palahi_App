import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palahi/screens/login_page.dart' show LoginPage;
import 'login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const PalahiApp()); // Make sure this matches
  });
}

class PalahiApp extends StatelessWidget { // This class should exist
  const PalahiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PALAHI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),
    );
  }
}