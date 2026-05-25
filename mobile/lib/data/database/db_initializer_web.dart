/// Web database initializer
class DbInitializer {
  static Future<void> initialize() async {
    // No-op on web
    print("DbInitializer: skipping database setup on web");
  }
}
