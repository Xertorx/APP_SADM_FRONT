import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/admin_usuarios_textos.dart';
import '../config/app_config.dart';
import '../models/usuario_admin.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP de administración de usuarios (HU27 + HU28). Todos los endpoints son de ADMINISTRADOR.
class AdminUsuariosService {
  AdminUsuariosService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String ruta, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.baseUrl}/admin/usuarios$ruta').replace(queryParameters: query);

  /// `GET /api/admin/usuarios?nombre=` → lista (vacía si no hay coincidencias).
  Future<List<UsuarioAdmin>> buscar(String nombre) async {
    final response = await _enviar(
      () => _client.get(_uri('', {'nombre': nombre.trim()}), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    final data = _data(response);
    if (data is! List) throw const ServerException(AdminUsuariosTextos.errorRespuesta);
    try {
      return data
          .whereType<Map<String, dynamic>>()
          .map(UsuarioAdmin.fromJson)
          .toList(growable: false);
    } catch (_) {
      throw const ServerException(AdminUsuariosTextos.errorRespuesta);
    }
  }

  /// `GET /api/admin/usuarios/{id}`.
  Future<UsuarioAdminDetalle> detalle(int id) async {
    final response = await _enviar(
      () => _client.get(_uri('/$id'), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    return _detalle(response);
  }

  /// `POST /api/admin/usuarios/{id}/inhabilitar` → detalle actualizado.
  Future<UsuarioAdminDetalle> inhabilitar(int id, String motivo) async {
    final response = await _enviar(
      () => _client.post(
        _uri('/$id/inhabilitar'),
        headers: {...AuthSession.headers, 'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'motivo': motivo.trim()}),
      ),
    );
    if (response.statusCode != 200) throw _error(response);
    return _detalle(response);
  }

  /// `POST /api/admin/usuarios/{id}/reactivar` → detalle actualizado.
  Future<UsuarioAdminDetalle> reactivar(int id) async {
    final response = await _enviar(
      () => _client.post(_uri('/$id/reactivar'), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    return _detalle(response);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() llamada) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  Object? _data(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded['data'] : decoded;
    } catch (_) {
      throw const ServerException(AdminUsuariosTextos.errorRespuesta);
    }
  }

  UsuarioAdminDetalle _detalle(http.Response response) {
    final data = _data(response);
    if (data is! Map<String, dynamic>) {
      throw const ServerException(AdminUsuariosTextos.errorRespuesta);
    }
    try {
      return UsuarioAdminDetalle.fromJson(data);
    } catch (_) {
      throw const ServerException(AdminUsuariosTextos.errorRespuesta);
    }
  }

  ApiException _error(http.Response response) {
    final message = _mensaje(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 400:
        return ValidationException(message ?? AdminUsuariosTextos.errorGenerico);
      case 401:
        return NoAutenticadoException(message ?? AdminUsuariosTextos.errorNoAutenticado);
      case 403:
        return SinPermisosException(message ?? AdminUsuariosTextos.errorSinPermisos);
      case 404:
        return NotFoundException(message ?? AdminUsuariosTextos.errorNoExiste);
      case 409:
        // "La cuenta ya está inhabilitada / activa": se muestra tal cual, sin subclase nueva.
        return ValidationException(message ?? AdminUsuariosTextos.errorGenerico);
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  /// Un 400 de @Valid trae `data: {campo: mensaje}`; los de negocio, `message`.
  String? _mensaje(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          final primero = data.values.first;
          if (primero is String && primero.isNotEmpty) return primero;
        }
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
