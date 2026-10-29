import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/postulacion_textos.dart';
import '../models/postulacion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP service for the postulación flow (HU13).
///
/// Every endpoint path and JSON field the backend contract defines lives in
/// this file, so a contract change only touches this layer.
class PostulacionService {
  PostulacionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  /// `GET /api/postulaciones/mascotas/{id}/resumen` — a 200 means the usuario
  /// already has an active postulación for that mascota; a 404 means none.
  Future<bool> tienePostulacionActiva(int mascotaId) async {
    final response = await _send(
      () => _client.get(
        _uri('/postulaciones/mascotas/$mascotaId/resumen'),
        headers: AuthSession.headers,
      ),
    );
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    _lanzarError(response);
  }

  /// `POST /api/postulaciones` with `{ mascotaId }`.
  Future<Postulacion> crear(int mascotaId) async {
    final response = await _send(
      () => _client.post(
        _uri('/postulaciones'),
        headers: {
          ...AuthSession.headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'mascotaId': mascotaId}),
      ),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      _lanzarError(response);
    }
    return _parse(response.body, Postulacion.fromJson);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  T _parse<T>(String body, T Function(Map<String, dynamic>) fromJson) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'];
      return fromJson(data is Map<String, dynamic> ? data : decoded);
    } catch (_) {
      throw const ServerException(PostulacionTextos.errorRespuesta);
    }
  }

  Never _lanzarError(http.Response response) {
    String? codigo;
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawCodigo = decoded['codigo'] ?? decoded['code'] ?? decoded['errorCode'];
        if (rawCodigo is String) codigo = rawCodigo;
        final rawMessage = decoded['message'] ?? decoded['mensaje'];
        if (rawMessage is String && rawMessage.isNotEmpty) message = rawMessage;
      }
    } catch (_) {
      // Non-JSON body: fall back to status code mapping.
    }

    switch (codigo) {
      case 'POSTULACION_DUPLICADA':
        throw const PostulacionDuplicadaException();
      case 'MASCOTA_NO_DISPONIBLE':
        throw const MascotaNoDisponibleException();
    }

    switch (response.statusCode) {
      case 401:
        throw const NoAutenticadoException();
      case 403:
        throw const SinPermisosException();
      case 400:
        throw ValidationException(message ?? PostulacionTextos.errorGenerico);
      case 404:
        throw NotFoundException(message ?? 'La mascota no existe.');
      default:
        throw ServerException(message ?? PostulacionTextos.errorGenerico);
    }
  }

  void dispose() => _client.close();
}
