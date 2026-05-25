import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a user profile merged with medical identification details
/// corresponding to the production-grade `users` SQLite table.
class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String profilePhoto;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> medications;
  final List<String> medicalConditions;
  final String emergencyNotes;
  final bool organDonor;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePhoto = '',
    this.bloodGroup = '',
    this.allergies = const [],
    this.medications = const [],
    this.medicalConditions = const [],
    this.emergencyNotes = '',
    this.organDonor = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String? ?? 'me',
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      profilePhoto: map['profile_photo'] as String? ?? '',
      bloodGroup: map['blood_group'] as String? ?? '',
      allergies: _splitCsv(map['allergies']),
      medications: _splitCsv(map['medications']),
      medicalConditions: _splitCsv(map['medical_conditions']),
      emergencyNotes: map['emergency_notes'] as String? ?? '',
      organDonor: (map['organ_donor'] as int? ?? 0) == 1 || map['organ_donor'] == true,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'profile_photo': profilePhoto,
      'blood_group': bloodGroup,
      'allergies': allergies.join(','),
      'medications': medications.join(','),
      'medical_conditions': medicalConditions.join(','),
      'emergency_notes': emergencyNotes,
      'organ_donor': organDonor ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) => User.fromMap(json.decode(source) as Map<String, dynamic>);

  // ── Copy With ────────────────────────────────────────────────────────

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? profilePhoto,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? medications,
    List<String>? medicalConditions,
    String? emergencyNotes,
    bool? organDonor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyNotes: emergencyNotes ?? this.emergencyNotes,
      organDonor: organDonor ?? this.organDonor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        fullName,
        email,
        phone,
        profilePhoto,
        bloodGroup,
        allergies,
        medications,
        medicalConditions,
        emergencyNotes,
        organDonor,
        createdAt,
        updatedAt,
      ];
}
