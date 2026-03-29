import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache entry with metadata for expiration and priority
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final DateTime expiresAt;
  final int priority;
  final String key;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiresAt,
    required this.priority,
    required this.key,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'priority': priority,
    'key': key,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json, T data) => CacheEntry(
    data: data,
    timestamp: DateTime.parse(json['timestamp']),
    expiresAt: DateTime.parse(json['expiresAt']),
    priority: json['priority'],
    key: json['key'],
  );
}

/// Advanced cache manager with LRU eviction, expiration, and persistence
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Memory cache with LRU ordering
  final Map<String, CacheEntry> _memoryCache = {};
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();

  // Cache configuration
  static const int maxMemoryEntries = 500;
  static const int maxMemorySizeBytes = 50 * 1024 * 1024; // 50MB
  static const Duration defaultExpiration = Duration(hours: 1);
  static const Duration maxExpiration = Duration(days: 7);

  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _currentSizeBytes = 0;

  SharedPreferences? _prefs;
  Timer? _cleanupTimer;
  bool _initialized = false;

  /// Initialize the cache manager
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistedCache();
      _startCleanupTimer();
      _initialized = true;

      if (kDebugMode) {
        debugPrint('[CacheManager] Initialized with ${_memoryCache.length} cached entries');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to initialize: $e');
      }
    }
  }

  /// Store data in cache with optional expiration and priority
  Future<void> set<T>(
    String key,
    T data, {
    Duration? expiration,
    int priority = 5, // 1=highest, 10=lowest
    bool persistToDisk = true,
  }) async {
    expiration ??= defaultExpiration;

    final entry = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(expiration),
      priority: priority.clamp(1, 10),
      key: key,
    );

    // Update access order for LRU
    _accessOrder[key] = DateTime.now();
    _memoryCache[key] = entry;

    // Update size tracking (rough estimate)
    final estimatedSize = _estimateSize(data);
    _currentSizeBytes += estimatedSize;

    // Evict if necessary
    await _evictIfNeeded();

    // Persist to disk if enabled
    if (persistToDisk && _prefs != null) {
      try {
        await _persistEntry(key, entry);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CacheManager] Failed to persist $key: $e');
        }
      }
    }
  }

  /// Get data from cache
  T? get<T>(String key) {
    // Check memory cache first
    final entry = _memoryCache[key];
    if (entry != null) {
      if (entry.isExpired) {
        remove(key);
        _misses++;
        return null;
      }

      // Update access order for LRU
      _accessOrder[key] = DateTime.now();
      _hits++;
      return entry.data as T?;
    }

    _misses++;
    return null;
  }

  /// Get data with fallback to async loader
  Future<T?> getOrLoad<T>(
    String key,
    Future<T?> Function() loader, {
    Duration? expiration,
    int priority = 5,
    bool persistToDisk = true,
  }) async {
    // Try cache first
    T? cached = get<T>(key);
    if (cached != null) return cached;

    // Load from source
    try {
      final data = await loader();
      if (data != null) {
        await set(key, data,
          expiration: expiration,
          priority: priority,
          persistToDisk: persistToDisk,
        );
      }
      return data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to load $key: $e');
      }
      return null;
    }
  }

  /// Remove entry from cache
  void remove(String key) {
    final entry = _memoryCache.remove(key);
    if (entry != null) {
      _accessOrder.remove(key);
      _currentSizeBytes -= _estimateSize(entry.data);
    }

    // Remove from persistent storage
    _prefs?.remove('cache_$key');
  }

  /// Clear all cache entries
  Future<void> clear() async {
    _memoryCache.clear();
    _accessOrder.clear();
    _currentSizeBytes = 0;
    _hits = 0;
    _misses = 0;
    _evictions = 0;

    // Clear persistent storage
    try {
      final keys = _prefs?.getKeys() ?? <String>{};
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await _prefs?.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to clear persistent cache: $e');
      }
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final total = _hits + _misses;
    return {
      'hits': _hits,
      'misses': _misses,
      'hitRate': total > 0 ? _hits / total : 0.0,
      'evictions': _evictions,
      'entries': _memoryCache.length,
      'sizeBytes': _currentSizeBytes,
      'maxSizeBytes': maxMemorySizeBytes,
    };
  }

  /// Check if key exists and is not expired
  bool contains(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      remove(key);
      return false;
    }

    return true;
  }

  /// Preload multiple keys in batch
  Future<void> preload<T>(
    Map<String, Future<T?> Function()> loaders, {
    Duration? expiration,
    int priority = 5,
  }) async {
    final futures = loaders.entries.map((entry) async {
      try {
        final data = await entry.value();
        if (data != null) {
          await set(entry.key, data,
            expiration: expiration,
            priority: priority,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CacheManager] Failed to preload ${entry.key}: $e');
        }
      }
    });

    await Future.wait(futures);
  }

  /// Evict entries using LRU + priority + size strategy
  Future<void> _evictIfNeeded() async {
    // Check if we need to evict based on size or count
    while (_memoryCache.length > maxMemoryEntries ||
           _currentSizeBytes > maxMemorySizeBytes) {

      if (_memoryCache.isEmpty) break;

      // Find entry to evict (oldest access + lowest priority)
      String? keyToEvict;
      DateTime oldestAccess = DateTime.now();
      int lowestPriority = 1;

      for (final entry in _accessOrder.entries) {
        final cacheEntry = _memoryCache[entry.key];
        if (cacheEntry == null) continue;

        // Prioritize eviction: expired > low priority > old access
        if (cacheEntry.isExpired) {
          keyToEvict = entry.key;
          break;
        }

        if (cacheEntry.priority >= lowestPriority &&
            entry.value.isBefore(oldestAccess)) {
          keyToEvict = entry.key;
          oldestAccess = entry.value;
          lowestPriority = cacheEntry.priority;
        }
      }

      if (keyToEvict != null) {
        remove(keyToEvict);
        _evictions++;
      } else {
        break; // Safety break
      }
    }
  }

  /// Estimate memory size of data (rough approximation)
  int _estimateSize(dynamic data) {
    if (data == null) return 0;

    try {
      // Rough estimation based on JSON string length
      final jsonString = jsonEncode(data);
      return jsonString.length * 2; // UTF-16 encoding
    } catch (e) {
      // Fallback for non-serializable data
      return 1024; // 1KB default
    }
  }

  /// Load persisted cache entries on startup
  Future<void> _loadPersistedCache() async {
    if (_prefs == null) return;

    try {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          final cacheKey = key.substring(6); // Remove 'cache_' prefix
          final jsonString = _prefs!.getString(key);

          if (jsonString != null) {
            final json = jsonDecode(jsonString);
            final entry = CacheEntry.fromJson(json, json['data']);

            if (!entry.isExpired) {
              _memoryCache[cacheKey] = entry;
              _accessOrder[cacheKey] = entry.timestamp;
              _currentSizeBytes += _estimateSize(entry.data);
            } else {
              // Remove expired entries
              await _prefs!.remove(key);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to load persisted cache: $e');
      }
    }
  }

  /// Persist cache entry to disk
  Future<void> _persistEntry(String key, CacheEntry entry) async {
    if (_prefs == null) return;

    try {
      final json = entry.toJson();
      final jsonString = jsonEncode(json);
      await _prefs!.setString('cache_$key', jsonString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to persist entry $key: $e');
      }
    }
  }

  /// Start periodic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _cleanupExpiredEntries();
    });
  }

  /// Clean up expired entries
  void _cleanupExpiredEntries() {
    final expiredKeys = <String>[];

    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove(key);
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint('[CacheManager] Cleaned up ${expiredKeys.length} expired entries');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _memoryCache.clear();
    _accessOrder.clear();
    _initialized = false;
  }
}