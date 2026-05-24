import 'package:equatable/equatable.dart';

/// A self-contained SOS broadcast packet designed for peer-to-peer
/// mesh networking via Nearby Connections.
///
/// Each packet carries enough context for *any* receiving device to
/// forward the alert or notify emergency services — even without
/// internet connectivity.
class SOSPacket extends Equatable {
  /// Unique identifier for this packet (UUID v4).
  final String uuid;

  /// Latitude of the sender at the time the SOS was triggered.
  final double senderLat;

  /// Longitude of the sender at the time the SOS was triggered.
  final double senderLng;

  /// UTC epoch milliseconds when the SOS was originally triggered.
  final int timestamp;

  /// Human-readable name of the victim (for display on receiving devices).
  final String victimName;

  /// A lightweight snapshot of the victim's [MedicalProfile] so that
  /// first-responders can see critical health data immediately.
  final Map<String, dynamic> medicalProfileSnapshot;

  /// Number of hops this packet has taken through the mesh.
  /// Incremented each time a relay device re-broadcasts.
  final int hopCount;

  /// Device IDs that have already received / forwarded this packet,
  /// used to prevent infinite re-broadcasts.
  final List<String> receivedByDevices;

  /// Whether the emergency has been marked as resolved.
  final bool resolved;

  const SOSPacket({
    required this.uuid,
    required this.senderLat,
    required this.senderLng,
    required this.timestamp,
    required this.victimName,
    this.medicalProfileSnapshot = const {},
    this.hopCount = 0,
    this.receivedByDevices = const [],
    this.resolved = false,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates an [SOSPacket] from a JSON map received over the mesh
  /// network or loaded from local storage.
  factory SOSPacket.fromMap(Map<String, dynamic> map) {
    return SOSPacket(
      uuid: map['uuid'] as String,
      senderLat: (map['senderLat'] as num).toDouble(),
      senderLng: (map['senderLng'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
      victimName: map['victimName'] as String? ?? '',
      medicalProfileSnapshot:
          (map['medicalProfileSnapshot'] as Map<String, dynamic>?) ?? const {},
      hopCount: map['hopCount'] as int? ?? 0,
      receivedByDevices: (map['receivedByDevices'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      resolved: map['resolved'] == true || map['resolved'] == 1,
    );
  }

  /// Converts this packet to a JSON-serialisable map for transmission
  /// over the mesh network.
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'senderLat': senderLat,
      'senderLng': senderLng,
      'timestamp': timestamp,
      'victimName': victimName,
      'medicalProfileSnapshot': medicalProfileSnapshot,
      'hopCount': hopCount,
      'receivedByDevices': receivedByDevices,
      'resolved': resolved,
    };
  }

  /// Returns a new packet with [hopCount] incremented and this device
  /// added to [receivedByDevices].
  SOSPacket relay(String thisDeviceId) {
    return SOSPacket(
      uuid: uuid,
      senderLat: senderLat,
      senderLng: senderLng,
      timestamp: timestamp,
      victimName: victimName,
      medicalProfileSnapshot: medicalProfileSnapshot,
      hopCount: hopCount + 1,
      receivedByDevices: [...receivedByDevices, thisDeviceId],
      resolved: resolved,
    );
  }

  @override
  List<Object?> get props => [uuid];
}
