import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents an emergency contact stored in the `emergency_contacts` SQLite table.
class EmergencyContact extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String relationship;
  final String phone;
  final String email;
  final bool isPrimary;
  final DateTime createdAt;
  final String avatarEmoji;

  EmergencyContact({
    required this.id,
    this.userId = 'me',
    required String name,
    required this.relationship,
    required this.phone,
    this.email = '',
    this.isPrimary = false,
    DateTime? createdAt,
    this.avatarEmoji = '👤',
  })  : fullName = name,
        createdAt = createdAt ?? DateTime.now();

  /// Backward compatible getter mapping `name` to `fullName`
  String get name => fullName;

  // ── Serialisation ────────────────────────────────────────────────────

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'me',
      name: (map['full_name'] as String?) ?? (map['name'] as String?) ?? '',
      relationship: map['relationship'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      isPrimary: (map['is_primary'] as int? ?? map['isPrimary'] as int? ?? 0) == 1 || 
                 map['is_primary'] == true || 
                 map['isPrimary'] == true,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      avatarEmoji: map['avatarEmoji'] as String? ?? '👤',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'relationship': relationship,
      'phone': phone,
      'email': email,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(String source) => 
      EmergencyContact.fromMap(json.decode(source) as Map<String, dynamic>);

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? isPrimary,
    DateTime? createdAt,
    String? avatarEmoji,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: fullName ?? name ?? this.fullName,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    );
  }

  @override
  List<Object?> get props => [id, userId, fullName, relationship, phone, email, isPrimary, createdAt, avatarEmoji];
}
