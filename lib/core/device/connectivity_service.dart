/// Coarse network reachability as seen by the application.
enum ConnectivityStatus { online, offline, unknown }

/// Abstraction over device connectivity checks.
abstract interface class ConnectivityService {
  Future<ConnectivityStatus> currentStatus();
}

/// Placeholder connectivity service until a platform implementation lands.
final class UnsupportedConnectivityService implements ConnectivityService {
  const UnsupportedConnectivityService();

  @override
  Future<ConnectivityStatus> currentStatus() async =>
      ConnectivityStatus.unknown;
}
