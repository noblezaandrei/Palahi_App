import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/models/stud_pig_model.dart';
import '../../data/stud_pig_repository.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/data/auth_repository.dart';

class ManageStudPigScreen extends ConsumerStatefulWidget {
  final StudPigModel? existingPig;

  const ManageStudPigScreen({super.key, this.existingPig});

  @override
  ConsumerState<ManageStudPigScreen> createState() => _ManageStudPigScreenState();
}

class _ManageStudPigScreenState extends ConsumerState<ManageStudPigScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _pickedImage;
  String? _existingImageUrl;
  bool _isAvailable = true;
  String _serviceType = 'Natural Breeding';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPig != null) {
      _nameController.text = widget.existingPig!.name;
      _breedController.text = widget.existingPig!.breed;
      _ageController.text = widget.existingPig!.ageMonths.toString();
      _weightController.text = widget.existingPig!.weight.toString();
      _priceController.text = widget.existingPig!.price.toString();
      _descriptionController.text = widget.existingPig!.description;
      _existingImageUrl = widget.existingPig!.imageUrl;
      _isAvailable = widget.existingPig!.isAvailable;
      _serviceType = widget.existingPig!.serviceType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or upload a pig image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      String imageUrl = _existingImageUrl ?? '';
      
      if (_pickedImage != null) {
        // Delete old image from Storage if it exists to optimize space
        if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty && _existingImageUrl!.contains('firebasestorage')) {
          try {
            await FirebaseStorage.instance.refFromURL(_existingImageUrl!).delete();
          } catch (e) {
            debugPrint('Error deleting old image: $e');
          }
        }
        // Upload to Firebase Storage
        final storagePath = 'pigs/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await ref.read(storageServiceProvider).uploadImage(_pickedImage!, storagePath);
      }

      final double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
      final double price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final int age = int.tryParse(_ageController.text.trim()) ?? 0;

      final newPig = StudPigModel(
        id: widget.existingPig?.id ?? '', // empty id will let firestore generate one
        breederId: user.uid,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        ageMonths: age,
        weight: weight,
        price: price,
        imageUrl: imageUrl,
        isAvailable: _isAvailable,
        description: _descriptionController.text.trim(),
        serviceType: _serviceType,
      );

      await ref.read(studPigRepositoryProvider).saveStudPig(newPig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stud pig saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPig == null ? 'Add Stud Pig' : 'Edit Stud Pig'),
        actions: [
          if (widget.existingPig != null)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Listing'),
                    content: const Text('Are you sure you want to delete this stud pig?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _isLoading = true);
                  try {
                    await ref.read(studPigRepositoryProvider).deleteStudPig(widget.existingPig!.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image Picker Container
                GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.network(_pickedImage!.path, fit: BoxFit.cover, width: double.infinity)
                                : Image.file(File(_pickedImage!.path), fit: BoxFit.cover, width: double.infinity),
                          )
                        : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(_existingImageUrl!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to select a pig photo',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Required *',
                                    style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                                  )
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Pig Name *',
                    hintText: 'Enter name (e.g. Duroc Champion)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _breedController,
                  decoration: const InputDecoration(
                    labelText: 'Breed *',
                    hintText: 'e.g. Duroc, Landrace, Large White',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Please enter the breed' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age (Months) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (int.tryParse(val) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price / Stud Fee (₱) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (double.tryParse(val) == null) return 'Invalid price';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _serviceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Offered *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Natural Breeding', child: Text('Natural Breeding')),
                    DropdownMenuItem(value: 'Artificial Insemination', child: Text('Artificial Insemination')),
                    DropdownMenuItem(value: 'Both', child: Text('Both (Natural & AI)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _serviceType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter details about health, genetics, vaccine status, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Available for Breeding'),
                  value: _isAvailable,
                  onChanged: (val) {
                    setState(() => _isAvailable = val);
                  },
                  activeTrackColor: AppColors.primaryLight,
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: const Text('Save Listing'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(50),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
