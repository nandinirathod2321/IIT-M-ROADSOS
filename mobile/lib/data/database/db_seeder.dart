import 'database_helper.dart';

/// Seeds the database with sample data for development and testing.
///
/// In production, call [DatabaseHelper.seedFromJson] with a bundled
/// JSON asset instead. This class provides a quick programmatic
/// alternative.
class DbSeeder {
  const DbSeeder();

  /// Seeds all tables from the bundled JSON asset at [assetPath].
  ///
  /// Defaults to `assets/data/seed_data.json`.
  Future<void> seed({
    String assetPath = 'assets/data/seed_data.json',
  }) async {
    // Note: seedFromJson was deprecated/removed in favor of native SQLite 
    // initialization and seeding within DatabaseHelper's lifecycle.
    // await _dbHelper.seedFromJson(assetPath);
  }
}
