/// HU12: configuración del proceso de selección de una mascota
/// (`/api/mascotas/{id}/configuracion-seleccion`).
///
/// Estos modelos son la fuente de datos para las HU siguientes:
/// - HU14: [PreguntaSeleccion] (texto, [TipoRespuesta], opciones) arma el formulario del adoptante.
/// - HU15: [DocumentoSeleccion] arma el checklist de archivos pendientes.
/// - HU16 / HU17: [CriterioSeleccion] de entrevista y visita domiciliaria.
/// - HU18: [ConfiguracionSeleccion.etapas] expone las etapas en orden y su puntaje máximo.
library;

/// Puntos totales que deben repartirse entre las cuatro etapas.
const puntajeTotalSeleccion = 100;

enum TipoRespuesta {
  texto('TEXTO', 'Texto libre'),
  siNo('SI_NO', 'Sí / No'),
  seleccionUnica('SELECCION_UNICA', 'Selección única'),
  seleccionMultiple('SELECCION_MULTIPLE', 'Selección múltiple');

  const TipoRespuesta(this.codigo, this.etiqueta);

  /// Valor que viaja al backend.
  final String codigo;
  final String etiqueta;

  /// Los tipos de selección necesitan una lista de opciones; los demás deben enviarla vacía.
  bool get requiereOpciones => this == seleccionUnica || this == seleccionMultiple;

  static TipoRespuesta desdeCodigo(Object? codigo) {
    for (final tipo in values) {
      if (tipo.codigo == codigo) return tipo;
    }
    return texto;
  }
}

/// Etapas del proceso, en el orden en que las recorre un candidato.
enum EtapaSeleccion {
  preguntas('Preguntas', 'Formulario del adoptante'),
  documentos('Documentos', 'Archivos que debe adjuntar'),
  entrevista('Entrevista', 'Criterios de evaluación'),
  visita('Visita', 'Visita domiciliaria');

  const EtapaSeleccion(this.titulo, this.subtitulo);

  final String titulo;
  final String subtitulo;

  /// Nombre usado en los mensajes de validación.
  String get nombreLargo => switch (this) {
        preguntas => 'Preguntas',
        documentos => 'Documentos',
        entrevista => 'Entrevista',
        visita => 'Visita domiciliaria',
      };
}

/// Elemento puntuable de una etapa.
sealed class ElementoSeleccion {
  const ElementoSeleccion({this.id});

  /// Id persistido; null mientras el elemento no se haya guardado.
  final int? id;

  /// Texto principal que se muestra en las listas.
  String get titulo;

  int get puntaje;

  Map<String, dynamic> toJson();
}

class PreguntaSeleccion extends ElementoSeleccion {
  const PreguntaSeleccion({
    super.id,
    required this.texto,
    required this.tipoRespuesta,
    required this.puntaje,
    this.opciones = const [],
  });

  factory PreguntaSeleccion.fromJson(Map<String, dynamic> json) => PreguntaSeleccion(
        id: _entero(json['id']),
        texto: _texto(json['texto']),
        tipoRespuesta: TipoRespuesta.desdeCodigo(json['tipoRespuesta']),
        puntaje: _entero(json['puntaje']) ?? 0,
        opciones: [
          if (json['opciones'] is List)
            for (final opcion in json['opciones'] as List) _texto(opcion),
        ],
      );

  final String texto;
  final TipoRespuesta tipoRespuesta;
  @override
  final int puntaje;
  final List<String> opciones;

  @override
  String get titulo => texto;

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'texto': texto,
        'tipoRespuesta': tipoRespuesta.codigo,
        'puntaje': puntaje,
        'opciones': tipoRespuesta.requiereOpciones ? opciones : const <String>[],
      };
}

class DocumentoSeleccion extends ElementoSeleccion {
  const DocumentoSeleccion({
    super.id,
    required this.nombre,
    this.descripcion = '',
    required this.obligatorio,
    required this.puntajeMaximo,
  });

  factory DocumentoSeleccion.fromJson(Map<String, dynamic> json) => DocumentoSeleccion(
        id: _entero(json['id']),
        nombre: _texto(json['nombre']),
        descripcion: _texto(json['descripcion']),
        obligatorio: json['obligatorio'] == true,
        puntajeMaximo: _entero(json['puntajeMaximo']) ?? 0,
      );

  final String nombre;
  final String descripcion;
  final bool obligatorio;
  final int puntajeMaximo;

  @override
  String get titulo => nombre;

  @override
  int get puntaje => puntajeMaximo;

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'obligatorio': obligatorio,
        'puntajeMaximo': puntajeMaximo,
      };
}

/// Criterio de evaluación de la entrevista o de la visita domiciliaria.
class CriterioSeleccion extends ElementoSeleccion {
  const CriterioSeleccion({super.id, required this.descripcion, required this.puntajeMaximo});

  factory CriterioSeleccion.fromJson(Map<String, dynamic> json) => CriterioSeleccion(
        id: _entero(json['id']),
        descripcion: _texto(json['descripcion']),
        puntajeMaximo: _entero(json['puntajeMaximo']) ?? 0,
      );

  final String descripcion;
  final int puntajeMaximo;

  @override
  String get titulo => descripcion;

  @override
  int get puntaje => puntajeMaximo;

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'descripcion': descripcion,
        'puntajeMaximo': puntajeMaximo,
      };
}

/// Puntaje máximo de una etapa y los elementos configurados dentro de ella.
class DatosEtapa<T extends ElementoSeleccion> {
  const DatosEtapa({this.puntajeMaximo = 0, this.elementos = const []});

