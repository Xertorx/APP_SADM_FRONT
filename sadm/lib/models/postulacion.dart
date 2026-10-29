import '../utils/etiquetas.dart';

/// A registered postulación (`POST /api/postulaciones` response).
class Postulacion {
  const Postulacion({
    required this.mascotaId,
    required this.fecha,
    required this.estado,
    required this.puntaje,
    this.id,
  });

  factory Postulacion.fromJson(Map<String, dynamic> json) {
    final fecha = json['fechaPostulacion'] ?? json['fecha'];
    return Postulacion(
      id: (json['id'] as num?)?.toInt(),
      mascotaId: (json['mascotaId'] as num).toInt(),
      fecha: DateTime.parse(fecha as String),
      estado: json['estado'] as String,
      puntaje: (json['puntaje'] as num?)?.toInt() ?? 0,
    );
  }

  final int? id;
  final int mascotaId;
  final DateTime fecha;
  final String estado;
  final int puntaje;

  String get estadoTexto => humanizar(estado);
}
