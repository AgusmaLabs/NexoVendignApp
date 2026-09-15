import '../config/app_config.dart';

/// Google Sign-In configuration supplied outside widgets.
///
/// Client IDs must come from environment/build configuration — never hardcode
/// production credentials into the repository.
final class GoogleSignInConfig {
  const GoogleSignInConfig({this.serverClientId, this.iosClientId});

  /// OAuth web/server client ID used to request an id_token (Android/iOS).
  final String? serverClientId;

  /// iOS OAuth client ID when required by the platform SDK.
  final String? iosClientId;

  /// Loads client IDs from `--dart-define` values for [environment] builds.
  ///
  /// The same define names are used across environments; pipelines supply
  /// environment-specific values at build time.
  factory GoogleSignInConfig.fromEnvironment(AppEnvironment environment) {
    final _ = environment;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    return GoogleSignInConfig(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
      iosClientId: iosClientId.isEmpty ? null : iosClientId,
    );
  }
}
