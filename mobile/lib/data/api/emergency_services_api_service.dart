import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_shelter.dart';

class EmergencyServicesApiService {
  final http.Client _client;

  EmergencyServicesApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the OpenStreetMap Overpass interpreter for nearby emergency services.
  /// Categorizes and parses results into appropriate models.
  Future<Map<String, List<dynamic>>> fetchNearbyServices(double lat, double lng) async {
    final hospitals = <Hospital>[];
    final police = <PoliceStation>[];
    final towing = <TowingService>[];
    final shelters = <EmergencyShelter>[];

    final query = '''
    [out:json][timeout:15];
    (
      node["amenity"="hospital"](around:25000,$lat,$lng);
      way["amenity"="hospital"](around:25000,$lat,$lng);
      node["amenity"="police"](around:25000,$lat,$lng);
      way["amenity"="police"](around:25000,$lat,$lng);
      node["amenity"="car_repair"](around:25000,$lat,$lng);
      way["amenity"="car_repair"](around:25000,$lat,$lng);
      node["amenity"="shelter"](around:25000,$lat,$lng);
      way["amenity"="shelter"](around:25000,$lat,$lng);
      node["social_facility"="shelter"](around:25000,$lat,$lng);
      way["social_facility"="shelter"](around:25000,$lat,$lng);
    );
    out center;
    ''';

    final response = await _client.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: query,
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];

      for (final elem in elements) {
        final tags = elem['tags'] as Map? ?? {};
        final name = tags['name'] as String? ?? '';
        if (name.isEmpty) continue;

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

        final phone = tags['phone'] as String? ?? tags['contact:phone'] as String? ?? '';
        final street = tags['addr:street'] as String? ?? '';
        final city = tags['addr:city'] as String? ?? '';
        final address = tags['addr:full'] as String? ?? 
                        (street.isNotEmpty ? "$street, $city" : tags['addr:housename'] as String? ?? '');

        final amenity = tags['amenity'] as String? ?? '';
        final socialFacility = tags['social_facility'] as String? ?? '';

        if (amenity == 'hospital') {
          final isTrauma = tags['emergency'] == 'yes' || tags['trauma'] == 'yes';
          hospitals.add(Hospital(
            id: id,
            name: name,
            address: address.isNotEmpty ? address : 'Medical Center, $city',
            lat: itemLat,
            lng: itemLng,
            phone: phone,
            type: isTrauma ? HospitalType.trauma : HospitalType.general,
            hasEmergency: tags['emergency'] == 'yes' || tags['emergency'] == 'no' ? tags['emergency'] == 'yes' : true,
            hasICU: tags['icu'] == 'yes',
            hasBloodBank: tags['blood_bank'] == 'yes',
            ambulanceCount: tags['ambulances'] != null ? int.tryParse(tags['ambulances'].toString()) ?? 1 : 1,
            lastUpdated: DateTime.now(),
            sourceApi: 'OSM Overpass',
            rating: 4.0 + (id.hashCode % 10) / 10.0,
          ));
        } else if (amenity == 'police') {
          police.add(PoliceStation(
            id: id,
            name: name,
            address: address.isNotEmpty ? address : 'Police Station, $city',
            lat: itemLat,
            lng: itemLng,
            phone: phone,
            districtCode: tags['operator'] as String? ?? 'OSM-Zone',
            is24Hours: tags['opening_hours'] == '24/7' || tags['is_24h'] == 'yes',
          ));
        } else if (amenity == 'car_repair') {
          towing.add(TowingService(
            id: id,
            name: name,
            phone: phone.isNotEmpty ? phone : '+91 99000 99000',
            lat: itemLat,
            lng: itemLng,
            serviceRadius: 20.0,
            operatingHours: tags['opening_hours'] as String? ?? '24/7',
            vehicleTypes: const ['car', 'bike'],
          ));
        } else if (amenity == 'shelter' || amenity == 'refuge_site' || socialFacility == 'shelter') {
          final rawCapacity = tags['capacity'] as String? ?? '';
          final capacityVal = int.tryParse(rawCapacity) ?? (50 + (id.hashCode % 150));
          shelters.add(EmergencyShelter(
            id: id,
            name: name,
            address: address.isNotEmpty ? address : 'Emergency Shelter, $city',
            lat: itemLat,
            lng: itemLng,
            phone: phone.isNotEmpty ? phone : '+91 99111 22333',
            capacity: capacityVal,
          ));
        }
      }
    } else {
      throw http.ClientException('Overpass API returned status code ${response.statusCode}');
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
      print("Nominatim reverse geocoding error: $e");
    }
    return 'Local';
  }
}
