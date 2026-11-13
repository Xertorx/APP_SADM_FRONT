/// HU10: textos de la búsqueda por geolocalización (exactos del criterio de aceptación).
class GeolocalizacionTextos {
  GeolocalizacionTextos._();

  // Botón / estado de la lista de mascotas.
  static const buscarCerca = 'Buscar cerca de mí';
  static const desactivar = 'Desactivar geolocalización';
  static const activa = 'Geolocalización activa';
  static const ordenadoPorDistancia = 'Ordenado por distancia (más cerca primero)';
  static const origenGps = 'Tu ubicación (GPS)';
  static const origenPerfil = 'Ubicación de tu perfil';

  // Diálogo previo al permiso del navegador/dispositivo (mockup, paso 1).
  static const permisoTitulo = '¿Permitir acceso a su ubicación?';
  static const permisoCuerpo = 'Le mostraremos las mascotas más cercanas a usted';
  static const permisoNota = 'Si niega el permiso, usaremos la ubicación de su perfil';
  static const permitir = 'Permitir';
  static const ahoraNo = 'Ahora no';

  // Respaldo cuando no hay GPS.
  static const avisoPerfil =
      'No pudimos acceder a tu ubicación. Mostrando resultados según tu ubicación registrada';
  static const avisoSinPerfil =
      'No pudimos acceder a tu ubicación. Registra tu ubicación de referencia en tu perfil';
  static const irAMiPerfil = 'Ir a mi perfil';

  // Distancia en la tarjeta.
  static const distanciaNoDisponible = 'Distancia no disponible';
  static const distanciaMenosDeUno = '< 1 km';

  // Perfil (ubicación de referencia) y publicación.
  static const seccionPerfil = 'Ubicación de referencia';
  static const seccionPublicacion = 'Ubicación para búsquedas cercanas (opcional)';
  static const usarUbicacionActual = 'Usar mi ubicación actual';
  static const localidad = 'Localidad';
  static const guardarUbicacion = 'Guardar ubicación';
  static const ubicacionGuardada = 'Ubicación guardada correctamente';
  static const quitarUbicacion = 'Quitar ubicación';
  static const sinUbicacion = 'Sin ubicación seleccionada';
  static const errorPermisoSelector =
      'No pudimos acceder a tu ubicación. Permite el acceso o elige una localidad.';
  static const errorNoDisponibleSelector =
      'No pudimos obtener tu ubicación. Inténtalo de nuevo o elige una localidad.';
}
