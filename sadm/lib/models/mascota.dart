/// Data model for a "mascota" (pet) publication request.
///
/// The JSON keys match exactly what the SADM backend expects for the
/// "datos" part of `POST /SADM/mascotas/crear`. Photos are sent separately
/// as multipart file parts, not through this model.
class Mascota {
  const Mascota({
    required this.idDador,
    required this.nombre,
    required this.especie,
    this.raza,
    required this.edad,
    required this.unidadEdad,
    required this.tamano,
    required this.sexo,
    required this.temperamento,
    this.historialSalud,
    required this.ubicacion,
    this.latitud,
    this.longitud,
  });

  // TODO HU02: tomar del usuario autenticado en vez de un campo editable.
  final int idDador;
  final String nombre;
  final String especie;
  final String? raza;
  final int edad;
  final String unidadEdad;
  final String tamano;
  final String sexo;
  final List<String> temperamento;
  final String? historialSalud;
  final String ubicacion;

  /// HU10 (opcionales, las dos o ninguna): coordenadas para las búsquedas por cercanía.
  final double? latitud;
  final double? longitud;

  /// Converts this model into the exact JSON payload expected by the
  /// "datos" part of `POST /SADM/mascotas/crear`.
  Map<String, dynamic> toJson() {
    return {
      'idDador': idDador,
      'nombre': nombre,
      'especie': especie,
      'raza': raza,
      'edad': edad,
      'unidadEdad': unidadEdad,
      'tamano': tamano,
      'sexo': sexo,
      'temperamento': temperamento,
      'historialSalud': historialSalud,
      'ubicacion': ubicacion,
      if (latitud != null && longitud != null) ...{
        'latitud': latitud,
        'longitud': longitud,
      },
    };
  }
}
