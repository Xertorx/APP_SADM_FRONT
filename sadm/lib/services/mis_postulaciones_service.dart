import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/mis_postulaciones_textos.dart';
import '../models/mi_postulacion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP de "Mis postulaciones" (HU21).
class MisPostulacionesService {
  MisPostulacionesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// `GET /api/postulaciones/mias` → lista (puede venir vacía).
  Future<List<MiPostulacion>> listar() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/postulaciones/mias'),
            headers: AuthSession.headers,
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }

    switch (response.statusCode) {
      case 200:
        return _parse(response);
      case 401:
        throw const NoAutenticadoException();
      case 403:
        throw const SinPermisosException();
      default:
        throw const ServerException(MisPostulacionesTextos.errorGenerico);
    }
  }

  List<MiPostulacion> _parse(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded['data'] : decoded;
      if (data is! List) throw const FormatException('data no es una lista');
      return data
          .whereType<Map<String, dynamic>>()
          .map(MiPostulacion.fromJson)
          .toList(growable: false);
    } catch (_) {
      throw const ServerException(MisPostulacionesTextos.errorRespuesta);
    }
  }

  void dispose() => _client.close();
}
