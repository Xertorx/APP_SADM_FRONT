import 'package:flutter/material.dart';

import '../config/postulacion_textos.dart';
import '../models/mascota_detalle.dart';
import '../models/postulacion.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/mascota_service.dart';
import '../services/postulacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/etiquetas.dart';
import 'mascota_galeria.dart';
import 'postulacion_dialog.dart';

class MascotaDetalleScreen extends StatefulWidget {
  const MascotaDetalleScreen({
    super.key,
    required this.mascotaId,
    this.mascotaService,
    this.postulacionService,
  });

  final int mascotaId;
  final MascotaService? mascotaService;
  final PostulacionService? postulacionService;

  @override
  State<MascotaDetalleScreen> createState() => _MascotaDetalleScreenState();
}

class _MascotaDetalleScreenState extends State<MascotaDetalleScreen> {
  late final MascotaService _mascotaService;
  late final PostulacionService _postulacionService;

  bool _cargando = true;
  String? _error;
  MascotaDetalle? _mascota;
  Postulacion? _postulacion;
  bool _postulacionActiva = false;

  @override
  void initState() {
    super.initState();
    _mascotaService = widget.mascotaService ?? MascotaService();
    _postulacionService = widget.postulacionService ?? PostulacionService();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.mascotaService == null) _mascotaService.dispose();
    if (widget.postulacionService == null) _postulacionService.dispose();
    super.dispose();
  }

  /// Loads the mascota and checks whether the usuario already has an active
  /// postulación for it (`GET /postulaciones/mascotas/{id}/resumen`).
  Future<void> _cargar({bool mostrarSpinner = true}) async {
    if (mostrarSpinner) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final mascota = await _mascotaService.obtenerPorId(widget.mascotaId);
      final activa = AuthSession.autenticado && await _consultarPostulacionActiva();
      if (!mounted) return;
      setState(() {
        _mascota = mascota;
        _postulacionActiva = activa;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  /// A failure here must not hide the mascota, so errors count as "no".
  Future<bool> _consultarPostulacionActiva() async {
    try {
      return await _postulacionService.tienePostulacionActiva(widget.mascotaId);
    } on ApiException {
      return false;
    }
  }

  Future<void> _solicitarAdopcion() async {
    final result = await showDialog<PostulacionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PostulacionDialog(
        mascotaId: widget.mascotaId,
        mascotaNombre: _mascota?.nombre ?? '',
        service: _postulacionService,
      ),
    );
    if (!mounted || result == null) return;

    if (result.postulacion != null) {
      setState(() => _postulacion = result.postulacion);
    }
    if (result.refrescar) await _cargar(mostrarSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(PostulacionTextos.tituloDetalle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mascota == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(_error ?? PostulacionTextos.errorGenerico, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text(PostulacionTextos.reintentar),
            ),
          ],
        ),
      );
    }

    final mascota = _mascota!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final galeria = MascotaGaleria(fotos: mascota.galeria, nombre: mascota.nombre);
          final info = _buildInfo(mascota);
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [galeria, const SizedBox(height: 20), info],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: galeria),
              const SizedBox(width: 24),
              Expanded(child: info),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfo(MascotaDetalle mascota) {
    final theme = Theme.of(context);
    final datos = <(IconData, String, String)>[
      if (mascota.especie != null)
        (Icons.category_outlined, 'Especie', humanizar(mascota.especie!)),
      if (mascota.raza != null) (Icons.badge_outlined, 'Raza', mascota.raza!),
      if (mascota.edadTexto != null) (Icons.cake_outlined, 'Edad', mascota.edadTexto!),
      if (mascota.tamano != null)
        (Icons.straighten_outlined, 'Tamaño', humanizar(mascota.tamano!)),
      if (mascota.sexo != null) (Icons.wc_outlined, 'Sexo', humanizar(mascota.sexo!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        mascota.nombre,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    EstadoChip(texto: mascota.estadoTexto, positivo: mascota.disponible),
                    if (_postulacionActiva && _postulacion == null)
                      const EstadoChip(texto: PostulacionTextos.yaTePostulaste),
                  ],
                ),
                if (datos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      for (final (icono, etiqueta, valor) in datos)
                        SizedBox(width: 150, child: _Dato(icono, etiqueta, valor)),
                    ],
                  ),
                ],
                if (mascota.ubicacion != null) ...[
                  const SizedBox(height: 14),
                  _Dato(Icons.place_outlined, 'Ubicación', mascota.ubicacion!),
                ],
                if (mascota.temperamento.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _TituloSeccion('Temperamento'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in mascota.temperamento)
                        Chip(
                          label: Text(humanizar(t)),
                          backgroundColor: AppPalette.mint,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
                if (mascota.historialSalud != null) ...[
                  const SizedBox(height: 20),
                  const _TituloSeccion('Historial de salud'),
                  const SizedBox(height: 8),
                  Text(mascota.historialSalud!, style: theme.textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildAccionPostulacion(mascota),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Volver'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: AppPalette.textDark,
            side: const BorderSide(color: AppPalette.mintDark, width: 1.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAccionPostulacion(MascotaDetalle mascota) {
    final postulacion = _postulacion;
    if (postulacion != null) {
      return _YaPostulado(postulacion: postulacion);
    }

    final String? explicacion;
    if (!AuthSession.autenticado) {
      explicacion = PostulacionTextos.requiereLogin;
    } else if (_postulacionActiva) {
      explicacion = PostulacionTextos.postulacionActiva;
    } else if (!mascota.disponible) {
      explicacion = PostulacionTextos.mascotaNoDisponible;
    } else {
      explicacion = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: explicacion == null ? _solicitarAdopcion : null,
          icon: const Icon(Icons.favorite_border),
          label: const Text(PostulacionTextos.postularme),
        ),
        if (explicacion != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              explicacion,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _YaPostulado extends StatelessWidget {
  const _YaPostulado({required this.postulacion});

  final Postulacion postulacion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.mint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.mintDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppPalette.textDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    PostulacionTextos.yaTePostulaste,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('${PostulacionTextos.estadoActual}: ${postulacion.estadoTexto}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppPalette.peachDark,
          ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.etiqueta, this.valor);

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: AppPalette.mintDark),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.textDark.withValues(alpha: 0.6),
                ),
              ),
              Text(valor, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}