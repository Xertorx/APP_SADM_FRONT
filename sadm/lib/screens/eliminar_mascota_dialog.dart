import 'package:flutter/material.dart';

import '../models/mascota_eliminacion.dart';
import '../services/api_exception.dart';
import '../services/mascota_eliminacion_service.dart';
import '../theme/app_theme.dart';

/// Rule of the confirm button: the checkbox is required only when the mascota
/// has active postulaciones, and nothing can be sent while a request is running.
bool puedeConfirmarEliminacion({
  required int postulacionesActivas,
  required bool casillaMarcada,
  required bool enviando,
}) {
  if (enviando) return false;
  return postulacionesActivas == 0 || casillaMarcada;
}

/// Confirmation dialog to delete a publicación (`DELETE /api/mascotas/{id}`).
/// Closes with `true` when the publicación was deleted, `false`/null otherwise.
class EliminarMascotaDialog extends StatefulWidget {
  const EliminarMascotaDialog({
    super.key,
    required this.mascotaId,
    required this.service,
  });

  final int mascotaId;
  final MascotaEliminacionService service;

  @override
  State<EliminarMascotaDialog> createState() => _EliminarMascotaDialogState();
}

class _EliminarMascotaDialogState extends State<EliminarMascotaDialog> {
  bool _cargando = true;
  bool _enviando = false;
  bool _casilla = false;
  MascotaEliminacion? _datos;
  ApiException? _errorCarga;
  ApiException? _errorEnvio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final datos = await widget.service.consultar(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e;
        _cargando = false;
      });
    }
  }

  Future<void> _confirmar() async {
    // Set before any await so a second tap in the same frame is ignored.
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      await widget.service.eliminar(widget.mascotaId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEnvio = e;
        _enviando = false;
      });
    }
  }

  void _cancelar() {
    if (_enviando) return;
    Navigator.of(context).pop(false);
  }

  /// Retrying cannot succeed on these errors.
  bool get _errorDefinitivo => switch (_errorEnvio) {
        NotFoundException() || SinPermisosException() || NoAutenticadoException() => true,
        _ => false,
      };

  bool get _puedeConfirmar {
    final datos = _datos;
    if (datos == null || _errorDefinitivo) return false;
    return puedeConfirmarEliminacion(
      postulacionesActivas: datos.postulacionesActivas,
      casillaMarcada: _casilla,
      enviando: _enviando,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final datos = _datos;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelar();
      },
      child: AlertDialog(
        backgroundColor: AppPalette.cream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: _cargando
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : datos == null
                  ? _ErrorCarga(error: _errorCarga!, onReintentar: _cargar)
                  : _Contenido(
                      datos: datos,
                      casilla: _casilla,
                      enviando: _enviando,
                      errorEnvio: _errorEnvio,
                      onCasilla: (valor) => setState(() => _casilla = valor),
                    ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              disabledBackgroundColor: scheme.error.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: _puedeConfirmar ? _confirmar : null,
            child: _enviando
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.onError,
                      semanticsLabel: 'Eliminando publicación',
                    ),
                  )
                : const Text('Sí, eliminar publicación'),
          ),
          OutlinedButton(
            autofocus: true,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.textDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: _enviando ? null : _cancelar,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.datos,
    required this.casilla,
    required this.enviando,
    required this.errorEnvio,
    required this.onCasilla,
  });

  final MascotaEliminacion datos;
  final bool casilla;
  final bool enviando;
  final ApiException? errorEnvio;
  final ValueChanged<bool> onCasilla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = datos.postulacionesActivas;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: scheme.error,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.errorContainer,
                  child: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      '¿Estás seguro de que deseas eliminar a ${datos.nombre}?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Esta acción no se puede deshacer', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TarjetaMascota(datos: datos),
        if (n > 0) ...[
          const SizedBox(height: 16),
          _Advertencia(
            texto: 'Esta mascota tiene $n postulaciones activas. '
                'Si continúas, los candidatos serán notificados',
          ),
        ],
        const SizedBox(height: 16),
        _ListaConsecuencias(postulacionesActivas: n),
        if (n > 0)
          CheckboxListTile(
            value: casilla,
            onChanged: enviando ? null : (valor) => onCasilla(valor ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Entiendo que esta acción no se puede deshacer y notificará a los adoptantes en curso',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (errorEnvio != null) ...[
          const SizedBox(height: 8),
          _MensajeError(texto: errorEnvio!.message),
        ],
      ],
    );
  }
}

class _TarjetaMascota extends StatelessWidget {
  const _TarjetaMascota({required this.datos});

  final MascotaEliminacion datos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foto = datos.fotoUrl;
    const placeholder = ColoredBox(
      color: AppPalette.mint,
      child: Center(child: Icon(Icons.pets, color: AppPalette.mintDark, size: 32)),
    );
    final detalle = [
      if (datos.datosClave.isNotEmpty) datos.datosClave,
      ?datos.publicadaHace(),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: foto == null
                    ? placeholder
                    : Image.network(
                        foto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datos.nombre,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (detalle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Advertencia extends StatelessWidget {
  const _Advertencia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.peach.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.peachDark),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppPalette.textDark, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaConsecuencias extends StatelessWidget {
  const _ListaConsecuencias({required this.postulacionesActivas});

  final int postulacionesActivas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = postulacionesActivas;

    Widget fila(IconData icono, String texto) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 18, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(child: Text(texto)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Al confirmar:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            fila(Icons.close, 'La publicación se retirará del listado público inmediatamente'),
            if (n > 0) ...[
              fila(Icons.close, 'Las $n postulaciones activas quedarán en estado «Cancelada por el dador»'),
              fila(Icons.mail_outline, 'Los adoptantes serán notificados de la cancelación'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.error),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.error, required this.onReintentar});

  final ApiException error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final definitivo = error is NotFoundException ||
        error is SinPermisosException ||
        error is NoAutenticadoException;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MensajeError(texto: error.message),
        if (!definitivo)
          TextButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
      ],
    );
  }
}
