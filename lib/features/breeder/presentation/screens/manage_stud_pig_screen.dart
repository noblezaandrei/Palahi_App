import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/stud_pig_model.dart';
import '../../data/stud_pig_repository.dart';
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
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;
  bool _isAvailable = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingPig?.name ?? '');
    _breedController = TextEditingController(text: widget.existingPig?.breed ?? '');
    _ageController = TextEditingController(text: widget.existingPig?.ageMonths.toString() ?? '');
    _priceController = TextEditingController(text: widget.existingPig?.price.toString() ?? '');
    _imageUrlController = TextEditingController(text: widget.existingPig?.imageUrl ?? '');
    _isAvailable = widget.existingPig?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      final newPig = StudPigModel(
        id: widget.existingPig?.id ?? '', // empty id will let firestore generate one
        breederId: user.uid,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        ageMonths: int.parse(_ageController.text.trim()),
        price: double.parse(_priceController.text.trim()),
        imageUrl: _imageUrlController.text.trim(),
        isAvailable: _isAvailable,
      );

      await ref.read(studPigRepositoryProvider).saveStudPig(newPig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stud pig saved successfully')),
        );
        context.pop();
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
                  await ref.read(studPigRepositoryProvider).deleteStudPig(widget.existingPig!.id);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breedController,
              decoration: const InputDecoration(labelText: 'Breed (e.g., Duroc, Large White)'),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age (Months)'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (Stud Fee)'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(labelText: 'Image URL'),
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
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Listing'),
            ),
          ],
        ),
      ),
    );
  }
}