  final int puntajeMaximo;
  final List<T> elementos;

  /// Suma de los puntajes de los elementos.
  int get puntajeAsignado => elementos.fold(0, (suma, e) => suma + e.puntaje);

  DatosEtapa<T> conPuntajeMaximo(int valor) =>
      DatosEtapa(puntajeMaximo: valor, elementos: elementos);

  DatosEtapa<T> conElementos(List<T> valores) =>
      DatosEtapa(puntajeMaximo: puntajeMaximo, elementos: List.unmodifiable(valores));
}

/// Agregado completo de las cuatro etapas de una mascota.
class ConfiguracionSeleccion {
  const ConfiguracionSeleccion({
    required this.mascotaId,
    this.definitiva = false,
    this.preguntas = const DatosEtapa(),
    this.documentos = const DatosEtapa(),
    this.entrevista = const DatosEtapa(),
    this.visitaDomiciliaria = const DatosEtapa(),
  });

  factory ConfiguracionSeleccion.fromJson(Map<String, dynamic> json, {required int mascotaId}) {
    DatosEtapa<T> etapa<T extends ElementoSeleccion>(
      Object? valor,
      String clave,
      T Function(Map<String, dynamic>) crear,
    ) {
      if (valor is! Map<String, dynamic>) return const DatosEtapa();
      final lista = valor[clave];
      return DatosEtapa(
        puntajeMaximo: _entero(valor['puntajeMaximo']) ?? 0,
        elementos: [
          if (lista is List)
            for (final item in lista)
              if (item is Map<String, dynamic>) crear(item),
        ],
      );
    }

    return ConfiguracionSeleccion(
      mascotaId: _entero(json['mascotaId']) ?? mascotaId,
      definitiva: json['definitiva'] == true,
      preguntas: etapa(json['preguntas'], 'elementos', PreguntaSeleccion.fromJson),
      documentos: etapa(json['documentos'], 'elementos', DocumentoSeleccion.fromJson),
      entrevista: etapa(json['entrevista'], 'criterios', CriterioSeleccion.fromJson),
      visitaDomiciliaria:
          etapa(json['visitaDomiciliaria'], 'criterios', CriterioSeleccion.fromJson),
    );
  }

  final int mascotaId;
  final bool definitiva;
  final DatosEtapa<PreguntaSeleccion> preguntas;
  final DatosEtapa<DocumentoSeleccion> documentos;
  final DatosEtapa<CriterioSeleccion> entrevista;
  final DatosEtapa<CriterioSeleccion> visitaDomiciliaria;

  /// Las cuatro etapas en orden, para recorrerlas sin conocer su tipo (HU18).
  List<({EtapaSeleccion etapa, DatosEtapa<ElementoSeleccion> datos})> get etapas => [
        (etapa: EtapaSeleccion.preguntas, datos: preguntas),
        (etapa: EtapaSeleccion.documentos, datos: documentos),
        (etapa: EtapaSeleccion.entrevista, datos: entrevista),
        (etapa: EtapaSeleccion.visita, datos: visitaDomiciliaria),
      ];

  DatosEtapa<ElementoSeleccion> datosDe(EtapaSeleccion etapa) =>
      etapas.firstWhere((e) => e.etapa == etapa).datos;

  /// Suma de los máximos de las cuatro etapas.
  int get puntajeDistribuido => etapas.fold(0, (suma, e) => suma + e.datos.puntajeMaximo);

  int get puntosPendientes =>
      puntajeDistribuido < puntajeTotalSeleccion ? puntajeTotalSeleccion - puntajeDistribuido : 0;

  int get puntosExcedentes =>
      puntajeDistribuido > puntajeTotalSeleccion ? puntajeDistribuido - puntajeTotalSeleccion : 0;

  ConfiguracionSeleccion copyWith({
    bool? definitiva,
    DatosEtapa<PreguntaSeleccion>? preguntas,
    DatosEtapa<DocumentoSeleccion>? documentos,
    DatosEtapa<CriterioSeleccion>? entrevista,
    DatosEtapa<CriterioSeleccion>? visitaDomiciliaria,
  }) =>
      ConfiguracionSeleccion(
        mascotaId: mascotaId,
        definitiva: definitiva ?? this.definitiva,
        preguntas: preguntas ?? this.preguntas,
        documentos: documentos ?? this.documentos,
        entrevista: entrevista ?? this.entrevista,
        visitaDomiciliaria: visitaDomiciliaria ?? this.visitaDomiciliaria,
      );

  /// Cuerpo del `PUT`: siempre las cuatro etapas completas.
  Map<String, dynamic> toJson() => {
        'preguntas': {
          'puntajeMaximo': preguntas.puntajeMaximo,
          'elementos': [for (final e in preguntas.elementos) e.toJson()],
        },
        'documentos': {
          'puntajeMaximo': documentos.puntajeMaximo,
          'elementos': [for (final e in documentos.elementos) e.toJson()],
        },
        'entrevista': {
          'puntajeMaximo': entrevista.puntajeMaximo,
          'criterios': [for (final e in entrevista.elementos) e.toJson()],
        },
        'visitaDomiciliaria': {
          'puntajeMaximo': visitaDomiciliaria.puntajeMaximo,
          'criterios': [for (final e in visitaDomiciliaria.elementos) e.toJson()],
        },
      };
}

int? _entero(Object? valor) => valor is num ? valor.toInt() : int.tryParse('$valor');

String _texto(Object? valor) => valor is String ? valor : '';
