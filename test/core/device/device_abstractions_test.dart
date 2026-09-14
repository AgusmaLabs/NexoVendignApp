import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/barcode_scanner.dart';
import 'package:vendingapp/core/device/connectivity_service.dart';
import 'package:vendingapp/core/device/location_service.dart';

void main() {
  group('FakeConnectivityService', () {
    test('reports configured status', () async {
      final service = FakeConnectivityService(ConnectivityStatus.online);
      expect(await service.currentStatus(), ConnectivityStatus.online);

      service.status = ConnectivityStatus.offline;
      expect(await service.currentStatus(), ConnectivityStatus.offline);
    });
  });

  group('FakeLocationService', () {
    test('returns configured location', () async {
      const expected = DeviceLocation(
        latitude: -34.6,
        longitude: -58.4,
        accuracyMeters: 5,
      );
      final service = FakeLocationService(expected);
      final location = await service.getCurrentLocation();
      expect(location.latitude, expected.latitude);
      expect(location.longitude, expected.longitude);
      expect(location.accuracyMeters, expected.accuracyMeters);
    });
  });

  group('FakeBarcodeScanner', () {
    test('returns configured scan value', () async {
      final scanner = FakeBarcodeScanner('1234567890');
      expect(await scanner.scan(), '1234567890');
    });

    test('supports cancellation as null', () async {
      final scanner = FakeBarcodeScanner(null);
      expect(await scanner.scan(), isNull);
    });
  });
}

final class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService(this.status);

  ConnectivityStatus status;

  @override
  Future<ConnectivityStatus> currentStatus() async => status;
}

final class FakeLocationService implements LocationService {
  FakeLocationService(this.location);

  final DeviceLocation location;

  @override
  Future<DeviceLocation> getCurrentLocation() async => location;
}

final class FakeBarcodeScanner implements BarcodeScanner {
  FakeBarcodeScanner(this.value);

  final String? value;

  @override
  Future<String?> scan() async => value;
}
