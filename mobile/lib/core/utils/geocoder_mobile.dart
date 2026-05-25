import 'dart:io';
import 'dart:convert';

Future<String> performReverseGeocode(double lat, double lng) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
    final request = await client.getUrl(uri);
    request.headers.setUserAgent('RoadSOS/1.0');
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = json.decode(body) as Map<String, dynamic>;
      return data['display_name'] ?? 'Coordinates: $lat, $lng';
    }
  } catch (_) {
    // Suppress
  }
  return 'Coordinates: $lat, $lng';
}
