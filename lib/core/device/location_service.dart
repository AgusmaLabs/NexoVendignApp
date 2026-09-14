/// Geographic coordinates captured on the device.
final class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

/// Abstraction over device location. Real GPS arrives in later commits.
abstract interface class LocationService {
  Future<DeviceLocation> getCurrentLocation();
}

/// Placeholder location service until GPS permissions and providers exist.
final class UnsupportedLocationService implements LocationService {
  const UnsupportedLocationService();

  @override
  Future<DeviceLocation> getCurrentLocation() {
    throw UnsupportedError('LocationService is not implemented yet');
  }
}
