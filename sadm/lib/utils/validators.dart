/// Field-level validation rules shared by the adoptante registration form.
class Validators {
  Validators._();

  static final _nameRegExp = RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ]{3,50}$');
  static final _idRegExp = RegExp(r'^\d{1,10}$');
  static final _emailRegExp = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );
  static final _passwordLetterRegExp = RegExp(r'[A-Za-z]');
  static final _passwordDigitRegExp = RegExp(r'\d');
  static final _phoneRegExp = RegExp(r'^\+?\d{7,15}$');

  static String? nombreApellido(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el $label.';
    if (!_nameRegExp.hasMatch(v)) {
      return '$label debe tener 3-50 letras, sin espacios ni números.';
    }
    return null;
  }

  static String? identificacion(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa la identificación.';
    if (!_idRegExp.hasMatch(v)) {
      return 'Debe ser un número entero positivo de máximo 10 dígitos.';
    }
    if (int.tryParse(v) == null || int.parse(v) <= 0) {
      return 'Debe ser un número entero positivo.';
    }
    return null;
  }

  static String? fechaNacimiento(DateTime? value) {
    if (value == null) return 'Selecciona la fecha de nacimiento.';
    if (!value.isBefore(DateTime.now())) {
      return 'La fecha debe ser anterior a hoy.';
    }
    return null;
  }

  static String? correo(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el correo.';
    if (v.length > 254) return 'El correo no debe superar 254 caracteres.';
    if (!_emailRegExp.hasMatch(v)) return 'Ingresa un correo válido.';
    return null;
  }

  static String? contrasena(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa la contraseña.';
    if (v.length < 8 || v.length > 72) {
      return 'La contraseña debe tener entre 8 y 72 caracteres.';
    }
    if (!_passwordLetterRegExp.hasMatch(v) || !_passwordDigitRegExp.hasMatch(v)) {
      return 'Debe incluir al menos una letra y un número.';
    }
    return null;
  }

  static String? telefono(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el teléfono.';
    if (!_phoneRegExp.hasMatch(v)) {
      return 'Debe tener 7-15 dígitos, puede iniciar con "+".';
    }
    return null;
  }

  static String? direccion(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 5 || v.length > 150) {
      return 'La dirección debe tener entre 5 y 150 caracteres.';
    }
    return null;
  }

  static String? tipoUsuario(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El tipo de usuario es obligatorio.';
    if (v.length > 30) return 'Máximo 30 caracteres.';
    return null;
  }

  static String? estado(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El estado es obligatorio.';
    if (v.length > 20) return 'Máximo 20 caracteres.';
    return null;
  }
}
