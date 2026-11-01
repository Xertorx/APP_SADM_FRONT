import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/dador_publico.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP del perfil público del dador (`/api/perfil/publico`). Lanza subclases de [ApiException].
class DadorService {
  DadorService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(int usuarioId, [String sufijo = '']) =>
      Uri.parse('${AppConfig.baseUrl}/perfil/publico/$usuarioId$sufijo');

  /// `GET /api/perfil/publico/{usuarioId}`.
  Future<DadorPublico> obtener(int usuarioId) async {
    final response = await _enviar(() => _client.get(_uri(usuarioId), headers: AuthSession.headers));
    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        return DadorPublico.fromJson(data is Map<String, dynamic> ? data : decoded);
      } catch (_) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }
    throw _error(response);
  }

  /// `GET /api/perfil/publico/{usuarioId}/foto`. Devuelve `null` si no tiene foto (404).
  /// Se descarga con el header `Authorization`, por eso no se usa `Image.network`.
  Future<Uint8List?> descargarFoto(int usuarioId) async {
    final response =
        await _enviar(() => _client.get(_uri(usuarioId, '/foto'), headers: AuthSession.headers));
    if (response.statusCode == 200) return response.bodyBytes;
    if (response.statusCode == 404) return null;
    throw _error(response);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  ApiException _error(http.Response response) {
    final message = _extraerMensaje(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 401:
        return NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        return SinPermisosException(message ?? 'No tienes permisos para ver este perfil.');
      case 404:
        return NotFoundException(message ?? 'El usuario no existe.');
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  String? _extraerMensaje(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['message'] ?? decoded['error'] ?? decoded['mensaje'];
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {
      // El cuerpo no era JSON.
    }
    return null;
  }

  void dispose() => _client.close();
}
