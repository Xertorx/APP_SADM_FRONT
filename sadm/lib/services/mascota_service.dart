import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/mascota.dart';
import '../models/mascota_detalle.dart';
import '../models/mascota_edicion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP service responsible for talking to the SADM mascotas API.
class MascotaService {
  MascotaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _createUri => Uri.parse('${AppConfig.baseUrl}/mascotas/crear');

  /// Publishes a new mascota with its photos. Returns the created id.
  /// Throws an [ApiException] subtype on failure.
  Future<int> crear(Mascota mascota, List<XFile> fotos) async {
    final request = await _multipart('POST', _createUri, mascota, fotos);
    final response = await _enviar(request);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractId(response.body);
    }

    final message = _extractMessage(response.body);

    switch (response.statusCode) {
      case 400:
        throw ValidationException(
          message ?? 'Los datos ingresados no son válidos.',
        );
      case 401:
        throw NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        throw SinPermisosException(message ?? 'No tienes permisos para publicar mascotas.');
      case 404:
        throw NotFoundException(message ?? 'El usuario dador no existe');
      default:
        throw ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  /// `GET /api/mascotas/{id}/editar` — current data of a mascota to edit.
  Future<MascotaEdicion> obtenerParaEditar(int id) async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/mascotas/$id/editar'),
            headers: AuthSession.headers,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        return MascotaEdicion.fromJson(data is Map<String, dynamic> ? data : decoded, id: id);
      } catch (e) {
        debugPrint('Respuesta de edición no interpretable: $e');
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }

    throw _errorEdicion(response);
  }

  /// `PUT /api/mascotas/{id}` as multipart/form-data: the JSON `datos` part
  /// plus the optional new `fotos`.
  Future<void> actualizar(int id, Mascota mascota, List<XFile> fotos) async {
    final request = await _multipart(
      'PUT',
      Uri.parse('${AppConfig.baseUrl}/mascotas/$id'),
      mascota,
      fotos,
    );
    final response = await _enviar(request);

    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
      return;
    }
    throw _errorEdicion(response);
  }

  ApiException _errorEdicion(http.Response response) {
    final message = _extractMessage(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 400:
        return ValidationException(message ?? 'Los datos ingresados no son válidos.');
      case 401:
        return NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        return SinPermisosException(
          message ?? 'Solo el dador propietario puede editar esta publicación.',
        );
      case 404:
        return NotFoundException(message ?? 'La mascota no existe.');
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  Future<http.MultipartRequest> _multipart(
    String method,
    Uri uri,
    Mascota mascota,
    List<XFile> fotos,
  ) async {
    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(AuthSession.headers)
      ..files.add(
        http.MultipartFile.fromString(
          'datos',
          jsonEncode(mascota.toJson()),
          contentType: MediaType('application', 'json'),
        ),
      );

    for (final foto in fotos) {
      final bytes = await foto.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'fotos',
          bytes,
          filename: foto.name,
          contentType: _resolveMediaType(foto),
        ),
      );
    }
    return request;
  }

  Future<http.Response> _enviar(http.MultipartRequest request) async {
    late final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }
    return http.Response.fromStream(streamed);
  }

  /// `GET /api/mascotas` — every mascota that can be adopted. Accepts a bare
  /// JSON array or one wrapped in `data` (optionally paged under `content`).
  Future<List<MascotaDetalle>> listarDisponibles() => _listar('/mascotas');

  /// `GET /api/mascotas/mis-publicaciones` — mascotas de la persona autenticada.
  Future<List<MascotaDetalle>> listarMias() => _listar('/mascotas/mis-publicaciones');

  Future<List<MascotaDetalle>> _listar(String path) async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}$path'),
            headers: AuthSession.headers,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200) {
      try {
        var decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) decoded = decoded['data'] ?? decoded;
        if (decoded is Map<String, dynamic>) decoded = decoded['content'];
        return (decoded as List)
            .cast<Map<String, dynamic>>()
            .map((json) => MascotaDetalle.fromJson({'estado': 'DISPONIBLE', ...json}))
            .toList();
      } catch (_) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }

    final message = _extractMessage(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
    }
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw NotFoundException(message ?? 'No se encontró el recurso solicitado.');
    }
    if (response.statusCode == 400) {
      throw ValidationException(message ?? 'La solicitud no es válida.');
    }
    throw ServerException(
      message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
    );
  }

  /// `GET /api/mascotas/{id}`. Throws an [ApiException] subtype on failure.
  Future<MascotaDetalle> obtenerPorId(int id) async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/mascotas/$id'),
            headers: AuthSession.headers,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        return MascotaDetalle.fromJson(data is Map<String, dynamic> ? data : decoded);
      } catch (_) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }

    final message = _extractMessage(response.body);
    if (response.statusCode == 404) {
      throw NotFoundException(message ?? 'La mascota no existe.');
    }
    throw ServerException(
      message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
    );
  }

  /// Resolves the content type of a picked photo (`image/jpeg` or
  /// `image/png`). `XFile.mimeType` can come back null on Chrome, so this
  /// falls back to the file extension.
  MediaType _resolveMediaType(XFile foto) {
    final mime = foto.mimeType;
    if (mime == 'image/png') return MediaType('image', 'png');
    if (mime == 'image/jpeg') return MediaType('image', 'jpeg');

    final name = foto.name.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  int _extractId(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final id = data['id'];
          if (id is int) return id;
        }
      }
    } catch (_) {
      // Fall through to the default below.
    }
    return -1;
  }

  String? _extractMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['message'] ?? decoded['error'] ?? decoded['mensaje'];
        if (value is String && value.isNotEmpty) return value;
      }
      if (decoded is String && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // Body wasn't JSON; fall back to raw text if it seems readable.
    }
    return null;
  }

  void dispose() => _client.close();
}
