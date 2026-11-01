import 'dart:async';

import 'package:flutter/material.dart';

import '../models/filtros_mascota.dart';
import '../models/mascota_detalle.dart';
import '../services/api_exception.dart';
import '../services/busqueda_mascotas_service.dart';
import '../theme/app_theme.dart';
import '../utils/foto_url.dart';
import 'filtros_mascota_panel.dart';
import 'mascota_detalle_screen.dart';

/// Lists the mascotas that can be adopted, with name search (HU08) and filters (HU09)
/// (`GET /api/mascotas/buscar`).
class MascotasDisponiblesScreen extends StatefulWidget {
  const MascotasDisponiblesScreen({super.key, this.service});

  final BusquedaMascotasService? service;

  @override
  State<MascotasDisponiblesScreen> createState() => _MascotasDisponiblesScreenState();
}

class _MascotasDisponiblesScreenState extends State<MascotasDisponiblesScreen> {
  static const _espera = Duration(milliseconds: 300);
  static const _anchoPanelFijo = 900.0;

  late final BusquedaMascotasService _service;
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  /// Cada petición lleva un número; solo la última puede actualizar la pantalla.
  int _peticion = 0;

  bool _cargando = true;
  String? _error;
  List<MascotaDetalle> _mascotas = const [];
  FiltrosMascota _filtros = FiltrosMascota.vacio;

  /// Nombre con el que se obtuvo `_mascotas` (para elegir el mensaje de vacío).
  String _nombreConsultado = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BusquedaMascotasService();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final peticion = ++_peticion;
    final nombre = _busquedaCtrl.text.trim();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mascotas = await _service.buscar(nombre: nombre, filtros: _filtros);
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _mascotas = mascotas;
        _nombreConsultado = nombre;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  /// Búsqueda en tiempo real: espera 300 ms sin teclear antes de llamar al backend.
  void _alEscribir(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_espera, _cargar);
  }

  void _limpiarBusqueda() {
    _debounce?.cancel();
    _busquedaCtrl.clear();
    _cargar();
  }

  void _aplicarFiltros(FiltrosMascota filtros) {
    _debounce?.cancel();
    setState(() => _filtros = filtros);
    _cargar();
  }

  Widget _panel({VoidCallback? alTerminar}) => FiltrosMascotaPanel(
        filtros: _filtros,
        cargarRazas: _service.razas,
        onAplicar: (f) {
          alTerminar?.call();
          _aplicarFiltros(f);
        },
        onLimpiar: () {
          alTerminar?.call();
          _aplicarFiltros(FiltrosMascota.vacio);
        },
      );

  void _abrirFiltros() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.85),
            child: _panel(alTerminar: () => Navigator.of(sheetContext).pop()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mascotas en adopción')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Pantalla ancha: panel fijo a la izquierda (como el mockup); angosta: BottomSheet.
            if (constraints.maxWidth < _anchoPanelFijo) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _buildContenido(panelFijo: false),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 280, child: _panel()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildContenido(panelFijo: true)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContenido({required bool panelFijo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraBusqueda(panelFijo: panelFijo),
        if (_filtros.hayFiltros) _chipsActivos(),
        if (!_cargando && _error == null && _mascotas.isNotEmpty) _contador(),
        Expanded(child: _buildLista()),
        const _AvisoDisponibles(),
      ],
    );
  }

  Widget _barraBusqueda({required bool panelFijo}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaCtrl,
                  onChanged: _alEscribir,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar mascota por nombre...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busquedaCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close),
                            onPressed: _limpiarBusqueda,
                          ),
                  ),
                ),
              ),
              if (!panelFijo) ...[
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _filtros.hayFiltros,
                  label: Text('${_filtros.cantidad}'),
                  child: IconButton.filledTonal(
                    tooltip: 'Filtros',
                    icon: const Icon(Icons.tune),
                    onPressed: _abrirFiltros,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'No distingue mayúsculas ni tildes',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _chipsActivos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Filtros activos:', style: Theme.of(context).textTheme.labelLarge),
          for (final f in _filtros.activos)
            InputChip(
              label: Text(f.etiqueta),
              onDeleted: () => _aplicarFiltros(_filtros.sin(f.grupo, f.valor)),
              deleteButtonTooltipMessage: 'Quitar ${f.etiqueta}',
            ),
          Text(
            'combinados con lógica Y',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _contador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Semantics(
        liveRegion: true,
        child: Text(
          textoContador(_mascotas.length),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _Mensaje(
        icon: Icons.error_outline,
        texto: _error!,
        accion: TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (_mascotas.isEmpty) {
      if (_filtros.hayFiltros) {
        return const _Mensaje(
          icon: Icons.pets_outlined,
          texto: 'No hay mascotas que coincidan con los filtros seleccionados',
        );
      }
      if (_nombreConsultado.isNotEmpty) {
        return const _Mensaje(
          icon: Icons.pets_outlined,
          texto: 'No se encontraron mascotas con ese nombre',
          subtitulo: 'Intente con otro texto o revise la ortografía',
        );
      }
      return const _Mensaje(
        icon: Icons.pets_outlined,
        texto: 'Por ahora no hay mascotas disponibles para adopción.',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _mascotas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _MascotaTile(
          mascota: _mascotas[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MascotaDetalleScreen(mascotaId: _mascotas[i].id),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso fijo al pie: la lista solo trae mascotas aprobadas y disponibles.
class _AvisoDisponibles extends StatelessWidget {
  const _AvisoDisponibles();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppPalette.mintDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Solo se muestran mascotas aprobadas y en estado «Disponible»',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotaTile extends StatelessWidget {
  const _MascotaTile({required this.mascota, required this.onTap});

  final MascotaDetalle mascota;
  final VoidCallback onTap;

  String? get _fotoUrl => resolverUrlFoto(mascota.fotoUrl ?? mascota.galeria.firstOrNull);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foto = _fotoUrl;
    const placeholder = CircleAvatar(
      radius: 32,
      backgroundColor: AppPalette.mint,
      child: Icon(Icons.pets, color: AppPalette.mintDark, size: 30),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SizedBox(
                  width: 64,
                  height: 64,
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
                      mascota.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (mascota.datosClave.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(mascota.datosClave, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icon, required this.texto, this.subtitulo, this.accion});

  final IconData icon;
  final String texto;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppPalette.mintDark),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(texto, textAlign: TextAlign.center),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 12), accion!],
          ],
        ),
      ),
    );
  }
}
