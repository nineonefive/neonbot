import 'dart:collection';

/// Cache that exhibits optionally both LRU eviction and/or time-to-live expiration
///
/// Retrieves missed keys from a [retrieve] function and stores the value.
class Cache<K, V> {
  final Duration? ttl;
  final int? maxSize;
  final Future<V?> Function(K) retrieve;
  final Future<void> Function(K, V)? onEvict;
  final LinkedHashMap<K, (V, DateTime)> _cache = LinkedHashMap();

  /// Creates a new cache
  ///
  /// [ttl] is the time-to-live of entries in the cache
  /// [retrieve] is the function called on a cache miss
  /// [maxSize] is the maximum size of the cache
  /// [onEvict] is the function called when an item is evicted
  Cache({this.ttl, required this.retrieve, this.maxSize, this.onEvict});

  /// Returns the value associated with key [key], if any.
  ///
  /// If this incurs a cache miss (either because [key] is not present or is expired),
  /// the [retrieve] function will be called to get the value.
  Future<V?> get(K key) async {
    if (_cache.containsKey(key)) {
      var (value, creationTime) = _cache[key]!;

      if (ttl == null || DateTime.now().difference(creationTime) < ttl!) {
        _moveToFront(key);
        return value;
      }

      // Delete expired entry
      _cache.remove(key);
    }

    // At this point our entry either doesn't exist or is expired, so we
    // need to refresh it
    var value = await retrieve(key);
    if (value == null) return null;

    // We got the value, so add to cache and return, possibly evicting the oldest item
    if (atCapacity) {
      var evictedKey = _cache.keys.first;
      var (otherValue, _) = _cache.remove(evictedKey)!;
      if (onEvict != null) await onEvict!(evictedKey, otherValue);
    }

    _cache[key] = (value, DateTime.now());
    return value;
  }

  /// Tests if the cache is full (and therefore the next new item will cause an eviction)
  bool get atCapacity => maxSize != null && _cache.length >= maxSize!;

  /// Clears the cache, calling [onEvict] for each item if [evict] is true
  void clear({bool evict = true}) async {
    if (evict) {
      if (onEvict == null) throw StateError("No eviction function provided");

      for (var entry in _cache.entries) {
        await onEvict!(entry.key, entry.value.$1);
      }
    }

    _cache.clear();
  }

  /// Deletes a key from the cache, calling [onEvict] if [evict] is true
  Future<V?> remove(K key, {bool evict = true}) async {
    var value = _cache.remove(key);
    if (value == null) return null;

    if (evict) {
      if (onEvict == null) throw StateError("No eviction function provided");

      await onEvict!(key, value.$1);
    }

    return value.$1;
  }

  /// Tests if a key has not expired. Will error if the key is not in the cache
  bool isKeyValid(K key) =>
      (ttl == null) ? true : ttl! > DateTime.now().difference(_cache[key]!.$2);

  /// Tests if the key is in the cache and is still valid
  bool containsKey(K key) => _cache.containsKey(key) && isKeyValid(key);

  /// Returns the entries of the cache that are still valid
  Iterable<MapEntry<K, V>> get entries => _cache.entries
      .where((e) => isKeyValid(e.key))
      .map((e) => MapEntry(e.key, e.value.$1));

  void _moveToFront(K key) {
    var data = _cache.remove(key)!;
    _cache[key] = data;
  }
}
