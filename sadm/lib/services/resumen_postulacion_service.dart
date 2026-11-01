import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Lee el estado de la postulación del usuario a una mascota (HU11, caso B).
///
/// Usa el mismo endpoint de HU13 (`GET /api/postulaciones/mascotas/{id}/resumen`), que responde 200
/// siempre: `data.estado` solo viene si el usuario ya se postuló. Es un servicio propio para no
/// modificar `postulacion_service.dart` (HU13), que descarta el cuerpo de esa respuesta.
class ResumenPostulacionService {
  ResumenPostulacionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Estado en código backend (ej. `ETAPA_1_EN_CURSO`), o `null` si el usuario no se ha postulado.
  Future<String?> estadoPostulacion(int mascotaId) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/postulaciones/mascotas/$mascotaId/resumen'),
            headers: AuthSession.headers,
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }

    switch (response.statusCode) {
      case 200:
        return _estado(response);
      case 404:
        return null;
      case 401:
        throw const NoAutenticadoException();
      case 403:
        throw const SinPermisosException();
      default:
        throw ServerException('Ocurrió un error inesperado (código ${response.statusCode}).');
    }
  }

  String? _estado(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final data = decoded['data'];
      final cuerpo = data is Map<String, dynamic> ? data : decoded;
      final estado = cuerpo['estado'];
      return estado is String && estado.isNotEmpty ? estado : null;
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  void dispose() => _client.close();
}
