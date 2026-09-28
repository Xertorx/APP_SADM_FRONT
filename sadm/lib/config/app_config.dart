import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized configuration for the SADM backend connection.
///
/// [baseUrl] can be overridden at startup (e.g. from `main.dart`) to point to
/// a physical device's server IP. By default it resolves to:
/// - `http://10.0.2.2:8862/SADM` when running on the Android emulator.
/// - `http://localhost:8862/SADM` for iOS simulator / desktop / web.
///
/// For a physical device, set [baseUrl] to `http://<IP_LOCAL_SERVIDOR>:8862/SADM`.
class AppConfig {
  AppConfig._();

  static String baseUrl = _resolveDefaultBaseUrl();

  static String _resolveDefaultBaseUrl() {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8862/SADM';
    }
    return 'http://localhost:8862/SADM';
  }
}

/// Default values used to pre-fill the adoptante registration form.
class AppConstants {
  AppConstants._();

  static const String defaultTipoUsuario = 'ADOPTANTE';
  static const String defaultEstado = 'ACTIVO';
}
