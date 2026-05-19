import 'package:flutter/material.dart';
import 'service_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget card(String title, IconData icon) {
    return Card(
      elevation: 5,
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text("PALAHI Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            card("Pig Health Monitoring", Icons.health_and_safety),
            card("Breeding Schedule", Icons.calendar_today),
            card("Feed Management", Icons.restaurant),
            card("Reports", Icons.bar_chart),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServicePage(),
                  ),
                );
              },
              child: const Text("Go to Service Center"),
            ),
          ],
        ),
      ),
    );
  }
}