import 'package:flutter/material.dart';
import 'breeder_detail_page.dart';
import 'map_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget breederCard(
    BuildContext context, {
    required String name,
    required String location,
    required String rating,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),

      child: ListTile(
        contentPadding: const EdgeInsets.all(12),

        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.green[100],

          child: const Icon(Icons.pets, color: Colors.green, size: 30),
        ),

        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const SizedBox(height: 5),

            Text(location),

            const SizedBox(height: 5),

            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 18),

                const SizedBox(width: 4),

                Text(rating),
              ],
            ),
          ],
        ),

        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),

          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BreederDetailPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef7ef),

      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        title: const Text("PALAHI"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Hello, User 👋",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            const Text(
              "Find trusted stud pig breeders near you.",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            TextField(
              decoration: InputDecoration(
                hintText: "Search breeder or location",

                prefixIcon: const Icon(Icons.search),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

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

                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPage()),
                  );
                },

                icon: const Icon(Icons.map),

                label: const Text("Open Breeder Map"),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Top Breeders",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: ListView(
                children: [
                  breederCard(
                    context,
                    name: "Green Valley Farms",
                    location: "Legazpi City",
                    rating: "4.8",
                  ),

                  breederCard(
                    context,
                    name: "Lucky 7 Genetics",
                    location: "Daraga, Albay",
                    rating: "4.7",
                  ),

                  breederCard(
                    context,
                    name: "Triple A Hog Farm",
                    location: "Camalig, Albay",
                    rating: "4.9",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,

        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapPage()),
            );
          }
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),

          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),

          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Favorites",
          ),

          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
