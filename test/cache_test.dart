import 'dart:io';

import 'package:neonbot/src/cache.dart';
import 'package:test/test.dart';

void main() {
  test('Cache entries expire', () async {
    var cacheRetrievals = 0;
    Cache<String, int> cache = Cache(
      ttl: Duration(seconds: 1),
      retrieve: (s) async {
        cacheRetrievals++;
        return s.length;
      },
    );

    // Test retrieving the key initially incurs a cache miss
    expect(await cache.get("test"), 4);
    expect(cache.containsKey("test"), true);
    expect(cacheRetrievals, 1);

    // Now we should be able to retrieve it again with a hit
    expect(await cache.get("test"), 4);
    expect(cache.containsKey("test"), true);
    expect(cacheRetrievals, 1);

    // Now sleep so that the entry expires, incurring another retrieval
    sleep(Duration(seconds: 2));
    expect(cache.containsKey("test"), false);
    expect(await cache.get("test"), 4);
    expect(cache.containsKey("test"), true);
    expect(cacheRetrievals, 2);
  });

  test('Cache entries dont expire by default', () async {
    var cacheRetrievals = 0;
    Cache<String, int> cache = Cache(retrieve: (s) async {
      cacheRetrievals++;
      return s.length;
    });

    // Test retrieving the key initially incurs a cache miss
    expect(await cache.get("test"), 4);
    expect(cache.containsKey("test"), true);
    expect(cacheRetrievals, 1);

    // Now we should be able to retrieve it again with a hit
    expect(await cache.get("test"), 4);
    expect(cacheRetrievals, 1);

    // Now sleep and show it's still valid
    sleep(Duration(seconds: 2));
    expect(cache.containsKey("test"), true);
    expect(await cache.get("test"), 4);
    expect(cache.containsKey("test"), true);
    expect(cacheRetrievals, 1);
  });

  test('Cache entries get evicted', () async {
    List<String> cacheEvictions = [];

    Cache<String, int> cache = Cache(
      retrieve: (s) async => s.length,
      onEvict: (k, v) async => cacheEvictions.add(k),
      maxSize: 3,
    );

    expect(cache.maxSize, 3);
    var strings = ["a", "b", "c", "d", "e"];

    // Fill up the cache to the max, nothing gets evicted
    for (var s in strings.take(cache.maxSize!)) {
      expect(await cache.get(s), 1);
      expect(cacheEvictions, []);
    }

    expect(cache.atCapacity, true);

    // After, all the keys better be in there
    for (var s in strings.take(cache.maxSize!)) {
      expect(cache.containsKey(s), true);
    }

    // Adding an item should get rid of the oldest one
    await cache.get('d');
    expect(cacheEvictions, ['a']);

    expect(cache.containsKey('a'), false);
    expect(cache.containsKey('b'), true);
    expect(cache.containsKey('c'), true);
    expect(cache.containsKey('d'), true);

    await cache.get('e');
    expect(cacheEvictions, ['a', 'b']);
    expect(cache.containsKey('b'), false);
    expect(cache.containsKey('c'), true);
    expect(cache.containsKey('d'), true);
    expect(cache.containsKey('e'), true);
  });

  test('Test LRU ordering of keys', () async {
    List<String> evicted = [];
    Cache<String, int> cache = Cache(
      retrieve: (s) async => s.length,
      onEvict: (k, v) async => evicted.add(k),
      maxSize: 3,
    );

    // Fill the cache
    for (var s in ['a', 'b', 'c']) {
      await cache.get(s);
    }

    // Reorder the cache to [b, a, c]
    await cache.get('a');
    await cache.get('c');

    // b should be evicted first
    await cache.get('d');
    expect(evicted, ['b']);
  });
}
