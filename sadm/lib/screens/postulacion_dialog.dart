import 'package:flutter/material.dart';

import '../config/postulacion_textos.dart';
import '../models/postulacion.dart';
import '../services/api_exception.dart';
import '../services/postulacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/fecha_formato.dart';

/// What the detail screen needs to know once the dialog closes.
class PostulacionDialogResult {
  const PostulacionDialogResult({this.postulacion, this.refrescar = false});

  final Postulacion? postulacion;

  /// True when the backend said the local data was stale (duplicada / no disponible).
  final bool refrescar;
}

/// Confirmation dialog for a postulación (`POST /api/postulaciones`).
/// Closes with a [PostulacionDialogResult], or null when nothing changed.
class PostulacionDialog extends StatefulWidget {
  const PostulacionDialog({
    super.key,
    required this.mascotaId,
    required this.mascotaNombre,
    required this.service,
  });

  final int mascotaId;
  final String mascotaNombre;
  final PostulacionService service;

  @override
  State<PostulacionDialog> createState() => _PostulacionDialogState();
}

class _PostulacionDialogState extends State<PostulacionDialog> {
  bool _enviando = false;
  bool _aceptoTerminos = false;
  ApiException? _errorEnvio;
  Postulacion? _creada;
  bool _refrescar = false;

  Future<void> _confirmar() async {
    // The flag is set before any await so a second tap in the same frame is ignored.
    if (_enviando) return;
    _enviando = true;
    setState(() => _errorEnvio = null);

    try {
      final postulacion = await widget.service.crear(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _creada = postulacion;
        _enviando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEnvio = e;
        _enviando = false;
        if (e is PostulacionDuplicadaException || e is MascotaNoDisponibleException) {
          _refrescar = true;
        }
      });
    }
  }

  void _cerrar() {
    if (_enviando) return;
    final hayCambios = _creada != null || _refrescar;
    Navigator.of(context).pop(
      hayCambios ? PostulacionDialogResult(postulacion: _creada, refrescar: _refrescar) : null,
    );
  }

  /// Errors where retrying the same request cannot succeed.
  bool get _errorDefinitivo => switch (_errorEnvio) {
        PostulacionDuplicadaException() ||
        MascotaNoDisponibleException() ||
        NoAutenticadoException() ||
        SinPermisosException() =>
          true,
        _ => false,
      };

  bool get _puedeConfirmar => _aceptoTerminos && !_enviando && !_errorDefinitivo;

  @override
  Widget build(BuildContext context) {
    final exito = _creada != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: AlertDialog(
        backgroundColor: AppPalette.cream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: Text(
          exito ? PostulacionTextos.exitoTitulo : PostulacionTextos.tituloModal,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 560,
          child: exito ? _ExitoView(postulacion: _creada!) : _buildContenido(),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
        actions: exito
            ? [
                ElevatedButton(
                  style: _estiloBoton,
                  autofocus: true,
                  onPressed: _cerrar,
                  child: const Text(PostulacionTextos.cerrar),
                ),
              ]
            : [
                OutlinedButton(
                  autofocus: true,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: _enviando ? null : _cerrar,
                  child: const Text(PostulacionTextos.cancelar),
                ),
                ElevatedButton(
                  style: _estiloBoton,
                  onPressed: _puedeConfirmar ? _confirmar : null,
                  child: _enviando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppPalette.textDark,
                            semanticsLabel: PostulacionTextos.enviando,
                          ),
                        )
                      : const Text(PostulacionTextos.confirmar),
                ),
              ],
      ),
    );
  }

  static final _estiloBoton = ElevatedButton.styleFrom(
    foregroundColor: AppPalette.textDark,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );

  Widget _buildContenido() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Quieres solicitar la adopción de ${widget.mascotaNombre}?',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            PostulacionTextos.tituloProceso,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        const _EtapasCard(),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            PostulacionTextos.tituloTerminos,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        const _TerminosCard(),
        const SizedBox(height: 6),
        CheckboxListTile(
          value: _aceptoTerminos,
          onChanged: _enviando
              ? null
              : (valor) => setState(() => _aceptoTerminos = valor ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            PostulacionTextos.aceptoTerminos,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: _aceptoTerminos
              ? null
              : const Text(PostulacionTextos.debesAceptarTerminos),
        ),
        if (_errorEnvio != null) ...[
          const SizedBox(height: 8),
          _Mensaje(
            texto: _errorEnvio!.message,
            onReintentar: _errorDefinitivo ? null : _confirmar,
          ),
        ],
      ],
    );
  }
}

class _EtapasCard extends StatelessWidget {
  const _EtapasCard();

  @override
  Widget build(BuildContext context) {
    const etapas = PostulacionTextos.etapas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < etapas.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: i == 0 ? AppPalette.peach : AppPalette.mint,
                      child: Text(
                        '${etapas[i].numero}',
                        style: const TextStyle(
                          color: AppPalette.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Etapa ${etapas[i].numero} — ${etapas[i].titulo}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' · ${etapas[i].descripcion}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TerminosCard extends StatelessWidget {
  const _TerminosCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.mintDark.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < PostulacionTextos.terminos.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text(PostulacionTextos.terminos[i])),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small status pill shared by the dialog and the detail screen.
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.texto, this.positivo = true});

  final String texto;
  final bool positivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positivo ? AppPalette.mint : AppPalette.peach,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: positivo ? AppPalette.mintDark : AppPalette.peachDark),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppPalette.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Error box; announced to screen readers when it appears.
class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.onReintentar});

  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7A1C14);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5A39B)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: const TextStyle(color: color, fontWeight: FontWeight.w500)),
                  if (onReintentar != null)
                    TextButton(
                      onPressed: onReintentar,
                      style: TextButton.styleFrom(foregroundColor: color),
                      child: const Text(PostulacionTextos.reintentar),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitoView extends StatelessWidget {
  const _ExitoView({required this.postulacion});

  final Postulacion postulacion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: AppPalette.mint,
              child: Icon(Icons.check, color: AppPalette.textDark, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Fila(
                    etiqueta: PostulacionTextos.exitoFecha,
                    valor: formatearFechaHora(postulacion.fecha),
                  ),
                  const SizedBox(height: 10),
                  _Fila(
                    etiqueta: PostulacionTextos.exitoEstado,
                    valor: postulacion.estadoTexto,
                  ),
                  const SizedBox(height: 10),
                  _Fila(
                    etiqueta: PostulacionTextos.exitoPuntaje,
                    valor: '${postulacion.puntaje}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        Text('$etiqueta:', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(valor),
      ],
    );
  }
}
