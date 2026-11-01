import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/detalle_mascota_textos.dart';
import '../models/dador_publico.dart';
import '../services/api_exception.dart';
import '../services/dador_service.dart';
import '../theme/app_theme.dart';

/// Sección "Publicado por" del detalle de mascota: nombre, foto y fecha de registro del dador,
/// sin datos de contacto.
class DadorCard extends StatefulWidget {
  const DadorCard({super.key, required this.usuarioId, this.service});

  final int usuarioId;
  final DadorService? service;

  @override
  State<DadorCard> createState() => _DadorCardState();
}

class _DadorCardState extends State<DadorCard> {
  late final DadorService _service;

  bool _cargando = true;
  String? _error;
  DadorPublico? _dador;
  Uint8List? _foto;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DadorService();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final dador = await _service.obtener(widget.usuarioId);
      // La foto es opcional: si falla, igual se muestra el resto de los datos.
      Uint8List? foto;
      if (dador.tieneFoto) {
        try {
          foto = await _service.descargarFoto(widget.usuarioId);
        } on ApiException {
          foto = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _dador = dador;
        _foto = foto;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ConnectionException || e is ServerException
            ? DetalleMascotaTextos.errorDador
            : e.message;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                DetalleMascotaTextos.publicadoPor,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.peachDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _contenido(theme),
          ],
        ),
      ),
    );
  }

  Widget _contenido(ThemeData theme) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    final dador = _dador;
    if (dador == null) {
      return Semantics(liveRegion: true, child: Text(_error ?? DetalleMascotaTextos.errorDador));
    }

    final miembroDesde = dador.miembroDesdeTexto;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppPalette.mint,
          backgroundImage: _foto == null ? null : MemoryImage(_foto!),
          child: _foto == null ? const Icon(Icons.person, size: 32, color: AppPalette.mintDark) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dador.nombreCompleto,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (miembroDesde != null)
                Text(
                  miembroDesde,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppPalette.textDark.withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.mint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.mintDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: AppPalette.textDark),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DetalleMascotaTextos.notaContacto,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
