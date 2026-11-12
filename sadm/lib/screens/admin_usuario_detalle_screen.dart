import 'package:flutter/material.dart';

import '../config/admin_usuarios_textos.dart';
import '../models/usuario_admin.dart';
import '../services/admin_usuarios_service.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import 'inhabilitar_cuenta_dialog.dart';

/// Detalle de un usuario para el administrador (HU27) con inhabilitar / reactivar (HU28).
class AdminUsuarioDetalleScreen extends StatefulWidget {
  const AdminUsuarioDetalleScreen({
    super.key,
    required this.usuarioId,
    this.service,
  });

  final int usuarioId;

  /// Inyectable para pruebas; por defecto crea el cliente real.
  final AdminUsuariosService? service;

  @override
  State<AdminUsuarioDetalleScreen> createState() => _AdminUsuarioDetalleScreenState();
}

class _AdminUsuarioDetalleScreenState extends State<AdminUsuarioDetalleScreen> {
  late final AdminUsuariosService _service = widget.service ?? AdminUsuariosService();

  bool _cargando = true;
  bool _reactivando = false;
  UsuarioAdminDetalle? _detalle;
  ApiException? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final detalle = await _service.detalle(widget.usuarioId);
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
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

  void _aviso(String texto, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? scheme.error : AppPalette.mintDark,
        ),
      );
  }

  Future<void> _inhabilitar() async {
    final detalle = _detalle;
    if (detalle == null) return;
    final actualizado = await showDialog<UsuarioAdminDetalle>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InhabilitarCuentaDialog(usuario: detalle.usuario, service: _service),
    );
    if (!mounted || actualizado == null) return;
    setState(() => _detalle = actualizado);
    _aviso(AdminUsuariosTextos.exitoInhabilitada);
  }

  Future<void> _reactivar() async {
    final detalle = _detalle;
    // Se marca antes del await para ignorar un segundo toque.
    if (detalle == null || _reactivando) return;
    setState(() => _reactivando = true);
    try {
      final actualizado = await _service.reactivar(detalle.usuario.id);
      if (!mounted) return;
      setState(() {
        _detalle = actualizado;
        _reactivando = false;
      });
      _aviso(AdminUsuariosTextos.exitoReactivada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _reactivando = false);
      _aviso(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detalle == null
              ? AdminUsuariosTextos.tituloDetalle
              : 'Detalle · ${detalle.usuario.nombreCompleto}',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : detalle == null
                    ? _ErrorCarga(error: _errorCarga!, onReintentar: _cargar)
                    : _Contenido(
                        detalle: detalle,
                        reactivando: _reactivando,
                        onInhabilitar: _inhabilitar,
                        onReactivar: _reactivar,
                      ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.detalle,
    required this.reactivando,
    required this.onInhabilitar,
    required this.onReactivar,
  });

  final UsuarioAdminDetalle detalle;
  final bool reactivando;
  final VoidCallback onInhabilitar;
  final VoidCallback onReactivar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = detalle.usuario;

    Widget titulo(String texto) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              texto.toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );

    final accion = detalle.accionDisponible;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: AppPalette.mint.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppPalette.mint,
                  child: Icon(
                    detalle.tieneFoto ? Icons.account_circle : Icons.person_outline,
                    color: AppPalette.mintDark,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nombreCompleto,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(u.correo, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          EtiquetaRol(rol: u.rol),
                          EtiquetaEstado(estado: u.estado),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        titulo(AdminUsuariosTextos.seccionInformacion),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Dato(
                  AdminUsuariosTextos.etiquetaTelefono,
                  detalle.telefono.isEmpty ? AdminUsuariosTextos.sinDato : detalle.telefono,
                ),
                _Dato(
                  AdminUsuariosTextos.etiquetaDireccion,
                  detalle.direccion.isEmpty ? AdminUsuariosTextos.sinDato : detalle.direccion,
                ),
                _Dato(
                  AdminUsuariosTextos.etiquetaRegistrado,
                  formatearFechaCorta(u.fechaRegistro).isEmpty
                      ? AdminUsuariosTextos.sinDato
                      : formatearFechaCorta(u.fechaRegistro),
                ),
              ],
            ),
          ),
        ),
        titulo(AdminUsuariosTextos.seccionActividad),
        Row(
          children: [
            Expanded(
              child: _Contador(
                valor: detalle.mascotasPublicadas,
                etiqueta: AdminUsuariosTextos.mascotasPublicadas,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Contador(
                valor: detalle.postulaciones,
                etiqueta: AdminUsuariosTextos.postulaciones,
              ),
            ),
          ],
        ),
        titulo(AdminUsuariosTextos.seccionHistorial),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: detalle.historial.isEmpty
                ? Text(
                    AdminUsuariosTextos.historialVacio,
                    style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in detalle.historial) _FilaHistorial(item: h),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        if (accion == AccionCuenta.inhabilitar)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: onInhabilitar,
            icon: const Icon(Icons.block),
            label: const Text(AdminUsuariosTextos.botonInhabilitar),
          ),
        if (accion == AccionCuenta.reactivar)
          ElevatedButton.icon(
            onPressed: reactivando ? null : onReactivar,
            icon: reactivando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            label: const Text(AdminUsuariosTextos.botonReactivar),
          ),
      ],
    );
  }
}

/// Etiqueta de rol (Usuario / Fundación / Administrador).
class EtiquetaRol extends StatelessWidget {
  const EtiquetaRol({super.key, required this.rol});

  final String rol;

  @override
  Widget build(BuildContext context) =>
      _Etiqueta(texto: rolTexto(rol), fondo: AppPalette.peach.withValues(alpha: 0.6));
}

/// Etiqueta de estado: "Activo" (menta) o "Inhabilitado" (color de error del tema).
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inhabilitado = estado.toUpperCase() == estadoInhabilitado;
    return _Etiqueta(
      texto: estadoTexto(estado),
      fondo: inhabilitado ? scheme.errorContainer : AppPalette.mint,
      colorTexto: inhabilitado ? scheme.onErrorContainer : AppPalette.textDark,
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.fondo, this.colorTexto});

  final String texto;
  final Color fondo;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorTexto ?? AppPalette.textDark,
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$etiqueta:', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$valor',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.mintDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(etiqueta, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.item});

  final ModeracionHistorial item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motivo = item.motivo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.esInhabilitacion ? Icons.block : Icons.refresh,
            size: 18,
            color: item.esInhabilitacion ? scheme.error : AppPalette.mintDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.accionTexto} por ${item.adminNombre}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (motivo != null && motivo.isNotEmpty) Text('Motivo: $motivo'),
                Text(
                  formatearFechaHoraCorta(item.fecha),
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final definitivo = error is NotFoundException ||
        error is SinPermisosException ||
        error is NoAutenticadoException;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 40),
          const SizedBox(height: 12),
          Text(error.message, textAlign: TextAlign.center),
          if (!definitivo)
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text(AdminUsuariosTextos.reintentar),
            ),
        ],
      ),
    );
  }
}
