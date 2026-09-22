import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';

/// Lets the user tap the map to drop a pin, then confirm it. Pops with the
/// picked LatLng, or null if cancelled.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  void _handleTap(LatLng point) {
    if (!LocationUtils.isInCamaligAlbay(point.latitude, point.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a location within Camalig, Albay.'),
        ),
      );
      return;
    }
    setState(() => _selected = point);
  }

  @override
  Widget build(BuildContext context) {
    // Farmers, like breeders, are restricted to Camalig, Albay — the map
    // always centers there rather than on GPS, since a farm outside that
    // area couldn't be saved anyway.
    final LatLng initialCenter =
        widget.initialLocation ??
        const LatLng(
          LocationUtils.camaligCenterLatitude,
          LocationUtils.camaligCenterLongitude,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Your Farm Location (Camalig, Albay)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialCenter,
              zoom: 15.0,
            ),
            onTap: _handleTap,
            markers: _selected == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selected!,
                    ),
                  },
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Tap the map to place a pin on your farm (must be within Camalig, Albay).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Confirm Location'),
            ),
          ),
        ],
      ),
    );
  }
}
