import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../config/estadisticas_textos.dart';
import '../models/estadisticas.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP del panel de estadísticas (HU30). Endpoints de solo ADMINISTRADOR.
class EstadisticasService {
  EstadisticasService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String ruta, DateTime? desde, DateTime? hasta) {
    final query = <String, String>{
      if (desde != null) 'desde': _fecha(desde),
      if (hasta != null) 'hasta': _fecha(hasta),
    };
    return Uri.parse('${AppConfig.baseUrl}/admin/estadisticas$ruta')
        .replace(queryParameters: query.isEmpty ? null : query);
  }

  static String _fecha(DateTime fecha) => DateFormat('yyyy-MM-dd').format(fecha);

  /// Nombre del archivo descargado, igual al que propone el backend (reporte_estadisticas_yyyyMMdd.csv).
  static String nombreArchivo([DateTime? ahora]) =>
      'reporte_estadisticas_${DateFormat('yyyyMMdd').format(ahora ?? DateTime.now())}.csv';

  /// `GET /api/admin/estadisticas?desde=&hasta=` (ambos opcionales).
  Future<Estadisticas> obtener({DateTime? desde, DateTime? hasta}) async {
    final response = await _enviar(
      () => _client.get(_uri('', desde, hasta), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is! Map<String, dynamic>) {
        throw const ServerException(EstadisticasTextos.errorRespuesta);
      }
      return Estadisticas.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ServerException(EstadisticasTextos.errorRespuesta);
    }
  }

  /// `GET /api/admin/estadisticas/exportar` → bytes del CSV (se pide con el token, no con un enlace).
  Future<Uint8List> exportar({DateTime? desde, DateTime? hasta}) async {
    final response = await _enviar(
      () => _client.get(_uri('/exportar', desde, hasta), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    return response.bodyBytes;
  }

  Future<http.Response> _enviar(Future<http.Response> Function() llamada) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  /// El 403 de Quarkus llega sin cuerpo JSON: se decide por código de estado.
  ApiException _error(http.Response response) {
    final message = _mensaje(utf8.decode(response.bodyBytes, allowMalformed: true));
    switch (response.statusCode) {
      case 400:
        return ValidationException(message ?? EstadisticasTextos.errorGenerico);
      case 401:
        return NoAutenticadoException(message ?? EstadisticasTextos.errorNoAutenticado);
      case 403:
        return SinPermisosException(message ?? EstadisticasTextos.errorSinPermisos);
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
