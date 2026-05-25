import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

Future<String> performReverseGeocode(double lat, double lng) async {
  try {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';
    final completer = Completer<String>();
    final request = html.HttpRequest();
    request.open('GET', url);
    // Note: Nominatim prefers user agent header, but browser might restrict custom user agents.
    // Try sending it safely inside a try-catch, or skip it since standard browser fetches are fine.
    try {
      request.setRequestHeader('Accept', 'application/json');
    } catch (_) {}
    
    request.onLoadEnd.listen((_) {
      if (request.status == 200) {
        try {
          final data = json.decode(request.responseText ?? '') as Map<String, dynamic>;
          completer.complete(data['display_name'] ?? 'Coordinates: $lat, $lng');
        } catch (_) {
          completer.complete('Coordinates: $lat, $lng');
        }
      } else {
        completer.complete('Coordinates: $lat, $lng');
      }
    });
    request.onError.listen((_) {
      completer.complete('Coordinates: $lat, $lng');
    });
    request.send();
    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => 'Coordinates: $lat, $lng',
    );
  } catch (_) {
    // Suppress
  }
  return 'Coordinates: $lat, $lng';
}
