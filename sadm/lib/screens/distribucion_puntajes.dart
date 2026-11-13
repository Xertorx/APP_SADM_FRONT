import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/configuracion_seleccion.dart';
import '../theme/app_theme.dart';
import '../utils/configuracion_validators.dart';

/// Color con el que se identifica cada etapa en la barra y en la leyenda.
Color colorDeEtapa(EtapaSeleccion etapa) => switch (etapa) {
      EtapaSeleccion.preguntas => AppPalette.mintDark,
      EtapaSeleccion.documentos => AppPalette.peachDark,
      EtapaSeleccion.entrevista => const Color(0xFF7E9CC9),
      EtapaSeleccion.visita => const Color(0xFFB589C9),
    };

/// Indicador de la distribución de los 100 puntos entre las cuatro etapas, con el máximo
/// editable de cada una y el total, los puntos pendientes o los excedentes.
class DistribucionPuntajes extends StatelessWidget {
  const DistribucionPuntajes({
    super.key,
    required this.config,
    required this.onCambiarMaximo,
    this.habilitado = true,
  });

  final ConfiguracionSeleccion config;
  final void Function(EtapaSeleccion etapa, int puntaje) onCambiarMaximo;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = config.puntajeDistribuido;
    final completo = total == puntajeTotalSeleccion;
    final colorEstado = completo
        ? AppPalette.mintDark
        : config.puntosExcedentes > 0
            ? theme.colorScheme.error
            : AppPalette.peachDark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Distribución de puntos',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Text(
                  '$total / $puntajeTotalSeleccion',
                  key: const Key('total-distribuido'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorEstado,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BarraDistribucion(config: config),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    completo ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                    color: colorEstado,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      key: const Key('estado-distribucion'),
                      completo
                          ? 'Distribución completa: 100 puntos asignados.'
                          : config.puntosExcedentes > 0
                              ? 'Excedentes: ${config.puntosExcedentes} pts de más'
                              : 'Pendientes: ${config.puntosPendientes} pts por distribuir',
                      style: TextStyle(color: colorEstado, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 28),
            Text('Puntaje máximo por etapa', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final (:etapa, :datos) in config.etapas)
              _FilaEtapa(
                etapa: etapa,
                valor: datos.puntajeMaximo,
                habilitado: habilitado,
                onChanged: (v) => onCambiarMaximo(etapa, v),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarraDistribucion extends StatelessWidget {
  const _BarraDistribucion({required this.config});

  final ConfiguracionSeleccion config;

  @override
  Widget build(BuildContext context) {
    final pendientes = config.puntosPendientes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: AppPalette.mint.withValues(alpha: 0.35),
          border: config.puntosExcedentes > 0
              ? Border.all(color: Theme.of(context).colorScheme.error, width: 2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            for (final (:etapa, :datos) in config.etapas)
              if (datos.puntajeMaximo > 0)
                Expanded(
                  flex: datos.puntajeMaximo,
                  child: Tooltip(
                    message: '${etapa.titulo}: ${datos.puntajeMaximo} pts',
                    child: ColoredBox(color: colorDeEtapa(etapa)),
                  ),
                ),
            if (pendientes > 0) Spacer(flex: pendientes),
          ],
        ),
      ),
    );
  }
}

class _FilaEtapa extends StatefulWidget {
  const _FilaEtapa({
    required this.etapa,
    required this.valor,
    required this.habilitado,
    required this.onChanged,
  });

  final EtapaSeleccion etapa;
  final int valor;
  final bool habilitado;
  final ValueChanged<int> onChanged;

  @override
  State<_FilaEtapa> createState() => _FilaEtapaState();
}

class _FilaEtapaState extends State<_FilaEtapa> {
  late final _controller = TextEditingController(text: widget.valor.toString());

  @override
  void didUpdateWidget(covariant _FilaEtapa oldWidget) {
    super.didUpdateWidget(oldWidget);
    final escrito = _controller.text.trim().isEmpty ? 0 : int.tryParse(_controller.text);
    if (escrito != widget.valor && widget.valor != oldWidget.valor) {
      _controller.text = widget.valor.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cambio(String texto) {
    final valor = texto.trim().isEmpty ? 0 : int.tryParse(texto);
    if (valor != null) widget.onChanged(valor);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final error = ConfiguracionValidators.puntaje(_controller.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: colorDeEtapa(widget.etapa), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.etapa.nombreLargo)),
              SizedBox(
                width: 96,
                child: Semantics(
                  label: 'Puntaje máximo de ${widget.etapa.nombreLargo}',
                  child: TextField(
                    key: Key('maximo-${widget.etapa.name}'),
                    controller: _controller,
                    enabled: widget.habilitado,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,4}'))],
                    onChanged: _cambio,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: 'pts',
                      enabledBorder: error == null ? null : _bordeError(context),
                      focusedBorder: error == null ? null : _bordeError(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  OutlineInputBorder _bordeError(BuildContext context) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.6),
      );
}
