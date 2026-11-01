import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/mascota_eliminacion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP service for deleting a mascota publicación (HU07).
class MascotaEliminacionService {
  MascotaEliminacionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(int id, [String sufijo = '']) =>
      Uri.parse('${AppConfig.baseUrl}/mascotas/$id$sufijo');

  /// `GET /api/mascotas/{id}/eliminacion` — data shown in the confirmation dialog.
  Future<MascotaEliminacion> consultar(int id) async {
    final response = await _enviar(
      () => _client.get(_uri(id, '/eliminacion'), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final data = decoded['data'];
      return MascotaEliminacion.fromJson(data is Map<String, dynamic> ? data : decoded);
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  /// `DELETE /api/mascotas/{id}`. Throws an [ApiException] subtype on failure.
  Future<void> eliminar(int id) async {
    final response = await _enviar(
      () => _client.delete(_uri(id), headers: AuthSession.headers),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw _error(response);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() llamada) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  ApiException _error(http.Response response) {
    final message = _mensaje(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 401:
        return NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        return SinPermisosException(message ?? 'No puedes eliminar esta publicación');
      case 404:
        return NotFoundException(message ?? 'La mascota no existe');
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  String? _mensaje(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['message'] ?? decoded['mensaje'];
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {
      // Body wasn't JSON.
    }
    return null;
  }

  void dispose() => _client.close();
}
