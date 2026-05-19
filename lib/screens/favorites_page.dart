import 'package:flutter/material.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef7ef),

      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Favorites"),
      ),

      body: const Center(
        child: Text(
          "No favorite breeders yet.",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
