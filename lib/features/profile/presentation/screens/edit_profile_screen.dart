import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../features/breeder/data/breeder_repository.dart';
import '../../../../features/breeder/domain/models/breeder_model.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/colors.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _farmNameController;
  late TextEditingController _aboutController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  bool _offersNatural = false;
  bool _offersAI = false;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  LatLng _selectedLatLng = const LatLng(LocationUtils.camaligCenterLatitude, LocationUtils.camaligCenterLongitude); // Camalig default
  final MapController _mapController = MapController();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _farmNameController = TextEditingController();
    _aboutController = TextEditingController();
    _addressController = TextEditingController();
    _latitudeController = TextEditingController(
      text: _selectedLatLng.latitude.toString(),
    );
    _longitudeController = TextEditingController(
      text: _selectedLatLng.longitude.toString(),
    );

    // Load existing breeder profile
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBreederData());
  }

  Future<void> _loadBreederData() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final breeders = await ref
        .read(breederRepositoryProvider)
        .getBreeders()
        .first;
    final breeder = breeders.firstWhere(
      (b) => b.id == user.uid,
      orElse: () => breeders.isNotEmpty
          ? breeders.first
          : BreederModel(
              id: user.uid,
              userId: user.uid,
              farmName: 'My Farm',
              location: '',
              latitude: 14.5995,
              longitude: 120.9842,
              rating: 5.0,
              reviewCount: 0,
              imageUrl: '',
              about: 'Welcome to my breeder farm!',
              services: ['Natural Breeding', 'Artificial Insemination'],
            ),
    );

    if (mounted) {
      setState(() {
        _farmNameController.text = breeder.farmName;
        _aboutController.text = breeder.about;
        _addressController.text = breeder.location;
        _selectedLatLng = LatLng(breeder.latitude, breeder.longitude);
        _latitudeController.text = breeder.latitude.toString();
        _longitudeController.text = breeder.longitude.toString();
        _existingImageUrl = breeder.imageUrl;

        _offersNatural = breeder.services.contains('Natural Breeding');
        _offersAI = breeder.services.contains('Artificial Insemination');
      });

      _mapController.move(_selectedLatLng, 13.0);
    }
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _aboutController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
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
    if (!_formKey.currentState!.validate()) return;
    if (!_offersNatural && !_offersAI) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service offered.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing profile update...';
    });

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      String imageUrl = _existingImageUrl ?? '';

      if (_pickedImage != null) {
        setState(() {
          _uploadStatus = 'Uploading farm photo...';
        });

        final storagePath =
            'breeders/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await ref
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
      }

      setState(() {
        _uploadStatus = 'Saving profile details...';
      });

      final lat =
          double.tryParse(_latitudeController.text.trim()) ??
          _selectedLatLng.latitude;
      final lng =
          double.tryParse(_longitudeController.text.trim()) ??
          _selectedLatLng.longitude;

      if (!LocationUtils.isInCamaligAlbay(lat, lng)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Selected location must be within Camalig, Albay.'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      List<String> services = [];
      if (_offersNatural) services.add('Natural Breeding');
      if (_offersAI) services.add('Artificial Insemination');

      final updatedBreeder = BreederModel(
        id: user.uid,
        userId: user.uid,
        farmName: _farmNameController.text.trim(),
        location: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        rating: 5.0, // preserve or default
        reviewCount: 0,
        imageUrl: imageUrl,
        about: _aboutController.text.trim(),
        services: services,
      );

      await ref.read(breederRepositoryProvider).addBreeder(updatedBreeder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Breeder profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Update coordinate inputs and selected LatLng
  void _updateLocation(LatLng pos) {
    if (!LocationUtils.isInCamaligAlbay(pos.latitude, pos.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Selected location must be within Camalig, Albay.'),
        ),
      );
      return;
    }
    setState(() {
      _selectedLatLng = pos;
      _latitudeController.text = pos.latitude.toStringAsFixed(6);
      _longitudeController.text = pos.longitude.toStringAsFixed(6);
    });
    _mapController.move(pos, 13.0);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Breeder Profile')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile/Farm image uploader
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _pickedImageBytes != null
                            ? MemoryImage(_pickedImageBytes!)
                            : (_existingImageUrl != null &&
                                  _existingImageUrl!.isNotEmpty &&
                                  !_existingImageUrl!.toLowerCase().contains('google.com/url') &&
                                  !_existingImageUrl!.toLowerCase().contains('imgurl='))
                            ? NetworkImage(_existingImageUrl!)
                            : null,
                        child:
                            (_pickedImageBytes == null &&
                                (_existingImageUrl == null ||
                                    _existingImageUrl!.isEmpty ||
                                    _existingImageUrl!.toLowerCase().contains('google.com/url') ||
                                    _existingImageUrl!.toLowerCase().contains('imgurl=')))
                            ? const Icon(
                                Icons.store,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _farmNameController,
                  decoration: const InputDecoration(
                    labelText: 'Farm Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _aboutController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'About Farm',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Services Offered *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                CheckboxListTile(
                  title: const Text('Natural Breeding'),
                  value: _offersNatural,
                  onChanged: (val) =>
                      setState(() => _offersNatural = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Artificial Insemination'),
                  value: _offersAI,
                  onChanged: (val) => setState(() => _offersAI = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                const Text(
                  'Farm Location & GIS Coordinates *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address / Area (e.g. San Miguel, Bulacan)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final d = double.tryParse(val);
                          if (d != null) {
                            setState(() {
                              _selectedLatLng = LatLng(
                                d,
                                _selectedLatLng.longitude,
                              );
                            });
                            _mapController.move(_selectedLatLng, 13.0);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final d = double.tryParse(val);
                          if (d != null) {
                            setState(() {
                              _selectedLatLng = LatLng(
                                _selectedLatLng.latitude,
                                d,
                              );
                            });
                            _mapController.move(_selectedLatLng, 13.0);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Interactive Map Selection Box
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLatLng,
                        initialZoom: 13,
                        onTap: (tapPosition, point) => _updateLocation(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.palahi',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLatLng,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: const Text('Save Profile'),
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
                          _uploadStatus.isNotEmpty ? _uploadStatus : 'Saving profile...',
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
