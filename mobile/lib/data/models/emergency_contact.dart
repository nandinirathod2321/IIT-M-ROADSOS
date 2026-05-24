import 'package:equatable/equatable.dart';

/// A user-defined emergency contact that will be notified during
/// an SOS event.
class EmergencyContact extends Equatable {
  final String id;
  final String name;
  final String relationship;
  final String phone;

  /// Whether this is the default / primary emergency contact.
  final bool isPrimary;

  /// Single emoji used as a lightweight avatar, e.g. "👩" or "🧑‍⚕️".
  final String avatarEmoji;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.isPrimary = false,
    this.avatarEmoji = '👤',
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates an [EmergencyContact] from a database row / JSON map.
  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      name: map['name'] as String,
      relationship: map['relationship'] as String? ?? '',
      phone: map['phone'] as String,
      isPrimary: (map['isPrimary'] as int? ?? 0) == 1,
      avatarEmoji: map['avatarEmoji'] as String? ?? '👤',
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'isPrimary': isPrimary ? 1 : 0,
      'avatarEmoji': avatarEmoji,
    };
  }

  @override
  List<Object?> get props => [id];
}
