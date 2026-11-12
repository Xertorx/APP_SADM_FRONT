import 'dart:convert';

/// Minimal holder of the authenticated usuario's session.
///
/// Every usuario can both adopt and give pets up for adoption, so there are
/// no roles: being authenticated is enough. The token can also be injected
/// with `--dart-define=SADM_TOKEN=...` for development.
class AuthSession {
  AuthSession._();

  static const _envToken = String.fromEnvironment('SADM_TOKEN');

  static String? token = _envToken.isEmpty ? null : _envToken;

  /// Id of the logged usuario, when the token carries it.
  static int? usuarioId = token == null ? null : _idDesdeToken(token!);

  static bool get autenticado => token != null;

  /// HU27-HU28: rol del usuario (claim `role` del JWT). Solo sirve para mostrar u ocultar
  /// opciones de administrador; la seguridad real la aplica el backend con @RolesAllowed.
  static String? rol = token == null ? null : _rolDesdeToken(token!);

  static bool get esAdministrador => rol == 'ADMINISTRADOR';

  static Map<String, String> get headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static void iniciar(String accessToken) {
    token = accessToken;
    usuarioId = _idDesdeToken(accessToken);
    rol = _rolDesdeToken(accessToken);
  }

  static void limpiar() {
    token = null;
    usuarioId = null;
    rol = null;
  }

  /// Best-effort read of the usuario id from the JWT payload.
  static int? _idDesdeToken(String jwt) {
    try {
      final partes = jwt.split('.');
      if (partes.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      for (final clave in const ['id', 'userId', 'usuarioId', 'idUsuario', 'sub']) {
        final valor = payload[clave];
        if (valor is int) return valor;
        if (valor is String) {
          final id = int.tryParse(valor);
          if (id != null) return id;
        }
      }
    } catch (_) {
      // Token opaco o malformado: no hay id disponible.
    }
    return null;
  }

  /// HU27-HU28: lectura del claim `role` del payload del JWT (null si no está o el token es opaco).
  static String? _rolDesdeToken(String jwt) {
    try {
      final partes = jwt.split('.');
      if (partes.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      if (payload is Map<String, dynamic> && payload['role'] is String) {
        return payload['role'] as String;
      }
    } catch (_) {
      // Token opaco o malformado: no hay rol disponible.
    }
    return null;
  }
}
