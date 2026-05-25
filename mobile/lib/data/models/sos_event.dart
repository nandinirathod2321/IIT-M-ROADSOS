import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a logged SOS emergency incident inside the `sos_events` SQLite table.
class SosEvent extends Equatable {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String address;
  final String emergencyType;
  final DateTime timestamp;
  final List<String> contactsNotified;
  final String nearestHospital;
  final String nearestPoliceStation;
  final String status;

  const SosEvent({
    required this.id,
    this.userId = 'me',
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.emergencyType,
    required this.timestamp,
    this.contactsNotified = const [],
    this.nearestHospital = '',
    this.nearestPoliceStation = '',
    this.status = 'dispatched',
  });

  // ── Serialisation ────────────────────────────────────────────────────

  factory SosEvent.fromMap(Map<String, dynamic> map) {
    return SosEvent(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'me',
      latitude: (map['latitude'] as num?)?.toDouble() ?? (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
      emergencyType: map['emergency_type'] as String? ?? map['triggerType'] as String? ?? 'manual',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      contactsNotified: _splitCsv(map['contacts_notified']),
      nearestHospital: map['nearest_hospital'] as String? ?? '',
      nearestPoliceStation: map['nearest_police_station'] as String? ?? '',
      status: map['status'] as String? ?? 'dispatched',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'emergency_type': emergencyType,
      'timestamp': timestamp.toIso8601String(),
      'contacts_notified': contactsNotified.join(','),
      'nearest_hospital': nearestHospital,
      'nearest_police_station': nearestPoliceStation,
      'status': status,
    };
  }

  String toJson() => json.encode(toMap());

  factory SosEvent.fromJson(String source) => 
      SosEvent.fromMap(json.decode(source) as Map<String, dynamic>);

  // ── Copy With ────────────────────────────────────────────────────────

  SosEvent copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? address,
    String? emergencyType,
    DateTime? timestamp,
    List<String>? contactsNotified,
    String? nearestHospital,
    String? nearestPoliceStation,
    String? status,
  }) {
    return SosEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      emergencyType: emergencyType ?? this.emergencyType,
      timestamp: timestamp ?? this.timestamp,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      nearestHospital: nearestHospital ?? this.nearestHospital,
      nearestPoliceStation: nearestPoliceStation ?? this.nearestPoliceStation,
      status: status ?? this.status,
    );
  }

  // ── Helper ───────────────────────────────────────────────────────────

  static List<String> _splitCsv(dynamic value) {
    if (value == null || value == '') return [];
    if (value is List) return value.cast<String>();
    return (value as String).split(',').map((e) => e.trim()).toList();
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        latitude,
        longitude,
        address,
        emergencyType,
        timestamp,
        contactsNotified,
        nearestHospital,
        nearestPoliceStation,
        status,
      ];
}
