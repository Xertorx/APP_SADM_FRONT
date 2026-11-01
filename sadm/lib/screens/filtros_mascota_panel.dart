import 'package:flutter/material.dart';

import '../models/filtros_mascota.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../utils/etiquetas.dart';

/// Panel de filtros de HU09 (especie, raza, edad, tamaño, temperamento).
///
/// Trabaja sobre un borrador: nada se envía hasta pulsar "Aplicar filtros".
/// Se usa como columna lateral en pantallas anchas y dentro de un BottomSheet en las angostas.
class FiltrosMascotaPanel extends StatefulWidget {
  const FiltrosMascotaPanel({
    super.key,
    required this.filtros,
    required this.cargarRazas,
    required this.onAplicar,
    required this.onLimpiar,
  });

  /// Filtros hoy aplicados; si cambian desde fuera (chip ✕) el borrador se sincroniza.
  final FiltrosMascota filtros;

  /// Razas de la especie dada (`GET /api/mascotas/razas`).
  final Future<List<String>> Function(String especie) cargarRazas;

  final ValueChanged<FiltrosMascota> onAplicar;
  final VoidCallback onLimpiar;

  @override
  State<FiltrosMascotaPanel> createState() => _FiltrosMascotaPanelState();
}

class _FiltrosMascotaPanelState extends State<FiltrosMascotaPanel> {
  late FiltrosMascota _borrador;
  List<String> _razas = const [];
  bool _cargandoRazas = false;
  String? _errorRazas;
  int _peticionRazas = 0;

  @override
  void initState() {
    super.initState();
    _borrador = widget.filtros;
    _actualizarRazas();
  }

  @override
  void didUpdateWidget(FiltrosMascotaPanel anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.filtros != widget.filtros) {
      setState(() => _borrador = widget.filtros);
      _actualizarRazas();
    }
  }

  Set<String> _alternar(Set<String> actual, String valor, bool marcado) =>
      marcado ? {...actual, valor} : ({...actual}..remove(valor));

  void _cambiarEspecie(String valor, bool marcado) {
    setState(() => _borrador = _borrador.copyWith(especies: _alternar(_borrador.especies, valor, marcado)));
    _actualizarRazas();
  }

  /// Carga las razas solo si hay exactamente una especie; ignora respuestas viejas.
  Future<void> _actualizarRazas() async {
    final peticion = ++_peticionRazas;
    if (!_borrador.permiteRaza) {
      setState(() {
        _razas = const [];
        _cargandoRazas = false;
        _errorRazas = null;
      });
      return;
    }
    setState(() {
      _cargandoRazas = true;
      _errorRazas = null;
    });
    try {
      final razas = await widget.cargarRazas(_borrador.especies.first);
      if (!mounted || peticion != _peticionRazas) return;
      setState(() {
        _razas = razas;
        _cargandoRazas = false;
      });
    } on ApiException catch (e) {
      if (!mounted || peticion != _peticionRazas) return;
      setState(() {
        _razas = const [];
        _cargandoRazas = false;
        _errorRazas = e.message;
      });
    }
  }

  void _limpiar() {
    setState(() => _borrador = FiltrosMascota.vacio);
    _actualizarRazas();
    widget.onLimpiar();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Filtros',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Seccion('Especie', [
                  for (final v in especiesFiltro)
                    _Casilla(
                      etiqueta: humanizar(v),
                      marcada: _borrador.especies.contains(v),
                      onChanged: (m) => _cambiarEspecie(v, m),
                    ),
                ]),
                _Seccion('Raza', [_selectorRaza(theme)]),
                _Seccion('Edad', [
                  for (final v in edadesFiltro)
                    _Casilla(
                      etiqueta: edadEtiquetaConRango(v),
                      marcada: _borrador.edades.contains(v),
                      onChanged: (m) => setState(
                        () => _borrador = _borrador.copyWith(edades: _alternar(_borrador.edades, v, m)),
                      ),
                    ),
                ]),
                _Seccion('Tamaño', [
                  for (final v in tamanosFiltro)
                    _Casilla(
                      etiqueta: humanizar(v),
                      marcada: _borrador.tamanos.contains(v),
                      onChanged: (m) => setState(
                        () => _borrador = _borrador.copyWith(tamanos: _alternar(_borrador.tamanos, v, m)),
                      ),
                    ),
                ]),
                _Seccion('Temperamento', [
                  for (final v in temperamentosFiltro)
                    _Casilla(
                      etiqueta: humanizar(v),
                      marcada: _borrador.temperamentos.contains(v),
                      onChanged: (m) => setState(
                        () => _borrador = _borrador.copyWith(
                          temperamentos: _alternar(_borrador.temperamentos, v, m),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: _limpiar, child: const Text('Limpiar filtros')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onAplicar(_borrador),
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectorRaza(ThemeData theme) {
    if (!_borrador.permiteRaza) {
      return DropdownButtonFormField<String>(
        key: const ValueKey('raza-deshabilitada'),
        items: const [],
        onChanged: null,
        decoration: const InputDecoration(hintText: 'Elige una sola especie'),
      );
    }
    // Si la raza aplicada ya no está en la lista (datos cambiaron) no se ofrece como valor.
    final valor = _razas.contains(_borrador.raza) ? _borrador.raza : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('raza-${_borrador.especies.first}-${_razas.length}-$valor'),
          initialValue: valor,
          isExpanded: true,
          items: [for (final r in _razas) DropdownMenuItem(value: r, child: Text(r))],
          onChanged: _cargandoRazas ? null : (r) => setState(() => _borrador = _borrador.copyWith(raza: r)),
          decoration: InputDecoration(
            hintText: _cargandoRazas ? 'Cargando razas...' : 'Todas las razas',
            suffixIcon: valor == null
                ? null
                : IconButton(
                    tooltip: 'Quitar raza',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _borrador = _borrador.copyWith(raza: null)),
                  ),
          ),
        ),
        if (_errorRazas != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorRazas!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        if (!_cargandoRazas && _errorRazas == null && _razas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No hay razas registradas para esta especie.', style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo, this.hijos);

  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppPalette.mintDark,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          ...hijos,
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.etiqueta, required this.marcada, required this.onChanged});

  final String etiqueta;
  final bool marcada;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(etiqueta),
      value: marcada,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}
