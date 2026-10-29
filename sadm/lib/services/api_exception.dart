import '../config/postulacion_textos.dart';

/// Base type for all errors raised by the API services.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised on HTTP 400 responses (validation errors from the backend).
class ValidationException extends ApiException {
  const ValidationException(super.message);
}

/// Raised on HTTP 409 responses (duplicate email).
class DuplicateEmailException extends ApiException {
  const DuplicateEmailException([
    super.message = 'El correo ingresado ya existe',
  ]);
}

/// Raised when the request could not reach the server (timeouts, no
/// connection, DNS failures, etc.).
class ConnectionException extends ApiException {
  const ConnectionException([
    super.message = 'No fue posible conectar con el servidor. '
        'Verifica tu conexión e inténtalo nuevamente.',
  ]);
}

/// Raised for any other unexpected server response.
class ServerException extends ApiException {
  const ServerException(super.message);
}

/// Raised on HTTP 404 responses (e.g. a referenced resource, like the
/// dador, does not exist).
class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

/// Backend code `POSTULACION_DUPLICADA`.
class PostulacionDuplicadaException extends ApiException {
  const PostulacionDuplicadaException([
    super.message = PostulacionTextos.errorDuplicada,
  ]);
}

/// Backend code `MASCOTA_NO_DISPONIBLE`.
class MascotaNoDisponibleException extends ApiException {
  const MascotaNoDisponibleException([
    super.message = PostulacionTextos.errorNoDisponible,
  ]);
}

/// Raised on HTTP 401 responses.
class NoAutenticadoException extends ApiException {
  const NoAutenticadoException([
    super.message = PostulacionTextos.errorNoAutenticado,
  ]);
}

/// Raised on HTTP 403 responses.
class SinPermisosException extends ApiException {
  const SinPermisosException([
    super.message = PostulacionTextos.errorSinPermisos,
  ]);
}
