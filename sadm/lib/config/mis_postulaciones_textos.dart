/// Textos de la UI de "Mis postulaciones" (HU21).
class MisPostulacionesTextos {
  MisPostulacionesTextos._();

  static const titulo = 'Mis postulaciones';
  static const accionTitulo = 'Mis postulaciones';
  static const accionDescripcion = 'Consulta en qué etapa va cada una de tus postulaciones.';

  // Pestañas
  static const pestanaTodas = 'Todas';
  static const pestanaActivas = 'Activas';
  static const pestanaGanadora = 'Ganadora';
  static const pestanaDescartadas = 'Descartadas';
  static const sinResultadosFiltro = 'No tienes postulaciones en esta categoría.';

  // Estados visibles
  static const estadoActiva = 'Activa';
  static const estadoGanadora = 'Ganadora';
  static const estadoDescartada = 'Descartada';

  // Vacío
  static const vacioTitulo = 'Aún no te has postulado a ninguna mascota';
  static const vacioSubtitulo =
      'Explora las mascotas disponibles y postúlate a la que se ajuste a tu hogar.';
  static const verMascotas = 'Ver mascotas disponibles';

  // Tarjeta
  static const verDetalle = 'Ver detalle';
  static const reintentar = 'Reintentar';
  static const publicadoPor = 'Publicado por';
  static const proceso = 'Proceso';
  static const puntajeAcumulado = 'Puntaje acumulado';
  static const progreso = 'Progreso';
  static const procesoCompletado = 'Proceso completado';
  static const etapaActual = 'Etapa actual';
  static const motivo = 'Motivo';

  /// Nombres de las etapas 1 a 4 de la barra de progreso.
  static const etapas = ['Formulario', 'Documentos', 'Entrevista', 'Visita'];

  static String nombreEtapa(int numero) =>
      (numero >= 1 && numero <= etapas.length) ? etapas[numero - 1] : 'Etapa $numero';

  static String etapaNDeTotal(int n, int total) => 'Etapa $n de $total';
  static String descartadaEnEtapa(int n) => 'Descartada en etapa $n';

  // Errores
  static const errorRespuesta = 'No pudimos leer la respuesta del servidor.';
  static const errorGenerico = 'No pudimos cargar tus postulaciones. Inténtalo de nuevo.';
}
