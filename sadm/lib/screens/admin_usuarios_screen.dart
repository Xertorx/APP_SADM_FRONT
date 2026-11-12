import 'package:flutter/material.dart';

import '../config/admin_usuarios_textos.dart';
import '../models/usuario_admin.dart';
import '../services/admin_usuarios_service.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import 'admin_usuario_detalle_screen.dart';

/// Búsqueda de usuarios para el administrador (HU27).
/// Pantalla ancha: tabla. Pantalla angosta: tarjetas. La búsqueda se lanza con el botón o con Enter.
class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key, this.service});

  /// Inyectable para pruebas; por defecto crea el cliente real.
  final AdminUsuariosService? service;

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  /// Desde este ancho se muestra la tabla; por debajo, tarjetas.
  static const _anchoTabla = 760.0;

  static const _roles = <String?, String>{
    null: AdminUsuariosTextos.filtroTodos,
    'USUARIO': 'Usuario',
    'FUNDACION': 'Fundación',
    'ADMINISTRADOR': 'Administrador',
  };
  static const _estados = <String?, String>{
    null: AdminUsuariosTextos.filtroTodos,
    estadoActivo: 'Activo',
    estadoInhabilitado: 'Inhabilitado',
  };

  late final AdminUsuariosService _service = widget.service ?? AdminUsuariosService();
  final _busquedaCtrl = TextEditingController();

  bool _cargando = true;
  List<UsuarioAdmin> _usuarios = const [];
  ApiException? _error;
  String? _filtroRol;
  String? _filtroEstado;

  /// Evita que una respuesta lenta pise a una búsqueda más reciente.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final numero = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuarios = await _service.buscar(_busquedaCtrl.text);
      if (!mounted || numero != _consulta) return;
      setState(() {
        _usuarios = usuarios;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || numero != _consulta) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  void _limpiar() {
    _busquedaCtrl.clear();
    _buscar();
  }

  Future<void> _verDetalle(UsuarioAdmin usuario) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUsuarioDetalleScreen(usuarioId: usuario.id, service: widget.service),
      ),
    );
    // Al volver el estado pudo cambiar (inhabilitar / reactivar): se refresca la lista.
    if (mounted) _buscar();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = filtrarUsuarios(_usuarios, rol: _filtroRol, estado: _filtroEstado);

    return Scaffold(
      appBar: AppBar(title: const Text(AdminUsuariosTextos.tituloBusqueda)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BarraBusqueda(
                    controller: _busquedaCtrl,
                    habilitado: !_cargando,
                    onBuscar: _buscar,
                    onLimpiar: _limpiar,
                  ),
                  const SizedBox(height: 12),
                  _Filtros(
                    rol: _filtroRol,
                    estado: _filtroEstado,
                    roles: _roles,
                    estados: _estados,
                    onRol: (v) => setState(() => _filtroRol = v),
                    onEstado: (v) => setState(() => _filtroEstado = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _cuerpo(context, visibles)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, List<UsuarioAdmin> visibles) {
    final theme = Theme.of(context);

    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      final definitivo = _error is SinPermisosException || _error is NoAutenticadoException;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!.message, textAlign: TextAlign.center),
            if (!definitivo)
              TextButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.refresh),
                label: const Text(AdminUsuariosTextos.reintentar),
              ),
          ],
        ),
      );
    }

    if (visibles.isEmpty) {
      // Sin coincidencias del backend vs. todo descartado por los filtros del cliente.
      final porFiltros = _usuarios.isNotEmpty;
      return _Vacio(
        titulo: porFiltros ? AdminUsuariosTextos.vacioFiltros : AdminUsuariosTextos.vacio,
        ayuda: porFiltros ? AdminUsuariosTextos.vacioFiltrosAyuda : AdminUsuariosTextos.vacioAyuda,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${AdminUsuariosTextos.notaBusqueda} · ${AdminUsuariosTextos.encontrados(visibles.length)}',
          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= _anchoTabla
                ? _Tabla(usuarios: visibles, onVer: _verDetalle)
                : _Tarjetas(usuarios: visibles, onVer: _verDetalle),
          ),
        ),
      ],
    );
  }
}

class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({
    required this.controller,
    required this.habilitado,
    required this.onBuscar,
    required this.onLimpiar,
  });

  final TextEditingController controller;
  final bool habilitado;
  final VoidCallback onBuscar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, valor, _) => TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => habilitado ? onBuscar() : null,
              decoration: InputDecoration(
                hintText: AdminUsuariosTextos.placeholderBusqueda,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: valor.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close),
                        onPressed: habilitado ? onLimpiar : null,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          onPressed: habilitado ? onBuscar : null,
          child: const Text(AdminUsuariosTextos.botonBuscar),
        ),
      ],
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.rol,
    required this.estado,
    required this.roles,
    required this.estados,
    required this.onRol,
    required this.onEstado,
  });

  final String? rol;
  final String? estado;
  final Map<String?, String> roles;
  final Map<String?, String> estados;
  final ValueChanged<String?> onRol;
  final ValueChanged<String?> onEstado;

  @override
  Widget build(BuildContext context) {
    Widget combo(String etiqueta, String? valor, Map<String?, String> opciones, ValueChanged<String?> alCambiar) {
      return SizedBox(
        width: 220,
        child: DropdownButtonFormField<String?>(
          initialValue: valor,
          isExpanded: true,
          decoration: InputDecoration(labelText: etiqueta),
          items: [
            for (final e in opciones.entries)
              DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: alCambiar,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        combo(AdminUsuariosTextos.filtroRol, rol, roles, onRol),
        combo(AdminUsuariosTextos.filtroEstado, estado, estados, onEstado),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.usuarios, required this.onVer});

  final List<UsuarioAdmin> usuarios;
  final ValueChanged<UsuarioAdmin> onVer;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(AppPalette.mint.withValues(alpha: 0.4)),
            columns: const [
              DataColumn(label: Text(AdminUsuariosTextos.colNombre)),
              DataColumn(label: Text(AdminUsuariosTextos.colCorreo)),
              DataColumn(label: Text(AdminUsuariosTextos.colRol)),
              DataColumn(label: Text(AdminUsuariosTextos.colEstado)),
              DataColumn(label: Text(AdminUsuariosTextos.colRegistrado)),
              DataColumn(label: Text(AdminUsuariosTextos.colAccion)),
            ],
            rows: [
              for (final u in usuarios)
                DataRow(
                  cells: [
                    DataCell(Text(u.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(u.correo)),
                    DataCell(EtiquetaRol(rol: u.rol)),
                    DataCell(EtiquetaEstado(estado: u.estado)),
                    DataCell(Text(formatearFechaCorta(u.fechaRegistro))),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () => onVer(u),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text(AdminUsuariosTextos.botonVerDetalle),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas({required this.usuarios, required this.onVer});

  final List<UsuarioAdmin> usuarios;
  final ValueChanged<UsuarioAdmin> onVer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: usuarios.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final u = usuarios[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombreCompleto,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(u.correo, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EtiquetaRol(rol: u.rol),
                    EtiquetaEstado(estado: u.estado),
                    Text(
                      '${AdminUsuariosTextos.colRegistrado}: ${formatearFechaCorta(u.fechaRegistro)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => onVer(u),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(AdminUsuariosTextos.botonVerDetalle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.titulo, required this.ayuda});

  final String titulo;
  final String ayuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 72, color: AppPalette.mintDark),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            ayuda,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
