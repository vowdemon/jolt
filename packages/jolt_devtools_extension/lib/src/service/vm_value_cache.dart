import 'package:jolt_devtools_extension/src/models/vm_node.dart';

/// LRU cache for VM value trees.
/// Caches the most recently used VM value trees, with a maximum capacity.
class VmValueCache {
  final int maxSize;
  final Map<int, VmValueNode> _cache = {};
  final List<int> _accessOrder = [];

  VmValueCache({this.maxSize = 10});

  /// Gets a cached VM value tree by node ID.
  /// Returns null if not found in cache.
  VmValueNode? get(int nodeId) {
    if (!_cache.containsKey(nodeId)) {
      return null;
    }

    // Move to end (most recently used)
    _accessOrder.remove(nodeId);
    _accessOrder.add(nodeId);

    return _cache[nodeId];
  }

  /// Puts a VM value tree into the cache.
  void put(int nodeId, VmValueNode value) {
    if (_cache.containsKey(nodeId)) {
      // Update existing entry
      _cache[nodeId] = value;
      _accessOrder.remove(nodeId);
      _accessOrder.add(nodeId);
      return;
    }

    // Add new entry
    if (_cache.length >= maxSize) {
      // Remove least recently used
      final lru = _accessOrder.removeAt(0);
      _cache.remove(lru);
    }

    _cache[nodeId] = value;
    _accessOrder.add(nodeId);
  }

  /// Removes a VM value tree from the cache.
  void remove(int nodeId) {
    _cache.remove(nodeId);
    _accessOrder.remove(nodeId);
  }

  /// Clears all cached entries.
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Gets the current size of the cache.
  int get size => _cache.length;
}
