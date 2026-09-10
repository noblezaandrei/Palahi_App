import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:palahi/core/services/storage_service.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';
import 'package:palahi/features/map/data/farmer_location_repository.dart';
import 'package:palahi/features/map/presentation/screens/location_picker_screen.dart';

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
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  latlong.LatLng? _farmLocation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = ref.read(currentUserProfileProvider).value;

      if (profile != null) {
        _nameController.text = profile['name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _municipalityController.text = profile['municipality'] ?? '';
        _existingImageUrl =
            profile['imageUrl'] as String? ??
            ref.read(authRepositoryProvider).currentUser?.photoURL;
      }

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final location = await ref
            .read(farmerLocationRepositoryProvider)
            .getLocation(user.uid);
        if (location != null && mounted) {
          setState(() {
            _farmLocation = latlong.LatLng(
              location.latitude,
              location.longitude,
            );
          });
        }
      }
    });
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<latlong.LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerScreen(initialLocation: _farmLocation),
      ),
    );
    if (picked != null) {
      setState(() => _farmLocation = picked);
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 75,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    String? imageUrl = _existingImageUrl;

    if (_pickedImage != null) {
      final storagePath =
          'farmers/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      imageUrl = await ref
          .read(storageServiceProvider)
          .uploadImage(_pickedImage!, storagePath);
    }

    if (_farmLocation != null) {
      await ref
          .read(farmerLocationRepositoryProvider)
          .setLocation(
            user.uid,
            _farmLocation!.latitude,
            _farmLocation!.longitude,
          );
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'municipality': _municipalityController.text.trim(),
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });

    if (imageUrl != null && imageUrl.isNotEmpty) {
      await ref
          .read(authRepositoryProvider)
          .currentUser
          ?.updatePhotoURL(imageUrl);
    }

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
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _pickedImageBytes != null
                    ? MemoryImage(_pickedImageBytes!)
                    : (_existingImageUrl != null &&
                          _existingImageUrl!.isNotEmpty)
                    ? NetworkImage(_existingImageUrl!) as ImageProvider
                    : null,
                child:
                    (_pickedImageBytes == null &&
                        (_existingImageUrl == null ||
                            _existingImageUrl!.isEmpty))
                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Tap the circle to upload your profile photo'),
            const SizedBox(height: 24),
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

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(
                _farmLocation == null
                    ? Icons.location_on_outlined
                    : Icons.location_on,
                color: _farmLocation == null ? null : AppColors.primary,
              ),
              label: Text(
                _farmLocation == null
                    ? 'Pin Your Farm Location'
                    : 'Farm Location Pinned — Tap to Change',
              ),
            ),
            if (_farmLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'This is where breeders will get directions to for stud services.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
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
