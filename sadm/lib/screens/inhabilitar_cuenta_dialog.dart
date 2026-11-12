import 'package:flutter/material.dart';

import '../config/admin_usuarios_textos.dart';
import '../models/usuario_admin.dart';
import '../services/admin_usuarios_service.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../utils/admin_validators.dart';

/// Confirmación para inhabilitar una cuenta (HU28), con motivo obligatorio.
/// Se cierra con el [UsuarioAdminDetalle] actualizado si se inhabilitó, o con `null` si se canceló.
class InhabilitarCuentaDialog extends StatefulWidget {
  const InhabilitarCuentaDialog({
    super.key,
    required this.usuario,
    required this.service,
  });

  final UsuarioAdmin usuario;
  final AdminUsuariosService service;

  @override
  State<InhabilitarCuentaDialog> createState() => _InhabilitarCuentaDialogState();
}

class _InhabilitarCuentaDialogState extends State<InhabilitarCuentaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  bool _enviando = false;
  ApiException? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    // Se marca antes de cualquier await para ignorar un segundo toque en el mismo frame.
    if (_enviando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final detalle = await widget.service.inhabilitar(widget.usuario.id, _motivoCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop(detalle);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _enviando = false;
      });
    }
  }

  void _cancelar() {
    if (_enviando) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
          width: 520,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.errorContainer,
                        child: Icon(Icons.block, color: scheme.error, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              AdminUsuariosTextos.confirmarInhabilitar(widget.usuario.nombreCompleto),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AdminUsuariosTextos.inhabilitarSubtitulo,
                            style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.usuario.correo} · ${rolTexto(widget.usuario.rol)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivoCtrl,
                  enabled: !_enviando,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: AdminValidators.motivoMax,
                  textInputAction: TextInputAction.newline,
                  validator: AdminValidators.motivo,
                  decoration: const InputDecoration(
                    labelText: AdminUsuariosTextos.campoMotivo,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AdminUsuariosTextos.consecuenciasTitulo,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      _Consecuencia(texto: AdminUsuariosTextos.consecuenciaLogin),
                      _Consecuencia(texto: AdminUsuariosTextos.consecuenciaCatalogo),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
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
                              _error!.message,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
            onPressed: _enviando ? null : _confirmar,
            child: _enviando
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.onError,
                      semanticsLabel: 'Inhabilitando cuenta',
                    ),
                  )
                : const Text(AdminUsuariosTextos.botonInhabilitar),
          ),
          OutlinedButton(
            autofocus: true,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.textDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: _enviando ? null : _cancelar,
            child: const Text(AdminUsuariosTextos.botonCancelar),
          ),
        ],
      ),
    );
  }
}

class _Consecuencia extends StatelessWidget {
  const _Consecuencia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
