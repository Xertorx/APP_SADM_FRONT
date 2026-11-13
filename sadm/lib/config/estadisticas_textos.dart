import 'package:intl/intl.dart';

/// Textos de la UI del panel de estadísticas (HU30).
class EstadisticasTextos {
  EstadisticasTextos._();

  // Panel
  static const accionTitulo = 'Estadísticas';
  static const accionDescripcion = 'Consulta las cifras generales de uso de la plataforma y exporta el reporte.';

  // Pantalla
  static const titulo = 'Panel de estadísticas';
  static const kpiMascotas = 'Mascotas publicadas';
  static const kpiAdopciones = 'Adopciones completadas';
  static const kpiPostulaciones = 'Postulaciones en curso';
  static const kpiSeguimiento = 'Adopciones en seguimiento';
  static const graficoRoles = 'Usuarios activos por rol';

  // Cifras de módulos aún no implementados
  static const sinModuloSeguimiento = 'Disponible cuando se implemente el seguimiento post-adopción'; // HU22
  static const sinModuloAdopciones = 'Disponible cuando se implemente la notificación al ganador'; // HU20

  // Filtro
  static const desde = 'Desde';
  static const hasta = 'Hasta';
  static const aplicar = 'Aplicar';
  static const limpiar = 'Limpiar';
  static const sinFecha = 'dd/mm/aaaa';
  static const errorRango = 'La fecha inicial no puede ser posterior a la final';
  static const notaFiltro =
      'Usuarios activos, postulaciones en curso y adopciones en seguimiento muestran el estado actual';

  // Botones y mensajes
  static const actualizar = 'Actualizar';
  static const exportar = 'Exportar reporte';
  static const exportado = 'Reporte exportado';
  static const exportarSoloWeb = 'La exportación está disponible en la versión web';
  static const reintentar = 'Reintentar';

  // Roles (el backend envía USUARIO / FUNDACION / ADMINISTRADOR)
  static const rolUsuario = 'Adoptante/Usuario';
  static const rolFundacion = 'Fundación';
  static const rolAdministrador = 'Administrador';

  // Errores
  static const errorGenerico = 'No se pudieron cargar las estadísticas';
  static const errorRespuesta = 'La respuesta del servidor no es válida';
  static const errorNoAutenticado = 'Tu sesión expiró. Inicia sesión de nuevo.';
  static const errorSinPermisos = 'No tienes permisos para ver las estadísticas';

  /// "Actualizado: dd/MM/yyyy HH:mm"
  static String actualizado(DateTime fecha) =>
      'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}';

  static String fechaCorta(DateTime fecha) => DateFormat('dd/MM/yyyy').format(fecha);

  static String rolEtiqueta(String rol) {
    switch (rol) {
      case 'USUARIO':
        return rolUsuario;
      case 'FUNDACION':
        return rolFundacion;
      case 'ADMINISTRADOR':
        return rolAdministrador;
      default:
        return rol;
    }
  }
}
