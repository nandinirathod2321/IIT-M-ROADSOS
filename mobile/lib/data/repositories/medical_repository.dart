import '../database/database_helper.dart';
import '../models/medical_profile.dart';

class MedicalRepository {
  final DatabaseHelper _db;

  MedicalRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieves the active user health ID profile.
  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    return await _db.getMedicalProfile(userId);
  }

  /// Updates the medical health ID profile details in the primary database.
  Future<void> saveMedicalProfile(MedicalProfile profile) async {
    await _db.upsertMedicalProfile(profile);
  }
}
