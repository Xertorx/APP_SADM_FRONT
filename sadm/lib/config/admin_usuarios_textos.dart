/// Textos de la UI de administración de usuarios (HU27 + HU28).
class AdminUsuariosTextos {
  AdminUsuariosTextos._();

  // Panel
  static const accionTitulo = 'Administración de usuarios';
  static const accionDescripcion = 'Busca usuarios, consulta su actividad e inhabilita o reactiva cuentas.';

  // Búsqueda (HU27)
  static const tituloBusqueda = 'Búsqueda de usuarios';
  static const placeholderBusqueda = 'Buscar usuario por nombre...';
  static const botonBuscar = 'Buscar';
  static const botonVerDetalle = 'Ver detalle';
  static const vacio = 'No se encontraron usuarios con ese nombre';
  static const vacioAyuda = 'Verifique la ortografía o pruebe con un texto más corto';
  static const vacioFiltros = 'No hay usuarios con los filtros seleccionados';
  static const vacioFiltrosAyuda = 'Pruebe cambiando el rol o el estado';
  static const notaBusqueda = 'Coincidencia parcial · No distingue mayúsculas ni tildes';
  static const reintentar = 'Reintentar';

  // Filtros del cliente
  static const filtroRol = 'Rol';
  static const filtroEstado = 'Estado';
  static const filtroTodos = 'Todos';

  // Columnas
  static const colNombre = 'Nombre';
  static const colCorreo = 'Correo';
  static const colRol = 'Rol';
  static const colEstado = 'Estado';
  static const colRegistrado = 'Registrado';
  static const colAccion = 'Acción';

  // Detalle
  static const tituloDetalle = 'Detalle de usuario';
  static const seccionInformacion = 'Información';
  static const seccionActividad = 'Actividad en la plataforma';
  static const seccionHistorial = 'Historial de moderación';
  static const historialVacio = 'Sin inhabilitaciones ni reactivaciones';
  static const etiquetaTelefono = 'Teléfono';
  static const etiquetaDireccion = 'Dirección';
  static const etiquetaRegistrado = 'Registrado';
  static const mascotasPublicadas = 'Mascotas publicadas';
  static const postulaciones = 'Postulaciones';
  static const sinDato = 'No registrado';

  // Acciones (HU28)
  static const botonInhabilitar = 'Inhabilitar cuenta';
  static const botonReactivar = 'Reactivar cuenta';
  static const botonCancelar = 'Cancelar';
  static const campoMotivo = 'Motivo';
  static const motivoObligatorio = 'El motivo es obligatorio';
  static const motivoLongitud = 'El motivo debe tener entre 10 y 300 caracteres';
  static const exitoInhabilitada = 'Cuenta inhabilitada correctamente';
  static const exitoReactivada = 'Cuenta reactivada correctamente';
  static const inhabilitarSubtitulo = 'El usuario perderá acceso a la plataforma';
  static const consecuenciasTitulo = 'Consecuencias:';
  static const consecuenciaLogin = 'El usuario no podrá iniciar sesión';
  static const consecuenciaCatalogo = 'Si es dador, sus publicaciones se ocultarán del catálogo público';

  static String confirmarInhabilitar(String nombre) => '¿Confirmas inhabilitar la cuenta de $nombre?';

  static String encontrados(int n) => n == 1 ? '1 usuario encontrado' : '$n usuarios encontrados';

  // Errores
  static const errorGenerico = 'No se pudo completar la operación. Inténtalo de nuevo.';
  static const errorRespuesta = 'Respuesta inesperada del servidor.';
  static const errorNoAutenticado = 'Tu sesión expiró. Inicia sesión para continuar.';
  static const errorSinPermisos = 'Solo un administrador puede realizar esta acción.';
  static const errorNoExiste = 'El usuario no existe';
}
