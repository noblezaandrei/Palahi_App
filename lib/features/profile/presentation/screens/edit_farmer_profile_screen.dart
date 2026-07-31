import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditFarmerProfileScreen extends ConsumerStatefulWidget {
  const EditFarmerProfileScreen({super.key});

  @override
  ConsumerState<EditFarmerProfileScreen> createState() =>
      _EditFarmerProfileScreenState();
}

class _EditFarmerProfileScreenState
    extends ConsumerState<EditFarmerProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _municipalityController = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).value;

      if (profile != null) {
        _nameController.text = profile['name'] ?? '';

        _phoneController.text = profile['phone'] ?? '';

        _municipalityController.text = profile['municipality'] ?? '';
      }
    });
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'municipality': _municipalityController.text.trim(),
    });

    if (mounted) {
      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully.")),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _municipalityController,
              decoration: const InputDecoration(labelText: "Municipality"),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: _loading ? null : _save,

                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
