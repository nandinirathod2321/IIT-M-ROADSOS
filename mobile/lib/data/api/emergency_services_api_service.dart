import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_shelter.dart';

class EmergencyServicesApiService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  final http.Client _client;

  EmergencyServicesApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the OpenStreetMap Overpass interpreter for nearby emergency services.
  Future<Map<String, List<dynamic>>> fetchNearbyServices(
    double lat,
    double lng, {
    int radiusMeters = 10000,
  }) async {
    final hospitals = <Hospital>[];
    final police = <PoliceStation>[];
    final towing = <TowingService>[];
    final shelters = <EmergencyShelter>[];

    final query = '''
    [out:json][timeout:15];
    (
      node["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
      way["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
      node["healthcare"="hospital"](around:$radiusMeters,$lat,$lng);
      way["healthcare"="hospital"](around:$radiusMeters,$lat,$lng);
      node["amenity"="police"](around:$radiusMeters,$lat,$lng);
      way["amenity"="police"](around:$radiusMeters,$lat,$lng);
      node["amenity"="car_repair"](around:$radiusMeters,$lat,$lng);
      way["amenity"="car_repair"](around:$radiusMeters,$lat,$lng);
      node["shop"="car_repair"](around:$radiusMeters,$lat,$lng);
      way["shop"="car_repair"](around:$radiusMeters,$lat,$lng);
      node["emergency"="towing"](around:$radiusMeters,$lat,$lng);
      way["emergency"="towing"](around:$radiusMeters,$lat,$lng);
      node["amenity"="shelter"](around:$radiusMeters,$lat,$lng);
      way["amenity"="shelter"](around:$radiusMeters,$lat,$lng);
      node["social_facility"="shelter"](around:$radiusMeters,$lat,$lng);
      way["social_facility"="shelter"](around:$radiusMeters,$lat,$lng);
    );
    out center;
    ''';

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('[Overpass] API failure: HTTP ${response.statusCode}');
      throw http.ClientException('Overpass API returned status code ${response.statusCode}');
    }

    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final elements = data['elements'] as List? ?? [];
    debugPrint('[Overpass] Received ${elements.length} raw elements');

    for (final elem in elements) {
      final tags = Map<String, dynamic>.from(elem['tags'] as Map? ?? {});
      final id = (elem['id'] ?? '').toString();

      double itemLat = 0.0;
      double itemLng = 0.0;
      if (elem['lat'] != null && elem['lon'] != null) {
        itemLat = (elem['lat'] as num).toDouble();
        itemLng = (elem['lon'] as num).toDouble();
      } else if (elem['center'] != null) {
        itemLat = (elem['center']['lat'] as num).toDouble();
        itemLng = (elem['center']['lon'] as num).toDouble();
      } else {
        continue;
      }

      final phone = (tags['phone'] ?? tags['contact:phone'] ?? tags['emergency:phone'] ?? '') as String;
      final street = tags['addr:street'] as String? ?? '';
      final city = tags['addr:city'] as String? ?? tags['addr:town'] as String? ?? '';
      final house = tags['addr:housenumber'] as String? ?? '';
      String address = tags['addr:full'] as String? ?? '';
      if (address.isEmpty && street.isNotEmpty) {
        address = house.isNotEmpty ? '$house $street' : street;
        if (city.isNotEmpty) address += ', $city';
      }
      if (address.isEmpty) address = city.isNotEmpty ? city : 'Near your location';

      final amenity = tags['amenity'] as String? ?? '';
      final healthcare = tags['healthcare'] as String? ?? '';
      final socialFacility = tags['social_facility'] as String? ?? '';
      final emergencyTag = tags['emergency'] as String? ?? '';
      final shop = tags['shop'] as String? ?? '';

      final name = (tags['name'] ?? tags['operator'] ?? tags['brand'] ?? '') as String;

      if (amenity == 'hospital' || healthcare == 'hospital') {
        final displayName = name.isNotEmpty ? name : 'Hospital';
        final isTrauma = tags['emergency'] == 'yes' || tags['trauma'] == 'yes';
        hospitals.add(Hospital(
          id: id,
          name: displayName,
          address: address,
          lat: itemLat,
          lng: itemLng,
          phone: phone,
          type: isTrauma ? HospitalType.trauma : HospitalType.general,
          hasEmergency: tags['emergency'] == 'yes' || tags['emergency'] != 'no',
          hasICU: tags['icu'] == 'yes',
          hasBloodBank: tags['blood_bank'] == 'yes',
          ambulanceCount: tags['ambulances'] != null ? int.tryParse(tags['ambulances'].toString()) ?? 1 : 1,
          lastUpdated: DateTime.now(),
          sourceApi: 'OSM Overpass',
        ));
      } else if (amenity == 'police') {
        police.add(PoliceStation(
          id: id,
          name: name.isNotEmpty ? name : 'Police Station',
          address: address,
          lat: itemLat,
          lng: itemLng,
          phone: phone,
          districtCode: tags['operator'] as String? ?? '',
          is24Hours: tags['opening_hours'] == '24/7' || tags['is_24h'] == 'yes',
        ));
      } else if (amenity == 'car_repair' || shop == 'car_repair' || emergencyTag == 'towing') {
        towing.add(TowingService(
          id: id,
          name: name.isNotEmpty ? name : 'Towing Service',
          phone: phone,
          lat: itemLat,
          lng: itemLng,
          address: address,
          serviceRadius: 20.0,
          operatingHours: tags['opening_hours'] as String? ?? 'Unknown',
          vehicleTypes: const ['car', 'bike'],
        ));
      } else if (amenity == 'shelter' || socialFacility == 'shelter') {
        final rawCapacity = tags['capacity'] as String? ?? '';
        final capacityVal = int.tryParse(rawCapacity) ?? 50;
        shelters.add(EmergencyShelter(
          id: id,
          name: name.isNotEmpty ? name : 'Emergency Shelter',
          address: address,
          lat: itemLat,
          lng: itemLng,
          phone: phone,
          capacity: capacityVal,
        ));
      }
    }

    return {
      'hospitals': hospitals,
      'police': police,
      'towing': towing,
      'shelters': shelters,
    };
  }

  /// Performs Nominatim reverse geocoding to resolve a user-friendly city name.
  Future<String> fetchCityName(double lat, double lng) async {
    try {
      final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final geoRes = await _client.get(
        geoUrl,
        headers: {'User-Agent': 'RoadSOS/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (geoRes.statusCode == 200) {
        final geoData = json.decode(utf8.decode(geoRes.bodyBytes)) as Map<String, dynamic>;
        final addr = geoData['address'] as Map<String, dynamic>?;
        if (addr != null) {
          return addr['city'] as String? ??
              addr['town'] as String? ??
              addr['village'] as String? ??
              addr['state_district'] as String? ??
              addr['suburb'] as String? ??
              'Local';
        }
      }
    } catch (e) {
      debugPrint('[Overpass] Nominatim reverse geocoding error: $e');
    }
    return 'Local';
  }
}
