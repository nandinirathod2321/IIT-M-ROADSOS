import '../database/database_helper.dart';
import '../models/emergency_contact.dart';

class EmergencyContactRepository {
  final DatabaseHelper _db;

  EmergencyContactRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieves all emergency contacts from local SQLite or SharedPreferences caches.
  Future<List<EmergencyContact>> getContacts() async {
    return await _db.getEmergencyContacts();
  }

  /// Adds or updates an emergency contact, assuring primary contact constraints.
  Future<void> saveContact(EmergencyContact contact) async {
    await _db.upsertEmergencyContact(contact);
  }

  /// Deletes an emergency contact by [id].
  Future<void> deleteContact(String id) async {
    await _db.deleteEmergencyContact(id);
  }
}
