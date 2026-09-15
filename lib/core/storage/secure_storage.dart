/// Secure key-value storage for credentials and session material.
///
/// Authentication flows are introduced in later commits. This contract exists
/// so features never depend on a concrete platform API.
abstract interface class SecureStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}

/// In-memory [SecureStorage] for tests only.
///
/// Production composition uses [FlutterSecureStorageAdapter].
final class MemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
