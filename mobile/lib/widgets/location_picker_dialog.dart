import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/services/osm_geocoding_service.dart';

class LocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerDialog({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _mapKey = GlobalKey();
  final _searchController = TextEditingController();
  late final MapController _mapController;
  late LatLng _selectedLocation;

  double _currentZoom = 15.0;
  String _address = '';
  String? _message;
  bool _isSearching = false;
  bool _isResolvingAddress = false;
  bool _isLocating = false;
  bool _isDraggingMarker = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
    _mapController = MapController();
    _reverseGeocode(_selectedLocation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isResolvingAddress = true;
      _message = null;
    });

    try {
      final address = await OSMGeocodingService.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _address = address;
        _isResolvingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address =
            'Selected Location (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
        _message =
            'Could not fetch an address. Check internet, or confirm using coordinates.';
        _isResolvingAddress = false;
      });
    }
  }

  void _setSelectedLocation(
    LatLng point, {
    bool moveMap = false,
    bool resolveAddress = true,
  }) {
    setState(() {
      _selectedLocation = point;
      _message = null;
    });

    if (moveMap) {
      _mapController.move(point, _currentZoom);
    }

    if (resolveAddress) {
      unawaited(_reverseGeocode(point));
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _message = 'Enter an address or landmark to search.');
      return;
    }

    setState(() {
      _isSearching = true;
      _message = null;
    });

    try {
      final result = await OSMGeocodingService.search(query);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _message = 'No matching location found. Try a more specific search.';
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _selectedLocation = result.point;
        _address = result.address;
        _isSearching = false;
      });
      _mapController.move(result.point, 16.0);
      _currentZoom = 16.0;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Search failed. Check internet and try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _locateMe() async {
    setState(() {
      _isLocating = true;
      _message = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _message = 'Location services are off. Turn on GPS or search manually.';
          _isLocating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _message = 'Location permission denied. Search or drag the pin manually.';
          _isLocating = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _message =
              'Location permission is permanently denied. Enable it in app settings or search manually.';
          _isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _isLocating = false);
      _setSelectedLocation(point, moveMap: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not detect GPS right now. Check signal, search, or drag the pin.';
        _isLocating = false;
      });
    }
  }

  void _updateMarkerFromGlobalPosition(Offset globalPosition) {
    final renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final local = renderBox.globalToLocal(globalPosition);
    final camera = _mapController.camera;
    final point = camera.pointToLatLng(Point(local.dx, local.dy));
    setState(() => _selectedLocation = point);
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
    _mapController.move(_selectedLocation, _currentZoom);
    setState(() {});
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
    _mapController.move(_selectedLocation, _currentZoom);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSearching || _isResolvingAddress || _isLocating;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose Issue Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Use current GPS location',
            onPressed: _isLocating ? null : _locateMe,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            key: _mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: _currentZoom,
              interactionOptions: InteractionOptions(
                flags: _isDraggingMarker
                    ? InteractiveFlag.none
                    : InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                _setSelectedLocation(point);
              },
              onPositionChanged: (position, hasGesture) {
                _currentZoom = position.zoom ?? _currentZoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jansetu_mobile',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 64,
                    height: 64,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() => _isDraggingMarker = true);
                        _updateMarkerFromGlobalPosition(details.globalPosition);
                      },
                      onPanUpdate: (details) {
                        _updateMarkerFromGlobalPosition(details.globalPosition);
                      },
                      onPanEnd: (_) {
                        setState(() => _isDraggingMarker = false);
                        unawaited(_reverseGeocode(_selectedLocation));
                      },
                      child: const Icon(
                        Icons.location_pin,
                        size: 54,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _SearchCard(
              controller: _searchController,
              isSearching: _isSearching,
              onSearch: _searchLocation,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 92,
            child: _LocationStatusCard(
              address: _address,
              message: _message,
              isBusy: isBusy,
              latitude: _selectedLocation.latitude,
              longitude: _selectedLocation.longitude,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 174,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomInBtn',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOutBtn',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 24),
              label: const Text(
                'CONFIRM LOCATION',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(_selectedLocation),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: 'Search address or landmark',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Search',
                  onPressed: onSearch,
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  final String address;
  final String? message;
  final bool isBusy;
  final double latitude;
  final double longitude;

  const _LocationStatusCard({
    required this.address,
    required this.message,
    required this.isBusy,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.location_on, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address.isEmpty ? 'Drag the pin or tap the map' : address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
