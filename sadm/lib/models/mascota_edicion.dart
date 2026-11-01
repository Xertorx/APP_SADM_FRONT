import 'mascota_detalle.dart';

/// Response of `GET /api/mascotas/{id}/editar`: the current data of a
/// mascota plus whether it has active postulaciones.
class MascotaEdicion {
  const MascotaEdicion({
    required this.mascota,
    required this.tienePostulacionesActivas,
  });

  /// Accepts the mascota fields at the top level or nested under `mascota`/`datos`.
  factory MascotaEdicion.fromJson(Map<String, dynamic> json, {required int id}) {
    final anidada = json['mascota'] ?? json['datos'];
    final datos = anidada is Map<String, dynamic> ? anidada : json;
    return MascotaEdicion(
      mascota: MascotaDetalle.fromJson(datos, idPorDefecto: id),
      tienePostulacionesActivas: json['tienePostulacionesActivas'] == true ||
          datos['tienePostulacionesActivas'] == true,
    );
  }

  final MascotaDetalle mascota;
  final bool tienePostulacionesActivas;
}
