import '../utils/etiquetas.dart';

/// Máximo de fotos que se muestran de una mascota.
const maxFotosMascota = 6;

/// Read model of a mascota as returned by `GET /api/mascotas/{id}` and by the
/// postulación summary.
class MascotaDetalle {
  const MascotaDetalle({
    required this.id,
    required this.nombre,
    required this.estado,
    this.especie,
    this.raza,
    this.edad,
    this.unidadEdad,
    this.tamano,
    this.sexo,
    this.temperamento = const [],
    this.ubicacion,
    this.historialSalud,
    this.fotoUrl,
    this.fotos = const [],
  });

  factory MascotaDetalle.fromJson(Map<String, dynamic> json) {
    return MascotaDetalle(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      estado: json['estado'] as String,
      especie: _texto(json['especie']),
      raza: _texto(json['raza']),
      edad: (json['edad'] as num?)?.toInt(),
      unidadEdad: _texto(json['unidadEdad']),
      tamano: _texto(json['tamano']),
      sexo: _texto(json['sexo']),
      temperamento: _lista(json['temperamento']),
      ubicacion: _texto(json['ubicacion']),
      historialSalud: _texto(json['historialSalud']),
      fotoUrl: _texto(json['fotoUrl']),
      fotos: _lista(json['fotos'], clave: 'url'),
    );
  }

  final int id;
  final String nombre;
  final String estado;
  final String? especie;
  final String? raza;
  final int? edad;
  final String? unidadEdad;
  final String? tamano;
  final String? sexo;
  final List<String> temperamento;
  final String? ubicacion;
  final String? historialSalud;
  final String? fotoUrl;
  final List<String> fotos;

  bool get disponible => estado.toUpperCase() == 'DISPONIBLE';

  String get estadoTexto => humanizar(estado);

  /// Fotos sin repetir, la principal primero, hasta [maxFotosMascota].
  List<String> get galeria {
    final todas = <String>{?fotoUrl, ...fotos};
    return todas.take(maxFotosMascota).toList();
  }

  /// "3 años"; null si no hay edad.
  String? get edadTexto {
    if (edad == null) return null;
    return '$edad ${unidadEdad == null ? '' : humanizar(unidadEdad!).toLowerCase()}'.trim();
  }

  /// "Perro · Criollo · 3 años · Mediano"
  String get datosClave {
    final edadTexto = this.edadTexto;
    return [
      if (especie != null) humanizar(especie!),
      ?raza,
      ?edadTexto,
      if (tamano != null) humanizar(tamano!),
    ].join(' · ');
  }
}

String? _texto(Object? valor) {
  if (valor is! String) return null;
  final texto = valor.trim();
  return texto.isEmpty ? null : texto;
}

/// Accepts a JSON array (of strings or of objects holding [clave]) or a
/// comma-separated string.
List<String> _lista(Object? valor, {String? clave}) {
  final Iterable<Object?> items;
  if (valor is List) {
    items = valor;
  } else if (valor is String) {
    items = valor.split(',');
  } else {
    return const [];
  }
  return [
    for (final item in items) ?_texto(item is Map && clave != null ? item[clave] : item),
  ];
}
