/// Field-level validation rules shared by the mascota publication form.
class MascotaValidators {
  MascotaValidators._();

  static String? nombre(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el nombre de la mascota.';
    if (v.length < 2 || v.length > 50) {
      return 'El nombre debe tener entre 2 y 50 caracteres.';
    }
    return null;
  }

  static String? especie(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Selecciona la especie.';
    return null;
  }

  static String? raza(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 50) return 'La raza no puede superar los 50 caracteres.';
    return null;
  }

  static String? edad(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa la edad.';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed <= 0) {
      return 'La edad debe ser un número entero mayor a 0.';
    }
    return null;
  }

  static String? unidadEdad(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Selecciona la unidad de la edad.';
    return null;
  }

  static String? tamano(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Selecciona el tamaño.';
    return null;
  }

  static String? sexo(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Selecciona el sexo.';
    return null;
  }

  static String? temperamento(List<String> value) {
    if (value.isEmpty) return 'Selecciona al menos un temperamento.';
    return null;
  }

  static String? historialSalud(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 1000) {
      return 'El historial de salud no puede superar los 1000 caracteres.';
    }
    return null;
  }

  static String? ubicacion(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa la ubicación.';
    if (v.length < 3 || v.length > 100) {
      return 'La ubicación debe tener entre 3 y 100 caracteres.';
    }
    return null;
  }

  static String? idDador(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el id del dador.';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed <= 0) {
      return 'Debe ser un número entero positivo.';
    }
    return null;
  }

  static String? fotos(int cantidad) {
    if (cantidad == 0) return 'Debes agregar al menos una foto de la mascota';
    if (cantidad > 6) return 'Puedes agregar máximo 6 fotos.';
    return null;
  }
}
