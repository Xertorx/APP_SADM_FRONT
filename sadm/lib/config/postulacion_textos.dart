/// Centralized UI copy for the postulación flow (HU13).
class PostulacionTextos {
  PostulacionTextos._();

  // Detalle de mascota
  static const tituloDetalle = 'Detalle de mascota';
  static const postularme = 'Solicitar adopción';
  static const yaTePostulaste = 'Ya te postulaste';
  static const postulacionActiva = 'Ya tienes una postulación activa para esta mascota.';
  static const estadoActual = 'Estado actual';
  static const puntajeActual = 'Puntaje';
  static const mascotaNoDisponible =
      'Esta mascota no está disponible para postulaciones en este momento.';
  static const requiereLogin = 'Inicia sesión para postularte.';

  // Modal de confirmación
  static const tituloModal = 'Confirmar postulación';
  static const confirmar = 'Confirmar postulación';
  static const enviando = 'Enviando postulación';
  static const cancelar = 'Cancelar';
  static const cerrar = 'Cerrar';
  static const reintentar = 'Reintentar';
  static const avisoDuplicada =
      'No podrá postularse de nuevo a esta misma mascota mientras su postulación esté activa.';

  // Resumen del proceso (se muestra dentro del modal)
  static const tituloProceso = 'Resumen del proceso de adopción';
  static const etapas = [
    (numero: 1, titulo: 'Evaluación inicial', descripcion: 'Revisión del perfil y entrevista'),
    (numero: 2, titulo: 'Visita al hogar', descripcion: 'Verificación del entorno'),
    (numero: 3, titulo: 'Decisión final', descripcion: 'Selección del adoptante'),
  ];

  // Términos y condiciones
  static const tituloTerminos = 'Términos y condiciones';
  static const terminos = [
    'Postularse no garantiza la adopción: cada solicitud pasa por las etapas de evaluación indicadas.',
    'La información de tu perfil debe ser veraz; datos falsos pueden ser causa de rechazo.',
    'Aceptas participar en la entrevista y permitir la visita al hogar.',
    'Si la adopción se aprueba, te comprometes a brindar alimentación, atención veterinaria y un trato digno, y a no vender, ceder ni abandonar a la mascota.',
    avisoDuplicada,
    'Tus datos personales se usarán únicamente para gestionar el proceso de adopción.',
  ];
  static const aceptoTerminos = 'Acepto los términos y condiciones';
  static const debesAceptarTerminos =
      'Debes aceptar los términos y condiciones para confirmar.';

  // Confirmación
  static const exitoTitulo = '¡Postulación registrada!';
  static const exitoFecha = 'Fecha de postulación';
  static const exitoEstado = 'Estado';
  static const exitoPuntaje = 'Puntaje';

  // Errores
  static const errorDuplicada = 'Ya te has postulado a esta mascota';
  static const errorNoDisponible = 'Esta mascota ya no está disponible';
  static const errorNoAutenticado = 'Tu sesión expiró. Inicia sesión para continuar.';
  static const errorSinPermisos = 'No tienes permisos para postularte a esta mascota.';
  static const errorGenerico =
      'No pudimos registrar tu postulación. Inténtalo de nuevo.';
  static const errorRespuesta = 'Respuesta inesperada del servidor.';
}
