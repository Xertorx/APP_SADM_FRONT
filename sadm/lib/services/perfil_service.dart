import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/perfil.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP del perfil (`/api/perfil`). Lanza subclases de [ApiException].
class PerfilService {
  PerfilService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _uri => Uri.parse('${AppConfig.baseUrl}/perfil');
  Uri get _fotoUri => Uri.parse('${AppConfig.baseUrl}/perfil/foto');

  /// `GET /api/perfil`.
  Future<Perfil> obtener() async {
    final response = await _enviar(() => _client.get(_uri, headers: AuthSession.headers));
    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        return Perfil.fromJson(data is Map<String, dynamic> ? data : decoded);
      } catch (_) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
    }
    throw _error(response);
  }

  /// `GET /api/perfil/foto`. Devuelve `null` si el usuario no tiene foto (404).
  /// Se descarga con el header `Authorization`, por eso no se usa `Image.network`.
  Future<Uint8List?> descargarFoto() async {
    final response = await _enviar(() => _client.get(_fotoUri, headers: AuthSession.headers));
    if (response.statusCode == 200) return response.bodyBytes;
    if (response.statusCode == 404) return null;
    throw _error(response);
  }

  /// `PUT /api/perfil` multipart: parte JSON `datos` + `foto` opcional.
  Future<void> actualizar(PerfilActualizacion datos, {XFile? foto, Uint8List? bytesFoto}) async {
    final request = http.MultipartRequest('PUT', _uri)
      ..headers.addAll(AuthSession.headers)
      ..files.add(
        http.MultipartFile.fromString(
          'datos',
          jsonEncode(datos.toJson()),
          contentType: MediaType('application', 'json'),
        ),
      );
    if (foto != null && bytesFoto != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          bytesFoto,
          filename: foto.name,
          contentType: _tipoFoto(foto),
        ),
      );
    }

    final response = await _enviar(() async {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw _error(response);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }
  }

  ApiException _error(http.Response response) {
    final message = _extraerMensaje(utf8.decode(response.bodyBytes));
    switch (response.statusCode) {
      case 400:
        return ValidationException(message ?? 'Los datos ingresados no son válidos.');
      case 401:
        return NoAutenticadoException(message ?? 'Tu sesión expiró. Inicia sesión para continuar.');
      case 403:
        return SinPermisosException(message ?? 'No tienes permisos para ver este perfil.');
      case 404:
        return NotFoundException(message ?? 'No se encontró tu perfil.');
      default:
        return ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  /// En 400 de validación el mensaje útil viene en `data` ({campo: mensaje}).
  String? _extraerMensaje(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          return data.values.whereType<String>().join('\n');
        }
        final value = decoded['message'] ?? decoded['error'] ?? decoded['mensaje'];
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {
      // El cuerpo no era JSON.
    }
    return null;
  }

  /// `XFile.mimeType` puede ser null en Chrome: se usa la extensión como respaldo.
  MediaType _tipoFoto(XFile foto) {
    if (foto.mimeType == 'image/png') return MediaType('image', 'png');
    if (foto.mimeType == 'image/jpeg') return MediaType('image', 'jpeg');
    return foto.name.toLowerCase().endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
  }

  void dispose() => _client.close();
}
