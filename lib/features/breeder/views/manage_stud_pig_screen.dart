import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/stud_pig_model.dart';
import '../repositories/stud_pig_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/colors.dart';
import '../../auth/repositories/auth_repository.dart';
import 'package:palahi/core/utils/error_messages.dart';

class ManageStudPigScreen extends ConsumerStatefulWidget {
  final StudPigModel? existingPig;

  const ManageStudPigScreen({super.key, this.existingPig});

  @override
  ConsumerState<ManageStudPigScreen> createState() =>
      _ManageStudPigScreenState();
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
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  bool _isAvailable = true;
  String _serviceType = 'Natural Breeding';
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  final ImagePicker _picker = ImagePicker();

  static const _serviceTypes = [
    'Natural Breeding',
    'Artificial Insemination',
    'Both',
  ];

  static String? _requiredText(String? val, String message) =>
      val == null || val.trim().isEmpty ? message : null;

  /// A non-negative number; [whole] for ages.
  static String? _validNumber(String? val, {bool whole = false}) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    final number = whole ? int.tryParse(text) : double.tryParse(text);
    // double.tryParse also accepts "NaN" and "Infinity".
    if (number == null || !number.isFinite) return 'Invalid number';
    if (number < 0) return 'Must be 0 or more';
    return null;
  }

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
      // An older/odd value that isn't one of the dropdown's options would
      // crash the dropdown, so fall back to the default.
      final service = widget.existingPig!.serviceType;
      _serviceType = _serviceTypes.contains(service)
          ? service
          : 'Natural Breeding';
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

    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or upload a pig image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing submission...';
    });

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      String imageUrl = _existingImageUrl ?? '';

      if (_pickedImage != null) {
        setState(() {
          _uploadStatus = 'Uploading pig photo...';
        });

        final storagePath =
            'pigs/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await ref
            .read(storageServiceProvider)
            .uploadImage(
              _pickedImage!,
              storagePath,
              onProgress: (progress) {
                if (mounted) {
                  setState(() {
                    _uploadProgress = progress;
                  });
                }
              },
            );

        imageUrl = uploadedUrl;

        if (_existingImageUrl != null &&
            _existingImageUrl!.isNotEmpty &&
            _existingImageUrl!.contains('firebasestorage') &&
            _existingImageUrl != uploadedUrl) {
          try {
            await FirebaseStorage.instance
                .refFromURL(_existingImageUrl!)
                .delete();
          } catch (e) {
            debugPrint('Error deleting old image after successful upload: $e');
          }
        }
      }

      setState(() {
        _uploadStatus = 'Saving listing...';
      });

      final double weight =
          double.tryParse(_weightController.text.trim()) ?? 0.0;
      final double price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final int age = int.tryParse(_ageController.text.trim()) ?? 0;

      final newPig = StudPigModel(
        id: widget.existingPig?.id ?? '',
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

      await ref
          .read(studPigRepositoryProvider)
          .saveStudPig(newPig)
          .withNetworkTimeout();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stud pig saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
        title: Text(
          widget.existingPig == null ? 'Add Stud Pig' : 'Edit Stud Pig',
        ),
        actions: [
          if (widget.existingPig != null)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Listing'),
                    content: const Text(
                      'Are you sure you want to delete this stud pig?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _isLoading = true);
                  try {
                    await ref
                        .read(studPigRepositoryProvider)
                        .deleteStudPig(widget.existingPig!.id)
                        .withNetworkTimeout();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting: ${friendlyError(e)}'),
                        ),
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
                    child: _pickedImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _pickedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : (_existingImageUrl != null &&
                              _existingImageUrl!.isNotEmpty &&
                              !_existingImageUrl!.toLowerCase().contains(
                                'google.com/url',
                              ) &&
                              !_existingImageUrl!.toLowerCase().contains(
                                'imgurl=',
                              ))
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to select a pig photo',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select a pig photo',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Required *',
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: const InputDecoration(
                    labelText: 'Pig Name *',
                    hintText: 'Enter name (e.g. Duroc Champion)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => _requiredText(val, 'Please enter a name'),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _breedController,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: const InputDecoration(
                    labelText: 'Breed *',
                    hintText: 'e.g. Duroc, Landrace, Large White',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      _requiredText(val, 'Please enter the breed'),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        inputFormatters: [LengthLimitingTextInputFormatter(4)],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age (Months) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => _validNumber(val, whole: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => _validNumber(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  inputFormatters: [LengthLimitingTextInputFormatter(9)],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price / Stud Fee (₱) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => _validNumber(val),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _serviceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Offered *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Natural Breeding',
                      child: Text('Natural Breeding'),
                    ),
                    DropdownMenuItem(
                      value: 'Artificial Insemination',
                      child: Text('Artificial Insemination'),
                    ),
                    DropdownMenuItem(
                      value: 'Both',
                      child: Text('Both (Natural & AI)'),
                    ),
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
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Enter details about health, genetics, vaccine status, etc.',
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
              color: Colors.black.withAlpha(120),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _uploadStatus.isNotEmpty
                              ? _uploadStatus
                              : 'Saving listing...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_pickedImage != null && _uploadProgress > 0) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey.shade200,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
