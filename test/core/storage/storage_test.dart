import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/storage/local_storage.dart';
import 'package:vendingapp/core/storage/secure_storage.dart';

void main() {
  group('MemoryLocalStorage', () {
    late LocalStorage storage;

    setUp(() {
      storage = MemoryLocalStorage();
    });

    test('write/read/remove/clear and key isolation', () async {
      await storage.write('a', '1');
      await storage.write('b', '2');

      expect(await storage.read('a'), '1');
      expect(await storage.read('b'), '2');

      await storage.remove('a');
      expect(await storage.read('a'), isNull);
      expect(await storage.read('b'), '2');

      await storage.clear();
      expect(await storage.read('b'), isNull);
    });
  });

  group('MemorySecureStorage', () {
    late SecureStorage storage;

    setUp(() {
      storage = MemorySecureStorage();
    });

    test('write/read/remove/clear and key isolation', () async {
      await storage.write('access_token', 'token-a');
      await storage.write('session', 'session-b');

      expect(await storage.read('access_token'), 'token-a');
      expect(await storage.read('session'), 'session-b');

      await storage.remove('access_token');
      expect(await storage.read('access_token'), isNull);
      expect(await storage.read('session'), 'session-b');

      await storage.clear();
      expect(await storage.read('session'), isNull);
    });
  });
}
