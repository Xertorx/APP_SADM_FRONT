import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/mis_postulaciones_textos.dart';
import '../models/mi_postulacion.dart';
import '../services/api_exception.dart';
import '../services/mis_postulaciones_service.dart';
import '../utils/foto_url.dart';
import 'mascota_detalle_screen.dart';
import 'mascotas_disponibles_screen.dart';
import 'progreso_etapas.dart';

/// HU21: "Mis postulaciones" del adoptante autenticado.
class MisPostulacionesScreen extends StatefulWidget {
  const MisPostulacionesScreen({super.key, this.service});

  final MisPostulacionesService? service;

  @override
  State<MisPostulacionesScreen> createState() => _MisPostulacionesScreenState();
}

class _MisPostulacionesScreenState extends State<MisPostulacionesScreen>
    with SingleTickerProviderStateMixin {
  late final MisPostulacionesService _service;
  late final TabController _tabs;

  bool _cargando = true;
  String? _error;
  List<MiPostulacion> _todas = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MisPostulacionesService();
    _tabs = TabController(length: 4, vsync: this)..addListener(_alCambiarPestana);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  // Redibuja cuando cambia la pestaña (filtra la lista ya cargada, sin otra petición).
  void _alCambiarPestana() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar({bool mostrarSpinner = true}) async {
    if (mostrarSpinner) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final lista = await _service.listar();
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _error = null;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  List<MiPostulacion> get _filtradas => switch (_tabs.index) {
        1 => _todas.where((p) => p.esActiva).toList(),
        2 => _todas.where((p) => p.esGanadora).toList(),
        3 => _todas.where((p) => p.esDescartada).toList(),
        _ => _todas,
      };

  int _contar(bool Function(MiPostulacion) test) => _todas.where(test).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(MisPostulacionesTextos.titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _cuerpo(context),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _EstadoError(mensaje: _error!, onReintentar: _cargar);
    if (_todas.isEmpty) return const _EstadoVacio();

    final lista = _filtradas;
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _pestana(MisPostulacionesTextos.pestanaTodas, _todas.length),
            _pestana(MisPostulacionesTextos.pestanaActivas, _contar((p) => p.esActiva)),
            _pestana(MisPostulacionesTextos.pestanaGanadora, _contar((p) => p.esGanadora)),
            _pestana(MisPostulacionesTextos.pestanaDescartadas, _contar((p) => p.esDescartada)),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _cargar(mostrarSpinner: false),
            child: lista.isEmpty
                ? ListView(
                    // Scrollable para que el pull-to-refresh funcione también sin filas.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      Text(
                        MisPostulacionesTextos.sinResultadosFiltro,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _TarjetaPostulacion(postulacion: lista[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Tab _pestana(String texto, int cantidad) => Tab(text: '$texto $cantidad');
}

class _TarjetaPostulacion extends StatelessWidget {
  const _TarjetaPostulacion({required this.postulacion});

  final MiPostulacion postulacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = postulacion;

    final tarjeta = Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: p.esGanadora
            ? BorderSide(color: scheme.primary, width: 2)
            : p.esDescartada
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Miniatura(fotoPath: p.fotoPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.mascotaNombre,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${MisPostulacionesTextos.publicadoPor} ${p.dadorNombre}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${MisPostulacionesTextos.proceso}: ${p.nombreProceso}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ChipEstado(estado: p.estado),
              ],
            ),
            const SizedBox(height: 14),
            _EncabezadoProgreso(postulacion: p),
            const SizedBox(height: 8),
            ProgresoEtapas(
              estado: p.estado,
              etapaActual: p.etapaActual,
              total: p.totalEtapas,
            ),
            const SizedBox(height: 12),
            // TODO HU12: mostrar "N / máximo" cuando el dador configure el puntaje máximo.
            Text(
              '${MisPostulacionesTextos.puntajeAcumulado}: ${p.puntaje}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (p.esDescartada && (p.estadoDetalle?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                '${MisPostulacionesTextos.motivo}: ${p.estadoDetalle}',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            // TODO HU14-HU16 / HU20: avisos y botones por etapa ("Continuar etapa",
            // "Abrir chat", "Ver notificación"). Por ahora solo "Ver detalle".
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MascotaDetalleScreen(mascotaId: p.mascotaId),
                  ),
                ),
                child: const Text(MisPostulacionesTextos.verDetalle),
              ),
            ),
          ],
        ),
      ),
    );

    // Descartada: tarjeta atenuada.
    return p.esDescartada ? Opacity(opacity: 0.75, child: tarjeta) : tarjeta;
  }
}

class _EncabezadoProgreso extends StatelessWidget {
  const _EncabezadoProgreso({required this.postulacion});

  final MiPostulacion postulacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = postulacion;

    final String izquierda;
    if (p.esGanadora) {
      izquierda = '${MisPostulacionesTextos.progreso}: ${MisPostulacionesTextos.procesoCompletado}';
    } else if (p.esDescartada) {
      izquierda = MisPostulacionesTextos.descartadaEnEtapa(p.etapaActual);
    } else {
      izquierda =
          '${MisPostulacionesTextos.etapaActual}: ${p.etapaActual} · ${MisPostulacionesTextos.nombreEtapa(p.etapaActual)}';
    }

    // Descartada: fecha de la última actualización; el resto: "Etapa N de 4".
    final String derecha = p.esDescartada
        ? (p.fechaActualizacion == null
            ? ''
            : DateFormat('dd/MM/yyyy').format(p.fechaActualizacion!.toLocal()))
        : MisPostulacionesTextos.etapaNDeTotal(p.etapaActual, p.totalEtapas);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(izquierda, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 8),
        Text(derecha, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});

  final EstadoMiPostulacion estado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String texto, Color fondo, Color letra) = switch (estado) {
      EstadoMiPostulacion.activa => (
          MisPostulacionesTextos.estadoActiva,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      EstadoMiPostulacion.ganadora => (
          MisPostulacionesTextos.estadoGanadora,
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      EstadoMiPostulacion.descartada => (
          MisPostulacionesTextos.estadoDescartada,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: letra, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.fotoPath});

  final String? fotoPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = resolverUrlFoto(fotoPath);
    final icono = Icon(Icons.pets, color: scheme.onSurfaceVariant);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: url == null
            ? icono
            : Image.network(
                url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => icono,
              ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReintentar,
              child: const Text(MisPostulacionesTextos.reintentar),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              MisPostulacionesTextos.vacioTitulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              MisPostulacionesTextos.vacioSubtitulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MascotasDisponiblesScreen()),
              ),
              child: const Text(MisPostulacionesTextos.verMascotas),
            ),
          ],
        ),
      ),
    );
  }
}
