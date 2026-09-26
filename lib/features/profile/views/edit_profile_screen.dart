import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/core/utils/location_utils.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/services/storage_service.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/error_messages.dart';

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

  LatLng _selectedLatLng = const LatLng(
    LocationUtils.camaligCenterLatitude,
    LocationUtils.camaligCenterLongitude,
  ); // Camalig default
  GoogleMapController? _mapController;

  // The breeder's existing document, kept so that saving can preserve the
  // fields this form doesn't edit. Null until loaded, or if they have none yet.
  BreederModel? _loadedBreeder;

  // Whether _selectedLatLng is a real pin (saved or just tapped) rather
  // than the Camalig-centre placeholder — saving the placeholder would put
  // this farm on everyone's map at the town hall.
  bool _hasPin = false;
  MapType _mapType = MapType.hybrid;

  void _moveCamera(LatLng target) {
    // Zoomed in far enough to see the actual farm lot; the town-wide view
    // is only used before a pin exists.
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _hasPin ? 17.0 : 13.0),
    );
  }

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

    // Match strictly on this user's own document. Falling back to another
    // breeder in the list (as this used to) loads a stranger's farm name,
    // photo and coordinates into the form — and the next save writes all of
    // it back under this user's id.
    BreederModel? existing;
    for (final b in breeders) {
      if (b.id == user.uid) {
        existing = b;
        break;
      }
    }

    final breeder =
        existing ??
        BreederModel(
          id: user.uid,
          userId: user.uid,
          farmName: 'My Farm',
          location: '',
          latitude: LocationUtils.camaligCenterLatitude,
          longitude: LocationUtils.camaligCenterLongitude,
          rating: 0.0,
          reviewCount: 0,
          imageUrl: '',
          about: 'Welcome to my breeder farm!',
          services: ['Natural Breeding', 'Artificial Insemination'],
        );

    if (mounted) {
      setState(() {
        _loadedBreeder = existing;
        _farmNameController.text = breeder.farmName;
        _aboutController.text = breeder.about;
        _addressController.text = breeder.location;

        // New breeder documents are seeded with placeholder coordinates well
        // outside Camalig, which would open this picker over the wrong part
        // of the country. Start at Camalig centre until they've pinned a real
        // location, since that's the only area they're allowed to choose in.
        _hasPin = LocationUtils.isInCamaligAlbay(
          breeder.latitude,
          breeder.longitude,
        );
        _selectedLatLng = _hasPin
            ? LatLng(breeder.latitude, breeder.longitude)
            : const LatLng(
                LocationUtils.camaligCenterLatitude,
                LocationUtils.camaligCenterLongitude,
              );
        _latitudeController.text = _selectedLatLng.latitude.toString();
        _longitudeController.text = _selectedLatLng.longitude.toString();
        _existingImageUrl = breeder.imageUrl;

        _offersNatural = breeder.services.contains('Natural Breeding');
        _offersAI = breeder.services.contains('Artificial Insemination');
      });

      _moveCamera(_selectedLatLng);
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

      // Validate everything before uploading, so a missing pin or service
      // doesn't waste a photo upload.
      final lat =
          double.tryParse(_latitudeController.text.trim()) ??
          _selectedLatLng.latitude;
      final lng =
          double.tryParse(_longitudeController.text.trim()) ??
          _selectedLatLng.longitude;

      if (!_hasPin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please tap the map to pin your exact farm location.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (!LocationUtils.isInCamaligAlbay(lat, lng)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Selected location must be within Camalig, Albay.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (!_offersNatural && !_offersAI) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one service you offer.'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

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

      List<String> services = [];
      if (_offersNatural) services.add('Natural Breeding');
      if (_offersAI) services.add('Artificial Insemination');

      // addBreeder does a set(), which replaces the whole document — so every
      // field this form doesn't edit has to be carried over explicitly.
      // Omitting them previously reset the breeder's rating to a hardcoded 5.0
      // and wiped their entire availability calendar on each profile save.
      final updatedBreeder = BreederModel(
        id: user.uid,
        userId: user.uid,
        farmName: _farmNameController.text.trim(),
        location: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        rating: _loadedBreeder?.rating ?? 0.0,
        reviewCount: _loadedBreeder?.reviewCount ?? 0,
        availableDates: _loadedBreeder?.availableDates ?? const [],
        imageUrl: imageUrl,
        about: _aboutController.text.trim(),
        services: services,
      );

      await ref
          .read(breederRepositoryProvider)
          .addBreeder(updatedBreeder)
          .withNetworkTimeout();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Breeder profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${friendlyError(e)}'),
          ),
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
    if (!LocationUtils.isInCamaligAlbay(pos.latitude, pos.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: Selected location must be within Camalig, Albay.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _hasPin = true;
      _selectedLatLng = pos;
      _latitudeController.text = pos.latitude.toStringAsFixed(6);
      _longitudeController.text = pos.longitude.toStringAsFixed(6);
    });
    _moveCamera(pos);
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
                                  !_existingImageUrl!.toLowerCase().contains(
                                    'google.com/url',
                                  ) &&
                                  !_existingImageUrl!.toLowerCase().contains(
                                    'imgurl=',
                                  ))
                            ? NetworkImage(_existingImageUrl!)
                            : null,
                        child:
                            (_pickedImageBytes == null &&
                                (_existingImageUrl == null ||
                                    _existingImageUrl!.isEmpty ||
                                    _existingImageUrl!.toLowerCase().contains(
                                      'google.com/url',
                                    ) ||
                                    _existingImageUrl!.toLowerCase().contains(
                                      'imgurl=',
                                    )))
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
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  decoration: const InputDecoration(
                    labelText: 'Farm Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _aboutController,
                  maxLength: 1000,
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
                  inputFormatters: [LengthLimitingTextInputFormatter(150)],
                  decoration: const InputDecoration(
                    labelText: 'Address / Area (e.g. San Miguel, Bulacan)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
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
                              _hasPin = true;
                              _selectedLatLng = LatLng(
                                d,
                                _selectedLatLng.longitude,
                              );
                            });
                            _moveCamera(_selectedLatLng);
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
                              _hasPin = true;
                              _selectedLatLng = LatLng(
                                _selectedLatLng.latitude,
                                d,
                              );
                            });
                            _moveCamera(_selectedLatLng);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Tap the map to choose your location. The latitude and longitude fields will update automatically.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),

                // Interactive Map Selection Box
                Container(
                  height: 360,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedLatLng,
                        zoom: 13.0,
                      ),
                      mapType: _mapType,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // The saved profile may have finished loading before
                        // the map existed, leaving the initial camera on the
                        // Camalig default — re-centre once we can.
                        _moveCamera(_selectedLatLng);
                      },
                      onTap: _updateLocation,
                      // This map lives inside a scrolling ListView. Without
                      // claiming gestures eagerly the list wins the arena and
                      // swallows taps and drags meant for the map, making it
                      // impossible to pin a location.
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              EagerGestureRecognizer.new,
                            ),
                          },
                      markers: {
                        if (_hasPin)
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: _selectedLatLng,
                            draggable: true,
                            onDragEnd: _updateLocation,
                          ),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _moveCamera(_selectedLatLng);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Center on pin'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _mapType = _mapType == MapType.hybrid
                              ? MapType.normal
                              : MapType.hybrid,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        icon: Icon(
                          _mapType == MapType.hybrid
                              ? Icons.map
                              : Icons.satellite_alt,
                        ),
                        label: Text(
                          _mapType == MapType.hybrid ? 'Road map' : 'Satellite',
                        ),
                      ),
                    ),
                  ],
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
                          _uploadStatus.isNotEmpty
                              ? _uploadStatus
                              : 'Saving profile...',
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
