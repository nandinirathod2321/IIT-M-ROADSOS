import 'package:equatable/equatable.dart';

/// A user-defined emergency contact that will be notified during
/// an SOS event.
class EmergencyContact extends Equatable {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;

  /// Whether this is the default / primary emergency contact.
  final bool isPrimary;

  /// Single emoji used as a lightweight avatar, e.g. "👩" or "🧑‍⚕️".
  final String avatarEmoji;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.email = '',
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
      email: map['email'] as String? ?? '',
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
      'email': email,
      'isPrimary': isPrimary ? 1 : 0,
      'avatarEmoji': avatarEmoji,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? isPrimary,
    String? avatarEmoji,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    );
  }

  @override
  List<Object?> get props => [id, name, relationship, phone, email, isPrimary, avatarEmoji];
}
