import 'package:equatable/equatable.dart';

/// The user's medical profile, shared via QR code or included in
/// SOS packets so first-responders have immediate access to critical
/// health information.
class MedicalProfile extends Equatable {
  final String userId;
  final String fullName;
  final int age;
  final String gender;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final String emergencyContactId;
  final String insuranceProvider;
  final String insurancePolicyNo;
  final bool organDonor;

  const MedicalProfile({
    required this.userId,
    required this.fullName,
    this.age = 0,
    this.gender = '',
    this.bloodGroup = '',
    this.allergies = const [],
    this.medications = const [],
    this.conditions = const [],
    this.emergencyContactId = '',
    this.insuranceProvider = '',
    this.insurancePolicyNo = '',
    this.organDonor = false,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates a [MedicalProfile] from a database row / JSON map.
  factory MedicalProfile.fromMap(Map<String, dynamic> map) {
    return MedicalProfile(
      userId: map['userId'] as String,
      fullName: map['fullName'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      gender: map['gender'] as String? ?? '',
      bloodGroup: map['bloodGroup'] as String? ?? '',
      allergies: _splitCsv(map['allergies']),
      medications: _splitCsv(map['medications']),
      conditions: _splitCsv(map['conditions']),
      emergencyContactId: map['emergencyContactId'] as String? ?? '',
      insuranceProvider: map['insuranceProvider'] as String? ?? '',
      insurancePolicyNo: map['insurancePolicyNo'] as String? ?? '',
      organDonor: (map['organDonor'] as int? ?? 0) == 1,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'allergies': allergies.join(','),
      'medications': medications.join(','),
      'conditions': conditions.join(','),
      'emergencyContactId': emergencyContactId,
      'insuranceProvider': insuranceProvider,
      'insurancePolicyNo': insurancePolicyNo,
      'organDonor': organDonor ? 1 : 0,
    };
  }

  /// Produces a lightweight JSON-like map used as a snapshot inside
  /// [SOSPacket]. Excludes internal IDs.
  Map<String, dynamic> toSnapshot() {
    return {
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medications': medications,
      'conditions': conditions,
      'organDonor': organDonor,
    };
  }

  /// Helper to split a comma-separated string (or null) into a list.
  static List<String> _splitCsv(dynamic value) {
    if (value == null || value == '') return [];
    if (value is List) return value.cast<String>();
    return (value as String).split(',').map((e) => e.trim()).toList();
  }

  @override
  List<Object?> get props => [
        userId,
        fullName,
        age,
        gender,
        bloodGroup,
        allergies,
        medications,
        conditions,
        emergencyContactId,
        insuranceProvider,
        insurancePolicyNo,
        organDonor,
      ];
}
