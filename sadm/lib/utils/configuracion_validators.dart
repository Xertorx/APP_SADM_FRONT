import '../models/configuracion_seleccion.dart';

/// Validaciones de la configuración del proceso de selección (HU12).
///
/// Replican las reglas del backend para avisar antes de enviar: puntajes entre 0 y
/// [puntajeTotalSeleccion], al menos un elemento por etapa, elementos que no superan el
/// máximo de su etapa y máximos de etapa que suman exactamente 100.
class ConfiguracionValidators {
  ConfiguracionValidators._();

  /// Validador de campos de texto numéricos para un puntaje.
  static String? puntaje(String? value) {
    final texto = value?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresa un puntaje';
    final numero = int.tryParse(texto);
    if (numero == null) return 'Ingresa un número entero';
    if (numero < 0) return 'El puntaje no puede ser negativo';
    if (numero > puntajeTotalSeleccion) {
      return 'El puntaje no puede superar $puntajeTotalSeleccion';
    }
    return null;
  }

  static String? textoObligatorio(String? value, {required String campo, int max = 500}) {
    final texto = value?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresa $campo';
    if (texto.length > max) return 'Máximo $max caracteres';
    return null;
  }

  /// Opciones de una pregunta de selección: al menos dos y distintas.
  static String? opciones(TipoRespuesta tipo, List<String> opciones) {
    if (!tipo.requiereOpciones) return null;
    final limpias = opciones.map((o) => o.trim().toLowerCase()).toList();
    if (limpias.any((o) => o.isEmpty)) return 'Las opciones no pueden estar vacías';
    if (limpias.length < 2) return 'Agrega al menos dos opciones';
    if (limpias.toSet().length != limpias.length) return 'Las opciones deben ser distintas';
    return null;
  }

  /// Errores de una etapa; vacío si está correcta.
  static List<String> etapa(
    EtapaSeleccion etapa,
    DatosEtapa<ElementoSeleccion> datos, {
    bool exigirElementos = true,
  }) {
    final nombre = etapa.nombreLargo;
    final maximo = datos.puntajeMaximo;
    final errores = <String>[];

    if (maximo < 0) {
      errores.add('$nombre: el puntaje máximo no puede ser negativo.');
    } else if (maximo > puntajeTotalSeleccion) {
      errores.add('$nombre: el puntaje máximo no puede superar $puntajeTotalSeleccion.');
    }

    if (datos.elementos.isEmpty) {
      if (exigirElementos) errores.add('$nombre: agrega al menos un criterio.');
      return errores;
    }

    for (final elemento in datos.elementos) {
      if (elemento.puntaje < 0) {
        errores.add('$nombre: "${elemento.titulo}" tiene un puntaje negativo.');
      } else if (elemento.puntaje > maximo) {
        errores.add(
          '$nombre: "${elemento.titulo}" (${elemento.puntaje} pts) supera el máximo de la '
          'etapa ($maximo pts).',
        );
      }
      if (elemento is PreguntaSeleccion) {
        final error = opciones(elemento.tipoRespuesta, elemento.opciones);
        if (error != null) errores.add('$nombre: "${elemento.titulo}": $error.');
      }
    }

    final asignado = datos.puntajeAsignado;
    if (asignado > maximo && datos.elementos.every((e) => e.puntaje <= maximo)) {
      errores.add('$nombre: los criterios suman $asignado pts y superan el máximo de la etapa '
          '($maximo pts).');
    }
    return errores;
  }

  /// Errores de la distribución global de puntos.
  static List<String> distribucion(ConfiguracionSeleccion config) {
    if (config.puntosPendientes > 0) {
      return [
        'Faltan ${config.puntosPendientes} puntos por distribuir: los máximos de las etapas '
            'deben sumar exactamente $puntajeTotalSeleccion.',
      ];
    }
    if (config.puntosExcedentes > 0) {
      return [
        'Hay ${config.puntosExcedentes} puntos de más: los máximos de las etapas deben sumar '
            'exactamente $puntajeTotalSeleccion.',
      ];
    }
    return const [];
  }

  /// Errores de una configuración que se quiere guardar como borrador (sin exigir las
  /// reglas de completitud): puntajes fuera de rango, elementos sobre el máximo y opciones.
  static List<String> paraGuardar(ConfiguracionSeleccion config) => [
        for (final (:etapa, :datos) in config.etapas)
          ...ConfiguracionValidators.etapa(etapa, datos, exigirElementos: false),
      ];

  /// Todos los errores que impiden finalizar. Vacío si la configuración está completa.
  static List<String> paraFinalizar(ConfiguracionSeleccion config) => [
        for (final (:etapa, :datos) in config.etapas) ...ConfiguracionValidators.etapa(etapa, datos),
        ...distribucion(config),
      ];
}
