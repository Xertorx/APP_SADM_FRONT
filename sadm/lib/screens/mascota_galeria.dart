import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/foto_url.dart';

/// Large main photo plus a thumbnail strip. Handles an empty list and photos
/// that fail to load.
class MascotaGaleria extends StatefulWidget {
  const MascotaGaleria({super.key, required this.fotos, required this.nombre});

  final List<String> fotos;
  final String nombre;

  @override
  State<MascotaGaleria> createState() => _MascotaGaleriaState();
}

class _MascotaGaleriaState extends State<MascotaGaleria> {
  int _seleccionada = 0;

  @override
  Widget build(BuildContext context) {
    final fotos = widget.fotos;
    final indice = _seleccionada < fotos.length ? _seleccionada : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: 'Foto principal de ${widget.nombre}',
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: fotos.isEmpty
                  ? const _FotoNoDisponible(mensaje: 'Sin fotos disponibles')
                  : _Foto(url: fotos[indice], fit: BoxFit.cover),
            ),
          ),
        ),
        if (fotos.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < fotos.length; i++)
                _Miniatura(
                  url: fotos[i],
                  seleccionada: i == indice,
                  onTap: () => setState(() => _seleccionada = i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url, required this.seleccionada, required this.onTap});

  final String url;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? AppPalette.peachDark : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: _Foto(url: url, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resuelta = resolverUrlFoto(url);
    if (resuelta == null) return const _FotoNoDisponible();

    return Image.network(
      resuelta,
      fit: fit,
      loadingBuilder: (context, child, progreso) {
        if (progreso == null) return child;
        return const ColoredBox(
          color: AppPalette.mint,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        );
      },
      errorBuilder: (_, _, _) => const _FotoNoDisponible(),
    );
  }
}

class _FotoNoDisponible extends StatelessWidget {
  const _FotoNoDisponible({this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.mint.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: AppPalette.mintDark, size: 36),
            if (mensaje != null) ...[
              const SizedBox(height: 8),
              Text(mensaje!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
