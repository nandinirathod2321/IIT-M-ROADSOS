import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/map_cache_service.dart';
import '../../../presentation/blocs/location/location_cubit.dart';
import '../../../core/responders/responder_cubit.dart';
import '../../../core/responders/responder_state.dart';
import '../../../data/models/hospital.dart';
import '../../../data/models/police_station.dart';

/// Interactive map view showing nearby hospitals and police stations with
/// cached tiles for offline usage. Designed to be embedded inside a parent
/// screen (e.g. as a tab in [EmergencyScreen]).
class NearbyMapView extends StatefulWidget {
  const NearbyMapView({super.key});

  @override
  State<NearbyMapView> createState() => _NearbyMapViewState();
}

class _NearbyMapViewState extends State<NearbyMapView> {
  late Future<CacheStore> _cacheStoreFuture;
  final MapController _mapController = MapController();
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _cacheStoreFuture = MapCacheService.instance.getCacheStore();
    _monitorConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _monitorConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    });
    // Initial check
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() => _isOffline = results.contains(ConnectivityResult.none));
      }
    });
  }

  Future<void> _makeCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri url = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dialing: $phone",
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.infoBlue,
          ),
        );
      }
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showMarkerBottomSheet({
    required String name,
    required String type,
    required String phone,
    required double lat,
    required double lng,
    required double distanceKm,
    required Color accentColor,
    required IconData icon,
  }) {
    final sheetBg = Theme.of(context).colorScheme.surface;
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type,
                          style: AppTypography.bodySmall.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Distance
              Row(
                children: [
                  const Icon(Icons.near_me_rounded,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km away',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              if (phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchNavigation(lat, lng),
                      icon: const Icon(Icons.directions_rounded,
                          size: 16, color: Colors.white),
                      label: Text(
                        "NAVIGATE",
                        style: AppTypography.labelCaps
                            .copyWith(color: Colors.white, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.infoBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makeCall(phone),
                      icon: const Icon(Icons.phone_rounded,
                          size: 16, color: Colors.white),
                      label: Text(
                        "CALL",
                        style: AppTypography.labelCaps
                            .copyWith(color: Colors.white, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers(ResponderState responderState) {
    final markers = <Marker>[];

    // Hospital markers (red)
    for (final h in responderState.hospitals) {
      markers.add(
        Marker(
          point: LatLng(h.lat, h.lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showMarkerBottomSheet(
              name: h.name,
              type: h.type == HospitalType.trauma
                  ? 'Level 1 Trauma Center'
                  : 'General Hospital',
              phone: h.phone,
              lat: h.lat,
              lng: h.lng,
              distanceKm: h.distanceKm,
              accentColor: AppColors.emergencyRed,
              icon: Icons.local_hospital_rounded,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.emergencyRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergencyRed.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    // Police markers (blue)
    for (final p in responderState.police) {
      markers.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showMarkerBottomSheet(
              name: p.name,
              type: p.is24Hours ? '24 Hours Active' : 'Patrol Station',
              phone: p.phone,
              lat: p.lat,
              lng: p.lng,
              distanceKm: p.distanceKm,
              accentColor: AppColors.policeBlue,
              icon: Icons.local_police_rounded,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.policeBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.policeBlue.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_police_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final locState = context.watch<LocationCubit>().state;
    final responderState = context.watch<ResponderCubit>().state;

    // No GPS available
    if (!locState.hasLocation) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded,
                  color: AppColors.emergencyRed, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "GPS REQUIRED",
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Map requires GPS coordinates to center on your location.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final userLat = locState.latitude!;
    final userLng = locState.longitude!;

    return FutureBuilder<CacheStore>(
      future: _cacheStoreFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.emergencyRed),
                SizedBox(height: 16),
                Text(
                  "INITIALIZING MAP CACHE...",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_rounded,
                    color: AppColors.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Map unavailable",
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Could not initialize map tile cache.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        final cacheStore = snapshot.data!;
        final markers = _buildMarkers(responderState);

        return Stack(
          children: [
            // ── Map ─────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(userLat, userLng),
                initialZoom: 14.0,
                minZoom: 10.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.roadsos.mobile',
                  tileProvider: CachedTileProvider(
                    store: cacheStore,
                  ),
                ),
                // User location marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(userLat, userLng),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.emergencyRed, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emergencyRed.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.person_pin,
                              color: AppColors.emergencyRed, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                // Responder markers
                MarkerLayer(markers: markers),
              ],
            ),

            // ── Offline banner ──────────────────────────────────
            if (_isOffline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.emergencyAmber.withOpacity(0.92),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        "OFFLINE MAP MODE",
                        style: AppTypography.labelCaps.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Legend ──────────────────────────────────────────
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.borderSubtle, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(AppColors.emergencyRed,
                        "Hospitals (${responderState.hospitals.length})"),
                    const SizedBox(height: 4),
                    _legendItem(AppColors.policeBlue,
                        "Police (${responderState.police.length})"),
                  ],
                ),
              ),
            ),

            // ── Re-center FAB ───────────────────────────────────
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'map_recenter',
                backgroundColor: Theme.of(context).colorScheme.surface,
                onPressed: () {
                  _mapController.move(
                    LatLng(userLat, userLng),
                    14.0,
                  );
                },
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.emergencyRed, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
