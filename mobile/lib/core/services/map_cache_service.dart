import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

/// Singleton service managing map tile cache storage.
/// Uses a file-based [CacheStore] to persist tiles on disk for offline use.
class MapCacheService {
  MapCacheService._();
  static final MapCacheService instance = MapCacheService._();

  CacheStore? _store;
  bool _initialized = false;

  /// Returns the file-backed [CacheStore] for tile caching.
  /// Initializes the store lazily on first access.
  Future<CacheStore> getCacheStore() async {
    if (_store != null) return _store!;

    try {
      final dir = await getTemporaryDirectory();
      final tileCacheDir = '${dir.path}${Platform.pathSeparator}map_tiles';
      _store = FileCacheStore(tileCacheDir);
      _initialized = true;
      debugPrint('[MapCache] MAP_TILES_CACHE_INITIALIZED at $tileCacheDir');
    } catch (e) {
      debugPrint('[MapCache] File store init failed, using memory store: $e');
      _store = MemCacheStore();
      _initialized = true;
    }

    return _store!;
  }

  /// Whether the cache store has been initialized.
  bool get isInitialized => _initialized;
}
