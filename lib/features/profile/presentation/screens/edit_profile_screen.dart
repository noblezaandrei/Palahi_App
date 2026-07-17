import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  String? _existingImageUrl;
  bool _isLoading = false;
  
  LatLng _selectedLatLng = const LatLng(14.5995, 120.9842); // Manila default
  GoogleMapController? _mapController;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _farmNameController = TextEditingController();
    _aboutController = TextEditingController();
    _addressController = TextEditingController();
    _latitudeController = TextEditingController(text: _selectedLatLng.latitude.toString());
    _longitudeController = TextEditingController(text: _selectedLatLng.longitude.toString());
    
    // Load existing breeder profile
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBreederData());
  }

  Future<void> _loadBreederData() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    
    final breeders = await ref.read(breederRepositoryProvider).getBreeders().first;
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
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_selectedLatLng),
      );
    }
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _aboutController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_offersNatural && !_offersAI) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service offered.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      String imageUrl = _existingImageUrl ?? '';
      
      if (_pickedImage != null) {
        final storagePath = 'breeders/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await ref.read(storageServiceProvider).uploadImage(_pickedImage!, storagePath);
      }

      final lat = double.tryParse(_latitudeController.text.trim()) ?? _selectedLatLng.latitude;
      final lng = double.tryParse(_longitudeController.text.trim()) ?? _selectedLatLng.longitude;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Update coordinate inputs and selected LatLng
  void _updateLocation(LatLng pos) {
    setState(() {
      _selectedLatLng = pos;
      _latitudeController.text = pos.latitude.toStringAsFixed(6);
      _longitudeController.text = pos.longitude.toStringAsFixed(6);
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are running on a Desktop platform that doesn't support Google Maps natively
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Breeder Profile'),
      ),
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
                        backgroundImage: _pickedImage != null
                            ? (kIsWeb ? NetworkImage(_pickedImage!.path) : FileImage(File(_pickedImage!.path)) as ImageProvider)
                            : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                ? NetworkImage(_existingImageUrl!)
                                : null,
                        child: (_pickedImage == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty))
                            ? const Icon(Icons.store, size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      )
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
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
                  onChanged: (val) => setState(() => _offersNatural = val ?? false),
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
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final d = double.tryParse(val);
                          if (d != null) {
                            setState(() {
                              _selectedLatLng = LatLng(d, _selectedLatLng.longitude);
                            });
                            _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLatLng));
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final d = double.tryParse(val);
                          if (d != null) {
                            setState(() {
                              _selectedLatLng = LatLng(_selectedLatLng.latitude, d);
                            });
                            _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLatLng));
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
                    child: isDesktop
                        ? _buildMockMapPicker()
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _selectedLatLng,
                              zoom: 13,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('farm_pin'),
                                position: _selectedLatLng,
                                draggable: true,
                                onDragEnd: _updateLocation,
                              ),
                            },
                            onMapCreated: (ctrl) => _mapController = ctrl,
                            onTap: _updateLocation,
                            myLocationEnabled: true,
                            zoomControlsEnabled: true,
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
              color: Colors.black.withAlpha(50),
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  // Fallback desktop coordinates mapper
  Widget _buildMockMapPicker() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.blue.shade700),
          const SizedBox(height: 8),
          const Text(
            'Interactive Google Map Fallback for Desktop',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              'Please adjust Latitude and Longitude using the text input boxes above. The location will be saved correctly on Firestore.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          // Add a preset quick coordinate selector for Bulacan / Manila testing
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  _updateLocation(const LatLng(15.0118, 120.9575)); // Bulacan Coordinates
                  _addressController.text = 'San Miguel, Bulacan';
                },
                child: const Text('Pin Bulacan'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _updateLocation(const LatLng(14.5995, 120.9842)); // Manila Coordinates
                  _addressController.text = 'Tondo, Manila';
                },
                child: const Text('Pin Manila'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
