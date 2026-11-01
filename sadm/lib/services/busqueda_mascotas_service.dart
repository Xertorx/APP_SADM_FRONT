import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/filtros_mascota.dart';
import '../models/mascota_detalle.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HU08-HU09: búsqueda por nombre y filtros (`GET /api/mascotas/buscar` y `/razas`).
class BusquedaMascotasService {
  BusquedaMascotasService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Mascotas DISPONIBLES que cumplen el nombre (opcional) y los filtros, todo en una petición.
  Future<List<MascotaDetalle>> buscar({
    String? nombre,
    FiltrosMascota filtros = FiltrosMascota.vacio,
  }) async {
    final lista = await _get('/mascotas/buscar', filtros.toQueryParameters(nombre: nombre));
    return lista
        .cast<Map<String, dynamic>>()
        .map((json) => MascotaDetalle.fromJson({'estado': 'DISPONIBLE', ...json}))
        .toList();
  }

  /// Razas de las mascotas disponibles de una especie (`PERRO`, `GATO`, `OTRO`).
  Future<List<String>> razas(String especie) async {
    final lista = await _get('/mascotas/razas', {
      'especie': [especie],
    });
    return lista.whereType<String>().toList();
  }

  Future<List<dynamic>> _get(String path, Map<String, List<String>> query) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path').replace(
      // Uri codifica cada valor (tildes, ñ) y repite la clave por cada elemento de la lista.
      queryParameters: query.isEmpty ? null : query,
    );

    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: AuthSession.headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200) {
      try {
        var decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) decoded = decoded['data'] ?? [];
        return decoded as List;
      } catch (_) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }

    final message = _extractMessage(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 400:
        throw ValidationException(message ?? 'La búsqueda no es válida.');
      case 401:
        throw NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      default:
        throw ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  String? _extractMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['message'] ?? decoded['error'] ?? decoded['mensaje'];
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {
      // Body wasn't JSON.
    }
    return null;
  }

  void dispose() => _client.close();
}
