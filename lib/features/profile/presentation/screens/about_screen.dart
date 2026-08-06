import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About PALAHI")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),

            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.pets, size: 55, color: AppColors.primary),
            ),

            const SizedBox(height: 20),

            Text(
              "PALAHI",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 30),

            const Text(
              "PALAHI (Pig Artificial and Natural Livestock Assistance Hub Interface) is a mobile application that connects farmers and breeders through a convenient digital breeding request system. The application helps streamline stud pig booking, communication, breeder discovery, and appointment management.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.school),
              title: const Text("Developed By"),
              subtitle: const Text(
                "BSIT Students\nDivine Word College of Legazpi",
              ),
            ),

            ListTile(
              leading: const Icon(Icons.code),
              title: const Text("Technology"),
              subtitle: const Text("Flutter • Firebase"),
            ),

            ListTile(
              leading: const Icon(Icons.copyright),
              title: const Text("Copyright"),
              subtitle: const Text("© 2026 PALAHI"),
            ),

            const SizedBox(height: 30),

            Text(
              "Thank you for using PALAHI!",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
