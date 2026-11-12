import 'package:flutter/material.dart';

import '../config/mis_postulaciones_textos.dart';
import '../models/mi_postulacion.dart';

/// Situación de un segmento de la barra de progreso.
enum SegmentoEtapa { completada, actual, pendiente, descartada }

/// Calcula la situación de cada etapa (1..[total]) según el estado.
/// - activa: antes de la actual ✓, la actual ▶, el resto pendiente.
/// - ganadora: todas ✓.
/// - descartada: antes de la etapa donde quedó ✓, esa con ✕, el resto pendiente.
List<SegmentoEtapa> segmentosDeProgreso({
  required EstadoMiPostulacion estado,
  required int etapaActual,
  int total = 4,
}) {
  return List.generate(total, (i) {
    final numero = i + 1;
    switch (estado) {
      case EstadoMiPostulacion.ganadora:
        return SegmentoEtapa.completada;
      case EstadoMiPostulacion.activa:
        if (numero < etapaActual) return SegmentoEtapa.completada;
        if (numero == etapaActual) return SegmentoEtapa.actual;
        return SegmentoEtapa.pendiente;
      case EstadoMiPostulacion.descartada:
        if (numero < etapaActual) return SegmentoEtapa.completada;
        if (numero == etapaActual) return SegmentoEtapa.descartada;
        return SegmentoEtapa.pendiente;
    }
  });
}

/// Barra de 4 pasos con el nombre de cada etapa.
class ProgresoEtapas extends StatelessWidget {
  const ProgresoEtapas({
    super.key,
    required this.estado,
    required this.etapaActual,
    this.total = 4,
  });

  final EstadoMiPostulacion estado;
  final int etapaActual;
  final int total;

  @override
  Widget build(BuildContext context) {
    final segmentos = segmentosDeProgreso(estado: estado, etapaActual: etapaActual, total: total);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segmentos.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _Segmento(numero: i + 1, tipo: segmentos[i])),
        ],
      ],
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({required this.numero, required this.tipo});

  final int numero;
  final SegmentoEtapa tipo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color fondo, Color texto, String simbolo) = switch (tipo) {
      SegmentoEtapa.completada => (scheme.primary, scheme.onPrimary, '✓'),
      SegmentoEtapa.actual => (scheme.secondaryContainer, scheme.onSecondaryContainer, '▶'),
      SegmentoEtapa.descartada => (scheme.error, scheme.onError, '✕'),
      SegmentoEtapa.pendiente => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, ''),
    };

    return Column(
      children: [
        Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            simbolo.isEmpty ? '$numero' : '$simbolo $numero',
            style: textTheme.labelLarge?.copyWith(color: texto, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MisPostulacionesTextos.nombreEtapa(numero),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: tipo == SegmentoEtapa.actual ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
