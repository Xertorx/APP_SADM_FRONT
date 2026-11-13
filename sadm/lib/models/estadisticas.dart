/// Cifra que puede no estar disponible aún (HU20 / HU22). Si [disponible] es false se muestra en gris.
class CifraDisponible {
  const CifraDisponible({required this.valor, required this.disponible});

  final int valor;
  final bool disponible;

  factory CifraDisponible.fromJson(Map<String, dynamic> json) => CifraDisponible(
        valor: (json['valor'] as num).toInt(),
        disponible: json['disponible'] as bool,
      );
}

/// Respuesta de `GET /api/admin/estadisticas` (HU30).
class Estadisticas {
  const Estadisticas({
    required this.mascotasPublicadas,
    required this.mascotasPorEstado,
    required this.adopcionesCompletadas,
    required this.usuariosActivosPorRol,
    required this.postulacionesEnCurso,
    required this.adopcionesEnSeguimiento,
    required this.generadoEn,
    this.desde,
    this.hasta,
  });

  final int mascotasPublicadas;
  final Map<String, int> mascotasPorEstado;
  final CifraDisponible adopcionesCompletadas;
  final Map<String, int> usuariosActivosPorRol;
  final int postulacionesEnCurso;
  final CifraDisponible adopcionesEnSeguimiento;
  final DateTime generadoEn;
  final String? desde;
  final String? hasta;

  /// Suma de usuarios activos de todos los roles (base de los porcentajes del gráfico).
  int get totalUsuariosActivos => usuariosActivosPorRol.values.fold(0, (a, b) => a + b);

  factory Estadisticas.fromJson(Map<String, dynamic> json) => Estadisticas(
        mascotasPublicadas: (json['mascotasPublicadas'] as num).toInt(),
        mascotasPorEstado: _mapaEnteros(json['mascotasPorEstado']),
        adopcionesCompletadas:
            CifraDisponible.fromJson(json['adopcionesCompletadas'] as Map<String, dynamic>),
        usuariosActivosPorRol: _mapaEnteros(json['usuariosActivosPorRol']),
        postulacionesEnCurso: (json['postulacionesEnCurso'] as num).toInt(),
        adopcionesEnSeguimiento:
            CifraDisponible.fromJson(json['adopcionesEnSeguimiento'] as Map<String, dynamic>),
        desde: json['desde'] as String?,
        hasta: json['hasta'] as String?,
        generadoEn: DateTime.parse(json['generadoEn'] as String),
      );

  static Map<String, int> _mapaEnteros(Object? valor) {
    final mapa = valor as Map<String, dynamic>;
    return {for (final e in mapa.entries) e.key: (e.value as num).toInt()};
  }
}
