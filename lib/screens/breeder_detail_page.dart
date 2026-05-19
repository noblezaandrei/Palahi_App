import 'package:flutter/material.dart';

class BreederDetailPage extends StatelessWidget {
  const BreederDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef7ef),

      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Breeder Details"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Center(
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.green[100],

                child: const Icon(Icons.pets, size: 60, color: Colors.green),
              ),
            ),

            const SizedBox(height: 25),

            const Center(
              child: Text(
                "Green Valley Farms",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            const Center(
              child: Text(
                "Legazpi City, Albay",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),

            const SizedBox(height: 25),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),

              child: Padding(
                padding: const EdgeInsets.all(18),

                child: Column(
                  children: [
                    detailRow(Icons.location_on, "Location", "Legazpi City"),

                    const Divider(),

                    detailRow(Icons.pets, "Breed", "Large White"),

                    const Divider(),

                    detailRow(Icons.star, "Rating", "4.8"),

                    const Divider(),

                    detailRow(Icons.check_circle, "Status", "Available"),

                    const Divider(),

                    detailRow(Icons.phone, "Contact", "09123456789"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                onPressed: () {},

                icon: const Icon(Icons.message),

                label: const Text(
                  "Message Breeder",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                onPressed: () {},

                icon: const Icon(Icons.map),

                label: const Text(
                  "View Location",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green),

        const SizedBox(width: 15),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        Text(value),
      ],
    );
  }
}
