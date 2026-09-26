import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';
import 'package:palahi/features/map/repositories/location_service.dart';
import 'package:palahi/core/utils/error_messages.dart';

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
  GoogleMapController? _mapController;
  // Satellite (with labels) lets the farmer see their actual buildings/lot
  // instead of guessing on a plain road map.
  MapType _mapType = MapType.hybrid;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  /// Drops the pin on the phone's current GPS fix — the most accurate option
  /// when the farmer is standing on their farm.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService().getCurrentLocation();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      if (!LocationUtils.isInCamaligAlbay(point.latitude, point.longitude)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your current location is outside Camalig, Albay. Tap the map to pin your farm instead.',
            ),
          ),
        );
        return;
      }
      setState(() => _selected = point);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 18));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
              // Close enough to place the pin on the actual farm, not just
              // the right barangay. Without a saved pin, show the whole town.
              zoom: widget.initialLocation != null ? 18.0 : 14.0,
            ),
            mapType: _mapType,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _handleTap,
            markers: _selected == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selected!,
                      draggable: true,
                      onDragEnd: _handleTap,
                    ),
                  },
          ),
          Positioned(
            right: 12,
            bottom: 84,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'picker_map_type',
                  tooltip: 'Toggle satellite view',
                  onPressed: () => setState(
                    () => _mapType = _mapType == MapType.hybrid
                        ? MapType.normal
                        : MapType.hybrid,
                  ),
                  child: Icon(
                    _mapType == MapType.hybrid
                        ? Icons.map
                        : Icons.satellite_alt,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'picker_my_location',
                  tooltip: 'Use my current location',
                  onPressed: _locating ? null : _useCurrentLocation,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
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
                'Tap the map (or drag the pin) to mark your farm exactly. On your farm now? Use the location button. Must be within Camalig, Albay.',
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
