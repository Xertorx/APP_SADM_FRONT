import 'package:flutter/material.dart';

import '../config/geolocalizacion_textos.dart';
import '../models/ubicacion.dart';
import '../services/api_exception.dart';
import '../services/ubicacion_service.dart';
import '../utils/geolocalizacion.dart';
import 'selector_ubicacion.dart';

/// HU10: sección «Ubicación de referencia» de «Mi perfil». Se guarda aparte del resto del perfil
/// (`PUT /api/perfil/ubicacion`) y es la ubicación de respaldo cuando el usuario niega el GPS.
class UbicacionReferenciaSeccion extends StatefulWidget {
  const UbicacionReferenciaSeccion({
    super.key,
    required this.onSesionExpirada,
    this.service,
    this.proveedor,
  });

  /// Se llama con el mensaje cuando el backend responde 401.
  final void Function(String mensaje) onSesionExpirada;
  final UbicacionService? service;
  final ProveedorUbicacion? proveedor;

  @override
  State<UbicacionReferenciaSeccion> createState() => _UbicacionReferenciaSeccionState();
}

enum _Estado { cargando, idle, guardando }

class _UbicacionReferenciaSeccionState extends State<UbicacionReferenciaSeccion> {
  UbicacionService? _servicioPropio;
  UbicacionService get _service => widget.service ?? (_servicioPropio ??= UbicacionService());

  _Estado _estado = _Estado.cargando;
  Ubicacion? _guardada;
  Ubicacion? _elegida;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _servicioPropio?.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = _Estado.cargando;
      _error = null;
    });
    try {
      final ubicacion = await _service.obtener();
      if (!mounted) return;
      setState(() {
        _guardada = ubicacion;
        _elegida = ubicacion;
        _estado = _Estado.idle;
      });
    } on NoAutenticadoException catch (e) {
      widget.onSesionExpirada(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _Estado.idle;
        _error = e.message;
      });
    }
  }

  bool get _hayCambios {
    final elegida = _elegida;
    final guardada = _guardada;
    if (elegida == null) return false;
    if (guardada == null) return true;
    return elegida.latitud != guardada.latitud ||
        elegida.longitud != guardada.longitud ||
        elegida.localidad != guardada.localidad;
  }

  Future<void> _guardar() async {
    final elegida = _elegida;
    if (elegida == null || _estado == _Estado.guardando) return;
    setState(() {
      _estado = _Estado.guardando;
      _error = null;
    });
    try {
      final guardada = await _service.guardar(elegida);
      if (!mounted) return;
      setState(() {
        _guardada = guardada;
        _elegida = guardada;
        _estado = _Estado.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(GeolocalizacionTextos.ubicacionGuardada)),
      );
    } on NoAutenticadoException catch (e) {
      widget.onSesionExpirada(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _Estado.idle;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guardando = _estado == _Estado.guardando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GeolocalizacionTextos.seccionPerfil,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Se usa para ordenar las mascotas por cercanía cuando no podemos acceder a tu GPS.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_estado == _Estado.cargando)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else ...[
          SelectorUbicacion(
            ubicacion: _elegida,
            enabled: !guardando,
            cargarLocalidadesAlInicio: true,
            service: widget.service ?? _service,
            proveedor: widget.proveedor,
            onChanged: (u) => setState(() {
              _elegida = u;
              _error = null;
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: guardando || !_hayCambios ? null : _guardar,
              child: guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(GeolocalizacionTextos.guardarUbicacion),
            ),
          ),
        ],
      ],
    );
  }
}
