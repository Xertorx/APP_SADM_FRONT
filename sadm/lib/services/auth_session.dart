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

  static Map<String, String> get headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static void iniciar(String accessToken) {
    token = accessToken;
    usuarioId = _idDesdeToken(accessToken);
  }

  static void limpiar() {
    token = null;
    usuarioId = null;
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
}
