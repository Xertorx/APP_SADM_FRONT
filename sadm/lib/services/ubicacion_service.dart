import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ubicacion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HU10: ubicación de referencia del perfil (`/api/perfil/ubicacion`) y catálogo de localidades
/// (`/api/ubicaciones/localidades`).
class UbicacionService {
  UbicacionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Ubicación guardada del usuario del token; null si todavía no registró ninguna (404).
  Future<Ubicacion?> obtener() async {
    final response = await _enviar(
      () => _client.get(_uri('/perfil/ubicacion'), headers: AuthSession.headers),
      devolver404: true,
    );
    if (response.statusCode == 404) return null;
    final data = _datos(response);
    return Ubicacion.fromJson(data as Map<String, dynamic>);
  }

  /// Crea o actualiza la ubicación de referencia (el backend la redondea a 3 decimales).
  Future<Ubicacion> guardar(Ubicacion ubicacion) async {
    final response = await _enviar(
      () => _client.put(
        _uri('/perfil/ubicacion'),
        headers: {...AuthSession.headers, 'Content-Type': 'application/json'},
        body: jsonEncode(ubicacion.toJson()),
      ),
    );
    return Ubicacion.fromJson(_datos(response) as Map<String, dynamic>);
  }

  Future<List<Localidad>> localidades() async {
    final response = await _enviar(
      () => _client.get(_uri('/ubicaciones/localidades'), headers: AuthSession.headers),
    );
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final lista = decoded is Map<String, dynamic> ? (decoded['data'] ?? []) : decoded;
      return (lista as List).cast<Map<String, dynamic>>().map(Localidad.fromJson).toList();
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  /// Envía la petición con timeout de 15 s y traduce el estado HTTP a una [ApiException].
  /// Con [devolver404] el 404 se devuelve tal cual (obtener() lo interpreta como «sin ubicación»).
  Future<http.Response> _enviar(
    Future<http.Response> Function() peticion, {
    bool devolver404 = false,
  }) async {
    late final http.Response response;
    try {
      response = await peticion().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return response;
    if (devolver404 && response.statusCode == 404) return response;

    final message = _extraerMensaje(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 400:
        throw ValidationException(message ?? 'La ubicación no es válida.');
      case 401:
        throw NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        throw SinPermisosException(message ?? 'No tienes permisos para esta acción.');
      case 404:
        throw NotFoundException(message ?? 'No se encontró el recurso.');
      default:
        throw ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  Object? _datos(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded['data'] : decoded;
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  /// Prefiere el primer mensaje de campo de un 400 de validación (`data: {latitud: "..."}`).
  String? _extraerMensaje(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map && data.values.isNotEmpty && data.values.first is String) {
          return data.values.first as String;
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
