import 'dart:async';

import 'package:flutter/material.dart';

import '../config/geolocalizacion_textos.dart';
import '../models/filtros_mascota.dart';
import '../models/mascota_detalle.dart';
import '../services/api_exception.dart';
import '../services/busqueda_mascotas_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/foto_url.dart';
import '../utils/geolocalizacion.dart';
import 'filtros_mascota_panel.dart';
import 'mascota_detalle_screen.dart';
import 'perfil_screen.dart';

/// Lists the mascotas that can be adopted, with name search (HU08), filters (HU09)
/// and search by proximity (HU10) (`GET /api/mascotas/buscar`).
class MascotasDisponiblesScreen extends StatefulWidget {
  const MascotasDisponiblesScreen({
    super.key,
    this.service,
    this.ubicacionService,
    this.proveedorUbicacion,
  });

  final BusquedaMascotasService? service;

  /// HU10: para simular la ubicación del perfil y el GPS en los tests.
  final UbicacionService? ubicacionService;
  final ProveedorUbicacion? proveedorUbicacion;

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

  // ---- HU10: búsqueda por cercanía ----
  UbicacionService? _ubicacionPropia;
  UbicacionService get _ubicacionService =>
      widget.ubicacionService ?? (_ubicacionPropia ??= UbicacionService());
  ProveedorUbicacion get _proveedor => widget.proveedorUbicacion ?? const GeolocatorProveedor();

  /// Ubicación con la que se ordena; null = listado general.
  _Cercania? _cercania;
  bool _buscandoUbicacion = false;

  /// Aviso de respaldo (cuando no hay GPS) y si debe ofrecer «Ir a mi perfil».
  String? _avisoUbicacion;
  bool _avisoIrAPerfil = false;

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
    _ubicacionPropia?.dispose();
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
      final mascotas = await _service.buscar(
        nombre: nombre,
        filtros: _filtros,
        lat: _cercania?.latitud,
        lon: _cercania?.longitud,
      );
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

  // ---- HU10 ----

  /// Pide permiso (diálogo propio + aviso del navegador). Si se niega o falla, usa la ubicación del perfil.
  Future<void> _activarCercania() async {
    final permitir = await showDialog<bool>(
      context: context,
      builder: (_) => const _PermisoUbicacionDialog(),
    );
    if (permitir == null || !mounted) return; // cerró el diálogo sin elegir
    setState(() {
      _buscandoUbicacion = true;
      _avisoUbicacion = null;
      _avisoIrAPerfil = false;
    });

    if (permitir) {
      final resultado = await _proveedor.obtener();
      if (!mounted) return;
      if (resultado case UbicacionObtenida(:final latitud, :final longitud)) {
        _debounce?.cancel();
        setState(() {
          _buscandoUbicacion = false;
          _cercania = _Cercania(latitud, longitud, _OrigenUbicacion.gps);
        });
        await _cargar();
        return;
      }
    }
    await _respaldoConUbicacionDelPerfil();
  }

  /// Criterio 3: sin GPS se usa la ubicación registrada en el perfil; si no hay, se avisa y se ofrece ir al perfil.
  Future<void> _respaldoConUbicacionDelPerfil() async {
    try {
      final ubicacion = await _ubicacionService.obtener();
      if (!mounted) return;
      if (ubicacion != null) {
        _debounce?.cancel();
        setState(() {
          _buscandoUbicacion = false;
          _cercania = _Cercania(ubicacion.latitud, ubicacion.longitud, _OrigenUbicacion.perfil);
          _avisoUbicacion = GeolocalizacionTextos.avisoPerfil;
        });
        await _cargar();
      } else {
        setState(() {
          _buscandoUbicacion = false;
          _avisoUbicacion = GeolocalizacionTextos.avisoSinPerfil;
          _avisoIrAPerfil = true;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoUbicacion = false;
        _avisoUbicacion = e.message; // incluye el 401 (sesión expirada)
      });
    }
  }

  /// Criterio 4: vuelve al listado general (se conservan nombre y filtros).
  void _desactivarCercania() {
    _debounce?.cancel();
    setState(() {
      _cercania = null;
      _avisoUbicacion = null;
      _avisoIrAPerfil = false;
    });
    _cargar();
  }

  void _irAMiPerfil() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PerfilScreen()));
  }

  Widget _bloqueCercania() {
    final theme = Theme.of(context);
    final cercania = _cercania;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cercania == null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _buscandoUbicacion ? null : _activarCercania,
                icon: _buscandoUbicacion
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text(GeolocalizacionTextos.buscarCerca),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.mint.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 20, color: AppPalette.mintDark),
                  Text(
                    GeolocalizacionTextos.activa,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Chip(
                    label: Text(
                      cercania.origen == _OrigenUbicacion.gps
                          ? GeolocalizacionTextos.origenGps
                          : GeolocalizacionTextos.origenPerfil,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton.icon(
                    onPressed: _desactivarCercania,
                    icon: const Icon(Icons.location_off_outlined),
                    label: const Text(GeolocalizacionTextos.desactivar),
                  ),
                ],
              ),
            ),
          if (_avisoUbicacion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.peach.withValues(alpha: 0.35),
                border: Border.all(color: AppPalette.peachDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppPalette.peachDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_avisoUbicacion!, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                    if (_avisoIrAPerfil)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _irAMiPerfil,
                          child: const Text(GeolocalizacionTextos.irAMiPerfil),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (cercania != null) ...[
            const SizedBox(height: 8),
            Text(
              GeolocalizacionTextos.ordenadoPorDistancia,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ],
      ),
    );
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
        _bloqueCercania(),
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
          mostrarDistancia: _cercania != null,
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

enum _OrigenUbicacion { gps, perfil }

/// HU10: ubicación del usuario con la que se ordena y de dónde salió.
class _Cercania {
  const _Cercania(this.latitud, this.longitud, this.origen);

  final double latitud;
  final double longitud;
  final _OrigenUbicacion origen;
}

/// HU10 (mockup, paso 1): explica para qué se pide la ubicación antes del aviso del navegador.
/// Devuelve true = Permitir, false = Ahora no, null = cerrado sin elegir.
class _PermisoUbicacionDialog extends StatelessWidget {
  const _PermisoUbicacionDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.location_on, size: 40, color: AppPalette.peachDark),
      title: const Text(GeolocalizacionTextos.permisoTitulo, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(GeolocalizacionTextos.permisoCuerpo, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            GeolocalizacionTextos.permisoNota,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(GeolocalizacionTextos.permitir),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(GeolocalizacionTextos.ahoraNo),
        ),
      ],
    );
  }
}

class _MascotaTile extends StatelessWidget {
  const _MascotaTile({
    required this.mascota,
    required this.onTap,
    this.mostrarDistancia = false,
  });

  final MascotaDetalle mascota;
  final VoidCallback onTap;

  /// HU10: en una búsqueda por cercanía cada tarjeta muestra su distancia.
  final bool mostrarDistancia;

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
                    if (mostrarDistancia) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.mint.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppPalette.mintDark),
                        ),
                        child: Text(
                          formatearDistancia(mascota.distanciaKm),
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
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
