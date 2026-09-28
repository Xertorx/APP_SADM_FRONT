import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/adoptante.dart';
import 'api_exception.dart';

/// HTTP service responsible for talking to the SADM adoptantes API.
class AdoptanteService {
  AdoptanteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _createUri => Uri.parse('${AppConfig.baseUrl}/adoptantes/crear');

  /// Registers a new adoptante. Throws an [ApiException] subtype on failure.
  Future<void> crear(Adoptante adoptante) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            _createUri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(adoptante.toJson()),
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const ConnectionException();
    } on HttpException {
      throw const ConnectionException();
    } on FormatException {
      throw const ConnectionException();
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    final message = _extractMessage(response.body);

    switch (response.statusCode) {
      case 400:
        throw ValidationException(
          message ?? 'Los datos ingresados no son válidos.',
        );
      case 409:
        throw DuplicateEmailException(
          message ?? 'El correo ingresado ya existe',
        );
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
      if (decoded is String && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // Body wasn't JSON; fall back to raw text if it seems readable.
    }
    return null;
  }

  void dispose() => _client.close();
}
