import 'package:flutter/material.dart';

class ServicePage extends StatelessWidget {
  const ServicePage({super.key});

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
        title: const Text("Service Center"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.support_agent),
            title: Text("Customer Support"),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text("System Settings"),
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text("About PALAHI"),
          ),
        ],
      ),
    );
  }
}