import '../config/detalle_mascota_textos.dart';

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Datos públicos de quien publica una mascota (`GET /api/perfil/publico/{id}`).
/// El backend nunca envía correo, teléfono, dirección ni identificación.
class DadorPublico {
  const DadorPublico({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.tieneFoto,
    this.miembroDesde,
  });

  factory DadorPublico.fromJson(Map<String, dynamic> json) {
    return DadorPublico(
      id: (json['id'] as num?)?.toInt() ?? -1,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      tieneFoto: json['tieneFoto'] == true,
      miembroDesde: fechaDesdeJson(json['miembroDesde']),
    );
  }

  final int id;
  final String nombre;
  final String apellido;
  final bool tieneFoto;
  final DateTime? miembroDesde;

  String get nombreCompleto => '$nombre $apellido'.trim();

  /// "Miembro desde marzo de 2025"; null si el usuario no tiene fecha de registro.
  String? get miembroDesdeTexto {
    final fecha = miembroDesde?.toLocal();
    if (fecha == null) return null;
    return '${DetalleMascotaTextos.miembroDesde} ${_meses[fecha.month - 1]} de ${fecha.year}';
  }
}

/// Jackson envía las fechas como texto ISO-8601 o como milisegundos, según la configuración.
DateTime? fechaDesdeJson(Object? valor) {
  if (valor is num) return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}
