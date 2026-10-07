import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/mascota.dart';
import 'api_exception.dart';

/// HTTP service responsible for talking to the SADM mascotas API.
class MascotaService {
  MascotaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _createUri => Uri.parse('${AppConfig.baseUrl}/mascotas/crear');

  /// Publishes a new mascota with its photos. Returns the created id.
  /// Throws an [ApiException] subtype on failure.
  Future<int> crear(Mascota mascota, List<XFile> fotos) async {
    final request = http.MultipartRequest('POST', _createUri)
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

    late final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const ConnectionException();
    } on HttpException {
      throw const ConnectionException();
    } on FormatException {
      throw const ConnectionException();
    } catch (_) {
      throw const ConnectionException();
    }

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractId(response.body);
    }

    final message = _extractMessage(response.body);

    switch (response.statusCode) {
      case 400:
        throw ValidationException(
          message ?? 'Los datos ingresados no son válidos.',
        );
      case 404:
        throw NotFoundException(message ?? 'El usuario dador no existe');
      default:
        throw ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
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
