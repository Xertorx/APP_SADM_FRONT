/// Reglas de validación del formulario de perfil (HU04). Espejo de las del backend.
class PerfilValidators {
  PerfilValidators._();

  static const maxBytesFoto = 5 * 1024 * 1024;

  static final _soloLetras = RegExp(r'^[\p{L} ]+$', unicode: true);
  static final _telefono = RegExp(r'^\+?[0-9]{7,15}$');
  static final _formatoNueva = RegExp(r'^(?=.*[A-Z])(?=.*\d).{8,72}$');

  static String? nombre(String? value) => _nombrePropio(value, 'nombre');

  static String? apellido(String? value) => _nombrePropio(value, 'apellido');

  static String? _nombrePropio(String? value, String campo) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El $campo es obligatorio';
    if (v.length < 3 || v.length > 50) {
      return 'El $campo debe tener entre 3 y 50 caracteres';
    }
    if (!_soloLetras.hasMatch(v)) return 'El $campo solo puede contener letras';
    return null;
  }

  static String? telefono(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El teléfono es obligatorio';
    if (!_telefono.hasMatch(v)) return 'El teléfono debe contener entre 7 y 15 dígitos';
    return null;
  }

  static String? ubicacion(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'La ubicación es obligatoria';
    if (v.length < 5 || v.length > 150) {
      return 'La ubicación debe tener entre 5 y 150 caracteres';
    }
    return null;
  }

  /// El bloque de contraseña es opcional: si cualquiera de los tres tiene texto,
  /// los tres pasan a ser obligatorios.
  static bool bloqueUsado(String? actual, String? nueva, String? confirmar) =>
      (actual ?? '').isNotEmpty || (nueva ?? '').isNotEmpty || (confirmar ?? '').isNotEmpty;

  static String? contrasenaActual(String? actual, String? nueva, String? confirmar) {
    if (!bloqueUsado(actual, nueva, confirmar)) return null;
    if ((actual ?? '').isEmpty) {
      return 'Debes ingresar tu contraseña actual para cambiar la contraseña';
    }
    return null;
  }

  static String? contrasenaNueva(String? actual, String? nueva, String? confirmar) {
    if (!bloqueUsado(actual, nueva, confirmar)) return null;
    final n = nueva ?? '';
    if (!_formatoNueva.hasMatch(n)) {
      return 'La nueva contraseña debe tener entre 8 y 72 caracteres, una mayúscula y un número';
    }
    if (n == actual) return 'La nueva contraseña debe ser diferente a la actual';
    return null;
  }

  static String? confirmar(String? actual, String? nueva, String? confirmar) {
    if (!bloqueUsado(actual, nueva, confirmar)) return null;
    if ((confirmar ?? '') != (nueva ?? '')) return 'Las contraseñas no coinciden';
    return null;
  }

  /// [tipo] es el mime reportado por el selector (puede ser null en web); se usa
  /// la extensión del [nombreArchivo] como respaldo.
  static String? foto({required String nombreArchivo, String? tipo, required int bytes}) {
    final nombre = nombreArchivo.toLowerCase();
    final esImagen = tipo == 'image/jpeg' ||
        tipo == 'image/png' ||
        ((tipo == null || tipo.isEmpty) &&
            (nombre.endsWith('.jpg') || nombre.endsWith('.jpeg') || nombre.endsWith('.png')));
    if (!esImagen) return 'La foto debe ser JPG o PNG';
    if (bytes > maxBytesFoto) return 'La foto no puede superar 5 MB';
    return null;
  }
}
