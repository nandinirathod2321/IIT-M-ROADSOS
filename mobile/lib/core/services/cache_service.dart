import 'dart:math' as math;
import '../utils/logger.dart';
import '../../data/models/nearby_place.dart';
import '../../data/models/chat_message.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cached GPS Coordinates
  double? _cachedLatitude;
  double? _cachedLongitude;
  String? _cachedCity;
  DateTime? _coordsTimestamp;

  // Cached Nearby Places
  List<NearbyPlace> _cachedPlaces = [];
  DateTime? _placesTimestamp;
  double? _placesRefLat;
  double? _placesRefLng;

  // Cached Chat History
  final List<ChatMessageModel> _chatHistory = [];

  void setCoordinates(double lat, double lng, String city) {
    AppLogger.info('Caching coordinates: $lat, $lng ($city)');
    _cachedLatitude = lat;
    _cachedLongitude = lng;
    _cachedCity = city;
    _coordsTimestamp = DateTime.now();
  }

  double? get cachedLatitude => _cachedLatitude;
  double? get cachedLongitude => _cachedLongitude;
  String? get cachedCity => _cachedCity;
  DateTime? get coordsTimestamp => _coordsTimestamp;

  bool get hasValidCoordinates =>
      _cachedLatitude != null &&
      _cachedLongitude != null &&
      _coordsTimestamp != null &&
      DateTime.now().difference(_coordsTimestamp!).inMinutes < 15;

  void setNearbyPlaces(List<NearbyPlace> places, double refLat, double refLng) {
    AppLogger.info('Caching ${places.length} nearby places for reference coordinates ($refLat, $refLng)');
    _cachedPlaces = List.unmodifiable(places);
    _placesRefLat = refLat;
    _placesRefLng = refLng;
    _placesTimestamp = DateTime.now();
  }

  List<NearbyPlace> get cachedPlaces => _cachedPlaces;
  double? get placesRefLat => _placesRefLat;
  double? get placesRefLng => _placesRefLng;
  DateTime? get placesTimestamp => _placesTimestamp;

  bool hasValidPlaces(double currentLat, double currentLng, double distanceThresholdKm) {
    if (_placesTimestamp == null || _placesRefLat == null || _placesRefLng == null) {
      return false;
    }
    // Check elapsed time (e.g. valid for 10 minutes)
    final elapsedMin = DateTime.now().difference(_placesTimestamp!).inMinutes;
    if (elapsedMin >= 10) return false;

    // Check distance from reference coordinates
    final distanceKm = _haversine(currentLat, currentLng, _placesRefLat!, _placesRefLng!);
    AppLogger.info('Distance from cached reference places is ${distanceKm.toStringAsFixed(2)} km, elapsed $elapsedMin mins');
    return distanceKm < distanceThresholdKm;
  }

  // AI Chat History
  List<ChatMessageModel> get chatHistory => List.unmodifiable(_chatHistory);

  void addChatMessage(ChatMessageModel message) {
    AppLogger.info('Caching chat message: user=${message.isUser}, text_length=${message.text.length}');
    _chatHistory.add(message);
  }

  void setChatHistory(List<ChatMessageModel> history) {
    _chatHistory.clear();
    _chatHistory.addAll(history);
  }

  void clearChatHistory() {
    AppLogger.info('Clearing cached chat history');
    _chatHistory.clear();
  }

  void clearAll() {
    AppLogger.info('Clearing all in-memory caches');
    _cachedLatitude = null;
    _cachedLongitude = null;
    _cachedCity = null;
    _coordsTimestamp = null;
    _cachedPlaces = [];
    _placesTimestamp = null;
    _placesRefLat = null;
    _placesRefLng = null;
    _chatHistory.clear();
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
