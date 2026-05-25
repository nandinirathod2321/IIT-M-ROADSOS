import 'package:flutter/foundation.dart' show kIsWeb;
import '../database/database_helper.dart';
import '../models/sos_event.dart';

class SosRepository {
  final DatabaseHelper _db;

  SosRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Logs a new SOS emergency event with live telemetry metrics.
  Future<void> logEvent({
    required String id,
    required double latitude,
    required double longitude,
    required String triggerType,
    Map<String, dynamic>? telemetry,
    String status = 'dispatched',
  }) async {
    await _db.logSosEvent(
      id: id,
      latitude: latitude,
      longitude: longitude,
      triggerType: triggerType,
      telemetry: telemetry,
      status: status,
    );
  }

  /// Retrieves the sorted chronological history of emergency incidents.
  Future<List<Map<String, dynamic>>> getEvents() async {
    return await _db.getSosEvents();
  }

  /// Resolves or updates the status of an emergency activation.
  Future<void> updateEventStatus(String id, String status) async {
    await _db.updateSosEventStatus(id, status);
  }

  /// Clears the recorded local telemetry history.
  Future<void> clearHistory() async {
    await _db.clearSosHistory();
  }
}
