import '../config/admin_usuarios_textos.dart';

/// Validadores de HU28 (propios para no tocar validators.dart).
class AdminValidators {
  AdminValidators._();

  static const motivoMin = 10;
  static const motivoMax = 300;

  /// Motivo de inhabilitación: obligatorio y de 10 a 300 caracteres (sin contar espacios de los bordes).
  static String? motivo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return AdminUsuariosTextos.motivoObligatorio;
    if (texto.length < motivoMin || texto.length > motivoMax) {
      return AdminUsuariosTextos.motivoLongitud;
    }
    return null;
  }
}
