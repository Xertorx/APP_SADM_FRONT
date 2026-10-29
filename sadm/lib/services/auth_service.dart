import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP service responsible for authenticating usuarios.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _loginUri => Uri.parse('${AppConfig.baseUrl}/autenticacion/login');

  /// `POST /api/autenticacion/login`. On success the token is stored in
  /// [AuthSession]. Throws an [ApiException] subtype on failure.
  Future<void> login(String correo, String contrasena) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            _loginUri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'correo': correo, 'contraseña': contrasena}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ConnectionException();
    }

    if (response.statusCode == 200) {
      final token = _extractToken(response.body);
      if (token == null) {
        throw const ServerException('Respuesta inesperada del servidor.');
      }
      AuthSession.iniciar(token);
      return;
    }

    final message = _extractMessage(response.body);
    switch (response.statusCode) {
      case 400:
        throw ValidationException(message ?? 'Los datos ingresados no son válidos.');
      case 401:
      case 403:
        throw NoAutenticadoException(message ?? 'Correo o contraseña incorrectos.');
      default:
        throw ServerException(
          message ?? 'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  String? _extractToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        final source = data is Map<String, dynamic> ? data : decoded;
        final token = source['accessToken'];
        if (token is String && token.isNotEmpty) return token;
      }
    } catch (_) {
      // Fall through to the default below.
    }
    return null;
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
