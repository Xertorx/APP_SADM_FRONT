/// HU10: ubicación de referencia del usuario (`/api/perfil/ubicacion`) o ubicación de una mascota
/// al publicarla. [localidad] es el código del catálogo (null si vino del GPS).
class Ubicacion {
  const Ubicacion({
    required this.latitud,
    required this.longitud,
    this.localidad,
    this.fechaActualizacion,
  });

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    final localidad = json['localidad'];
    final fecha = json['fechaActualizacion'];
    return Ubicacion(
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      localidad: localidad is String && localidad.isNotEmpty ? localidad : null,
      fechaActualizacion: fecha is String ? DateTime.tryParse(fecha) : null,
    );
  }

  final double latitud;
  final double longitud;
  final String? localidad;
  final DateTime? fechaActualizacion;

  Map<String, dynamic> toJson() => {
        'latitud': latitud,
        'longitud': longitud,
        if (localidad != null) 'localidad': localidad,
      };
}

/// Una localidad de Bogotá con las coordenadas aproximadas de su centro
/// (`GET /api/ubicaciones/localidades`).
class Localidad {
  const Localidad({
    required this.codigo,
    required this.nombre,
    required this.latitud,
    required this.longitud,
  });

  factory Localidad.fromJson(Map<String, dynamic> json) => Localidad(
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
      );

  final String codigo;
  final String nombre;
  final double latitud;
  final double longitud;

  Ubicacion aUbicacion() => Ubicacion(latitud: latitud, longitud: longitud, localidad: codigo);
}
