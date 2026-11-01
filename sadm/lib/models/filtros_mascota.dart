import '../utils/etiquetas.dart';

/// Grupos de filtro; el nombre de cada uno es el query param de `GET /api/mascotas/buscar`.
enum GrupoFiltro { especie, edad, tamano, temperamento, raza }

/// Códigos válidos (los mismos que valida el backend) en el orden en que se muestran.
const especiesFiltro = ['PERRO', 'GATO', 'OTRO'];
const edadesFiltro = ['CACHORRO', 'JOVEN', 'ADULTO', 'SENIOR'];
const tamanosFiltro = ['PEQUENO', 'MEDIANO', 'GRANDE'];
const temperamentosFiltro = [
  'JUGUETON',
  'TRANQUILO',
  'TIMIDO',
  'SOCIABLE',
  'PROTECTOR',
  'ENERGICO',
  'CARINOSO',
];

/// Rangos de edad tal como los define el backend (`rangoEdad`); solo para mostrarlos.
const _edadTextos = {
  'CACHORRO': 'Cachorro',
  'JOVEN': 'Joven',
  'ADULTO': 'Adulto',
  'SENIOR': 'Senior',
};
const _edadRangos = {
  'CACHORRO': 'menos de 1 año',
  'JOVEN': '1 a 3 años',
  'ADULTO': '3 a 8 años',
  'SENIOR': '8 años o más',
};

String edadEtiqueta(String codigo) => _edadTextos[codigo] ?? humanizar(codigo);

String edadEtiquetaConRango(String codigo) =>
    _edadRangos.containsKey(codigo) ? '${edadEtiqueta(codigo)} (${_edadRangos[codigo]})' : codigo;

/// "1 mascota encontrada" / "N mascotas encontradas".
String textoContador(int cantidad) =>
    cantidad == 1 ? '1 mascota encontrada' : '$cantidad mascotas encontradas';

/// Un filtro activo, para mostrarlo como chip y poder quitarlo.
class FiltroActivo {
  const FiltroActivo(this.grupo, this.valor, this.etiqueta);

  final GrupoFiltro grupo;
  final String valor;
  final String etiqueta;
}

/// Estado inmutable de los filtros de búsqueda (HU09).
///
/// Entre grupos distintos la lógica es «Y»; dentro de especie/edad/tamaño es «O»
/// y en temperamento la mascota debe tener todos los marcados (lo resuelve el backend).
class FiltrosMascota {
  const FiltrosMascota({
    this.especies = const {},
    this.raza,
    this.edades = const {},
    this.tamanos = const {},
    this.temperamentos = const {},
  });

  final Set<String> especies;
  final String? raza;
  final Set<String> edades;
  final Set<String> tamanos;
  final Set<String> temperamentos;

  static const vacio = FiltrosMascota();

  bool get hayFiltros =>
      especies.isNotEmpty ||
      raza != null ||
      edades.isNotEmpty ||
      tamanos.isNotEmpty ||
      temperamentos.isNotEmpty;

  /// La raza solo tiene sentido con una única especie elegida.
  bool get permiteRaza => especies.length == 1;

  int get cantidad => activos.length;

  FiltrosMascota copyWith({
    Set<String>? especies,
    Object? raza = _sinCambio,
    Set<String>? edades,
    Set<String>? tamanos,
    Set<String>? temperamentos,
  }) {
    final nuevasEspecies = especies ?? this.especies;
    final nuevaRaza = identical(raza, _sinCambio) ? this.raza : raza as String?;
    return FiltrosMascota(
      especies: nuevasEspecies,
      // Sin una única especie la raza deja de aplicar: se descarta para no filtrar a ciegas.
      raza: nuevasEspecies.length == 1 ? nuevaRaza : null,
      edades: edades ?? this.edades,
      tamanos: tamanos ?? this.tamanos,
      temperamentos: temperamentos ?? this.temperamentos,
    );
  }

  /// Quita un valor de un grupo (chip ✕).
  FiltrosMascota sin(GrupoFiltro grupo, String valor) {
    Set<String> menos(Set<String> s) => {...s}..remove(valor);
    return switch (grupo) {
      GrupoFiltro.especie => copyWith(especies: menos(especies)),
      GrupoFiltro.raza => copyWith(raza: null),
      GrupoFiltro.edad => copyWith(edades: menos(edades)),
      GrupoFiltro.tamano => copyWith(tamanos: menos(tamanos)),
      GrupoFiltro.temperamento => copyWith(temperamentos: menos(temperamentos)),
    };
  }

  /// Filtros activos en el orden del panel, con su texto para el chip.
  List<FiltroActivo> get activos => [
        for (final v in especiesFiltro.where(especies.contains))
          FiltroActivo(GrupoFiltro.especie, v, humanizar(v)),
        if (raza != null) FiltroActivo(GrupoFiltro.raza, raza!, raza!),
        for (final v in edadesFiltro.where(edades.contains))
          FiltroActivo(GrupoFiltro.edad, v, edadEtiqueta(v)),
        for (final v in tamanosFiltro.where(tamanos.contains))
          FiltroActivo(GrupoFiltro.tamano, v, humanizar(v)),
        for (final v in temperamentosFiltro.where(temperamentos.contains))
          FiltroActivo(GrupoFiltro.temperamento, v, humanizar(v)),
      ];

  /// Query params de `GET /api/mascotas/buscar`: los de selección múltiple se
  /// repiten (`especie=PERRO&especie=GATO`). Texto en blanco = no se envía.
  Map<String, List<String>> toQueryParameters({String? nombre}) {
    final texto = nombre?.trim() ?? '';
    return {
      if (texto.isNotEmpty) 'nombre': [texto],
      if (especies.isNotEmpty) 'especie': especiesFiltro.where(especies.contains).toList(),
      if (raza != null) 'raza': [raza!],
      if (edades.isNotEmpty) 'edad': edadesFiltro.where(edades.contains).toList(),
      if (tamanos.isNotEmpty) 'tamano': tamanosFiltro.where(tamanos.contains).toList(),
      if (temperamentos.isNotEmpty)
        'temperamento': temperamentosFiltro.where(temperamentos.contains).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FiltrosMascota &&
      other.raza == raza &&
      other.especies.length == especies.length &&
      other.especies.containsAll(especies) &&
      other.edades.length == edades.length &&
      other.edades.containsAll(edades) &&
      other.tamanos.length == tamanos.length &&
      other.tamanos.containsAll(tamanos) &&
      other.temperamentos.length == temperamentos.length &&
      other.temperamentos.containsAll(temperamentos);

  @override
  int get hashCode => Object.hash(
        raza,
        Object.hashAllUnordered(especies),
        Object.hashAllUnordered(edades),
        Object.hashAllUnordered(tamanos),
        Object.hashAllUnordered(temperamentos),
      );
}

const Object _sinCambio = Object();
