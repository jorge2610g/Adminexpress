import 'package:flutter/foundation.dart';

enum AdminEnvironment {
  production,
  preview;

  String get channel => switch (this) {
        AdminEnvironment.production => 'production',
        AdminEnvironment.preview => 'preview',
      };

  String get label => switch (this) {
        AdminEnvironment.production => 'Producción',
        AdminEnvironment.preview => 'Prueba',
      };

  static AdminEnvironment parse(String value) =>
      value == 'production' ? production : preview;
}

/// Immutable identity for one AdminExpress data workspace.
///
/// Every page below the admin shell must be rebuilt when any of these values
/// change, so no Future, realtime subscription or cached StatefulWidget from
/// one environment can survive into the other.
@immutable
class AdminRuntimeScope {
  final AdminEnvironment environment;
  final String? countryCode;
  final String? zoneId;

  const AdminRuntimeScope({
    required this.environment,
    this.countryCode,
    this.zoneId,
  });

  String get channel => environment.channel;

  String get cacheKey => <String>[
        environment.channel,
        countryCode ?? 'no-country',
        zoneId ?? 'no-zone',
      ].join(':');

  bool get isPreview => environment == AdminEnvironment.preview;
  bool get isProduction => environment == AdminEnvironment.production;

  AdminRuntimeScope copyWith({
    AdminEnvironment? environment,
    String? countryCode,
    String? zoneId,
    bool clearCountry = false,
    bool clearZone = false,
  }) {
    return AdminRuntimeScope(
      environment: environment ?? this.environment,
      countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
      zoneId: clearZone ? null : (zoneId ?? this.zoneId),
    );
  }
}
