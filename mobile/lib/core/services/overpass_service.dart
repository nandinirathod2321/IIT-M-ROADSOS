import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';
import '../utils/logger.dart';
import '../../data/models/nearby_place.dart';

class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';

  /// Fetches nearby hospitals, police stations, and towing services from OpenStreetMap.
  /// Standard radius is 10,000 meters (10km).
  Future<List<NearbyPlace>> fetchNearbyResponders(
    double lat,
    double lng, {
    int radiusMeters = 10000,
  }) async {
    AppLogger.info('Querying OSM Overpass API at ($lat, $lng) with radius ${radiusMeters}m...');

    // Construct the Overpass QL query
    final query = '''
    [out:json][timeout:8];
    (
      node["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
      node["healthcare"="hospital"](around:$radiusMeters,$lat,$lng);
      node["amenity"="police"](around:$radiusMeters,$lat,$lng);
      node["amenity"="car_repair"](around:$radiusMeters,$lat,$lng);
      node["emergency"="towing"](around:$radiusMeters,$lat,$lng);
      
      way["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
      way["healthcare"="hospital"](around:$radiusMeters,$lat,$lng);
      way["amenity"="police"](around:$radiusMeters,$lat,$lng);
    );
    out center;
    ''';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        AppLogger.error('Overpass API returned status code ${response.statusCode}');
        throw ApiException('Overpass API error', statusCode: response.statusCode);
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> elements = data['elements'] ?? [];
      AppLogger.info('Overpass API returned ${elements.length} raw elements.');

      final List<NearbyPlace> places = [];

      for (final element in elements) {
        try {
          final tags = element['tags'] ?? {};
          final name = tags['name'] ?? tags['operator'] ?? tags['brand'] ?? 'Emergency Service';
          
          // Determine lat/lng
          double itemLat;
          double itemLng;
          if (element['lat'] != null && element['lon'] != null) {
            itemLat = (element['lat'] as num).toDouble();
            itemLng = (element['lon'] as num).toDouble();
          } else if (element['center'] != null) {
            itemLat = (element['center']['lat'] as num).toDouble();
            itemLng = (element['center']['lon'] as num).toDouble();
          } else {
            // No coordinates, skip element
            continue;
          }

          // Determine type
          NearbyPlaceType type = NearbyPlaceType.towing;
          if (tags['amenity'] == 'hospital' || tags['healthcare'] == 'hospital') {
            type = NearbyPlaceType.hospital;
          } else if (tags['amenity'] == 'police') {
            type = NearbyPlaceType.police;
          }

          // Parse address info
          final street = tags['addr:street'] ?? '';
          final city = tags['addr:city'] ?? '';
          final house = tags['addr:housenumber'] ?? '';
          String address = '';
          if (street.isNotEmpty) {
            address = house.isNotEmpty ? '$house $street' : street;
            if (city.isNotEmpty) address += ', $city';
          } else {
            address = 'Near accident site';
          }

          // Parse contact details
          final phone = tags['phone'] ?? tags['contact:phone'] ?? tags['emergency:phone'];

          final dist = _haversine(lat, lng, itemLat, itemLng);

          places.add(NearbyPlace(
            id: '${element['type']}_${element['id']}',
            name: name,
            type: type,
            latitude: itemLat,
            longitude: itemLng,
            address: address,
            distanceKm: dist,
            phone: phone,
            isOperating: true,
          ));
        } catch (e) {
          AppLogger.warning('Failed to parse Overpass element: $e');
        }
      }

      // Sort by distance (closest first)
      places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return places;

    } catch (e) {
      AppLogger.error('Overpass service error', e);
      throw NetworkException('Network or API failure in Overpass service: $e');
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final double sinDLat = math.sin(dLat / 2);
    final double sinDLon = math.sin(dLon / 2);
    final double aVal = sinDLat * sinDLat +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * sinDLon * sinDLon;
    final c = 2 * math.atan2(math.sqrt(aVal), math.sqrt(1 - aVal));
    return r * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
