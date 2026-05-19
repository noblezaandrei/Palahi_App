import 'package:flutter/material.dart';
import 'package:palahi/screens/login_page.dart' show LoginPage;

void main() {
  runApp(const PALAHIApp());
}

class PALAHIApp extends StatelessWidget {
  const PALAHIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PALAHI',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const LoginPage(),
    );
  }
}