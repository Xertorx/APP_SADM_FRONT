import 'package:flutter/material.dart';

import '../config/geolocalizacion_textos.dart';
import '../models/ubicacion.dart';
import '../services/api_exception.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/geolocalizacion.dart';

/// HU10: bloque para elegir una ubicación: botón «Usar mi ubicación actual» (GPS) o desplegable
/// «Localidad». Lo usan «Ubicación de referencia» (perfil) y el formulario de publicación.
/// No guarda nada: avisa con [onChanged] y quien lo usa decide qué hacer con la ubicación.
class SelectorUbicacion extends StatefulWidget {
  const SelectorUbicacion({
    super.key,
    required this.ubicacion,
    required this.onChanged,
    this.enabled = true,
    this.permitirQuitar = false,
    this.cargarLocalidadesAlInicio = false,
    this.service,
    this.proveedor,
  });

  final Ubicacion? ubicacion;
  final ValueChanged<Ubicacion?> onChanged;
  final bool enabled;

  /// Muestra «Quitar ubicación» (útil cuando la ubicación es opcional).
  final bool permitirQuitar;

  /// Carga las localidades al abrir (para mostrar el nombre de la guardada); si no, solo al abrir el desplegable.
  final bool cargarLocalidadesAlInicio;

  final UbicacionService? service;
  final ProveedorUbicacion? proveedor;

  @override
  State<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<SelectorUbicacion> {
  UbicacionService? _servicioPropio;
  UbicacionService get _service => widget.service ?? (_servicioPropio ??= UbicacionService());
  ProveedorUbicacion get _proveedor => widget.proveedor ?? const GeolocatorProveedor();

  List<Localidad>? _localidades;
  bool _cargandoLocalidades = false;
  bool _obteniendoGps = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    if (widget.cargarLocalidadesAlInicio) _cargarLocalidades();
  }

  @override
  void dispose() {
    _servicioPropio?.dispose();
    super.dispose();
  }

  Future<bool> _cargarLocalidades() async {
    if (_localidades != null) return true;
    setState(() {
      _cargandoLocalidades = true;
      _mensaje = null;
    });
    try {
      final lista = await _service.localidades();
      if (!mounted) return false;
      setState(() {
        _localidades = lista;
        _cargandoLocalidades = false;
      });
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() {
        _cargandoLocalidades = false;
        _mensaje = e.message;
      });
      return false;
    }
  }

  Future<void> _usarGps() async {
    setState(() {
      _obteniendoGps = true;
      _mensaje = null;
    });
    final resultado = await _proveedor.obtener();
    if (!mounted) return;
    setState(() {
      _obteniendoGps = false;
      _mensaje = switch (resultado) {
        UbicacionObtenida() => null,
        PermisoNegado() => GeolocalizacionTextos.errorPermisoSelector,
        UbicacionNoDisponible() => GeolocalizacionTextos.errorNoDisponibleSelector,
      };
    });
    if (resultado case UbicacionObtenida(:final latitud, :final longitud)) {
      widget.onChanged(Ubicacion(latitud: latitud, longitud: longitud));
    }
  }

  Future<void> _elegirLocalidad() async {
    if (!await _cargarLocalidades() || !mounted) return;
    final elegida = await showModalBottomSheet<Localidad>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final l in _localidades!)
                ListTile(
                  title: Text(l.nombre),
                  selected: l.codigo == widget.ubicacion?.localidad,
                  onTap: () => Navigator.of(sheetContext).pop(l),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) widget.onChanged(elegida.aUbicacion());
  }

  String _resumen() {
    final ubicacion = widget.ubicacion;
    if (ubicacion == null) return GeolocalizacionTextos.sinUbicacion;
    final codigo = ubicacion.localidad;
    if (codigo != null) {
      final nombre = _localidades?.where((l) => l.codigo == codigo).firstOrNull?.nombre;
      return '${GeolocalizacionTextos.localidad}: ${nombre ?? codigo}';
    }
    return 'GPS: ${ubicacion.latitud.toStringAsFixed(3)}, ${ubicacion.longitud.toStringAsFixed(3)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activo = widget.enabled && !_obteniendoGps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20, color: AppPalette.mintDark),
            const SizedBox(width: 8),
            Expanded(child: Text(_resumen(), style: theme.textTheme.bodyMedium)),
            if (widget.permitirQuitar && widget.ubicacion != null)
              TextButton(
                onPressed: widget.enabled ? () => widget.onChanged(null) : null,
                child: const Text(GeolocalizacionTextos.quitarUbicacion),
              ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: activo ? _usarGps : null,
          icon: _obteniendoGps
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: const Text(GeolocalizacionTextos.usarUbicacionActual),
        ),
        const SizedBox(height: 10),
        // Desplegable «Localidad»: las localidades se piden al abrirlo.
        InkWell(
          onTap: widget.enabled && !_cargandoLocalidades ? _elegirLocalidad : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: GeolocalizacionTextos.localidad,
              prefixIcon: const Icon(Icons.map_outlined, size: 20),
              suffixIcon: _cargandoLocalidades
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _nombreLocalidadElegida() ?? '',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
        if (_mensaje != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(_mensaje!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ],
    );
  }

  String? _nombreLocalidadElegida() {
    final codigo = widget.ubicacion?.localidad;
    if (codigo == null) return null;
    return _localidades?.where((l) => l.codigo == codigo).firstOrNull?.nombre ?? codigo;
  }
}
