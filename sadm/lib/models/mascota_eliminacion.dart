import '../config/app_config.dart';
import '../utils/etiquetas.dart';

/// Response of `GET /api/mascotas/{id}/eliminacion`: what the confirmation
/// dialog needs to show before deleting a publicación.
class MascotaEliminacion {
  const MascotaEliminacion({
    required this.id,
    required this.nombre,
    required this.postulacionesActivas,
    this.especie,
    this.raza,
    this.edad,
    this.unidadEdad,
    this.fechaPublicacion,
    this.primeraFotoId,
  });

  factory MascotaEliminacion.fromJson(Map<String, dynamic> json) {
    return MascotaEliminacion(
      id: _entero(json['id']) ?? (throw const FormatException('Falta el id')),
      nombre: _texto(json['nombre']) ?? '',
      especie: _texto(json['especie']),
      raza: _texto(json['raza']),
      edad: _entero(json['edad']),
      unidadEdad: _texto(json['unidadEdad']),
      fechaPublicacion: _fecha(json['fechaPublicacion']),
      primeraFotoId: _entero(json['primeraFotoId']),
      postulacionesActivas: _entero(json['postulacionesActivas']) ?? 0,
    );
  }

  final int id;
  final String nombre;
  final String? especie;
  final String? raza;
  final int? edad;
  final String? unidadEdad;
  final DateTime? fechaPublicacion;
  final int? primeraFotoId;
  final int postulacionesActivas;

  bool get tienePostulacionesActivas => postulacionesActivas > 0;

  /// `GET /api/mascotas/fotos/{id}`; null when the mascota has no photo.
  String? get fotoUrl =>
      primeraFotoId == null ? null : '${AppConfig.baseUrl}/mascotas/fotos/$primeraFotoId';

  /// "Perro · Labrador · 3 años"
  String get datosClave {
    final edadTexto = edad == null
        ? null
        : '$edad ${unidadEdad == null ? '' : humanizar(unidadEdad!).toLowerCase()}'.trim();
    return [
      if (especie != null) humanizar(especie!),
      ?raza,
      ?edadTexto,
    ].join(' · ');
  }

  /// "Publicada hace 12 días"; null when the backend sent no date.
  String? publicadaHace([DateTime? ahora]) {
    final fecha = fechaPublicacion;
    if (fecha == null) return null;
    final dias = (ahora ?? DateTime.now()).difference(fecha).inDays;
    if (dias <= 0) return 'Publicada hoy';
    return dias == 1 ? 'Publicada hace 1 día' : 'Publicada hace $dias días';
  }
}

String? _texto(Object? valor) {
  if (valor is! String) return null;
  final texto = valor.trim();
  return texto.isEmpty ? null : texto;
}

int? _entero(Object? valor) => valor is num ? valor.toInt() : int.tryParse('$valor');

/// Jackson can send a date as an ISO string or as epoch milliseconds.
DateTime? _fecha(Object? valor) {
  if (valor is num) return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}
