class LruCache<K, V> {
  final int capacity;
  final _map = <K, V>{};
  final _order = <K>[];
  LruCache(this.capacity);
  V? get(K k) {
    if (!_map.containsKey(k)) return null;
    _order.remove(k);
    _order.add(k);
    return _map[k];
  }
  void set(K k, V v) {
    if (_map.containsKey(k)) {
      _order.remove(k);
    } else if (_map.length >= capacity) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
    _map[k] = v;
    _order.add(k);
  }
}
