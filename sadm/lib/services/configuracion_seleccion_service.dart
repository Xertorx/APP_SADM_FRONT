import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/configuracion_seleccion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP service for the configuración del proceso de selección (HU12).
class ConfiguracionSeleccionService {
  ConfiguracionSeleccionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  static const _mensajesPorCodigo = {
    'ETAPA_SIN_CRITERIOS': 'Todas las etapas deben tener al menos un criterio.',
    'DISTRIBUCION_INVALIDA': 'Los máximos de las cuatro etapas deben sumar exactamente 100 puntos.',
    'PUNTAJE_SUPERA_ETAPA': 'Hay criterios cuyo puntaje supera el máximo de su etapa.',
  };

  Uri _uri(int mascotaId, [String sufijo = '/configuracion-seleccion']) =>
      Uri.parse('${AppConfig.baseUrl}/mascotas/$mascotaId$sufijo');

  Map<String, String> get _headersJson => {
        ...AuthSession.headers,
        'Content-Type': 'application/json',
      };

  /// `GET /api/mascotas/{id}/configuracion-seleccion`. Devuelve una configuración vacía si
  /// la mascota todavía no tiene una guardada.
  Future<ConfiguracionSeleccion> obtener(int mascotaId) async {
    final response = await _enviar(() => _client.get(_uri(mascotaId), headers: _headersJson));
    return _configuracion(response, mascotaId);
  }

  /// `PUT /api/mascotas/{id}/configuracion-seleccion` con las cuatro etapas completas.
  Future<ConfiguracionSeleccion> guardar(ConfiguracionSeleccion config) async {
    final response = await _enviar(
      () => _client.put(
        _uri(config.mascotaId),
        headers: _headersJson,
        body: jsonEncode(config.toJson()),
      ),
    );
    return _configuracion(response, config.mascotaId);
  }

  /// `POST /api/mascotas/{id}/configuracion-seleccion/finalizar`.
  Future<ConfiguracionSeleccion> finalizar(int mascotaId) async {
    final response = await _enviar(
      () => _client.post(_uri(mascotaId, '/configuracion-seleccion/finalizar'),
          headers: _headersJson),
    );
    return _configuracion(response, mascotaId);
  }

  /// `POST /api/mascotas/{id}/publicar`: envía la mascota a revisión. Solo funciona con la
  /// configuración finalizada y la bloquea para edición.
  Future<void> publicar(int mascotaId) async {
    final response = await _enviar(
      () => _client.post(_uri(mascotaId, '/publicar'), headers: _headersJson),
    );
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
      return;
    }
    throw _error(response);
  }

  ConfiguracionSeleccion _configuracion(http.Response response, int mascotaId) {
    if (response.statusCode != 200 && response.statusCode != 201) throw _error(response);
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final data = decoded['data'];
      return ConfiguracionSeleccion.fromJson(
        data is Map<String, dynamic> ? data : decoded,
        mascotaId: mascotaId,
      );
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  Future<http.Response> _enviar(Future<http.Response> Function() llamada) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  ApiException _error(http.Response response) {
    final cuerpo = _decodificar(response.bodyBytes);
    final message = _mensaje(cuerpo);
    switch (response.statusCode) {
      case 400:
        return ValidationException(
          message ?? _mensajesPorCodigo[_codigo(cuerpo)] ?? 'La configuración no es válida.',
        );
      case 401:
        return NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        return SinPermisosException(
          message ?? 'Solo el dador propietario puede configurar esta mascota.',
        );
      case 404:
        return NotFoundException(message ?? 'La mascota no existe.');
      case 409:
        return ConflictoException(
          message ?? 'La configuración no se puede modificar en el estado actual de la mascota.',
        );
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  Object? _decodificar(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  String? _mensaje(Object? cuerpo) {
    if (cuerpo is Map<String, dynamic>) {
      final value = cuerpo['message'] ?? cuerpo['mensaje'] ?? cuerpo['error'];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Código de negocio (`ETAPA_SIN_CRITERIOS`, ...) cuando el backend lo informa.
  String? _codigo(Object? cuerpo) {
    if (cuerpo is! Map<String, dynamic>) return null;
    final data = cuerpo['data'];
    for (final fuente in [cuerpo, if (data is Map<String, dynamic>) data]) {
      for (final clave in const ['codigo', 'code', 'error']) {
        final valor = fuente[clave];
        if (valor is String && _mensajesPorCodigo.containsKey(valor)) return valor;
      }
    }
    return null;
  }

  void dispose() => _client.close();
}
