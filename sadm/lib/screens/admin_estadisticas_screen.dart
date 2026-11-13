import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/estadisticas_textos.dart';
import '../models/estadisticas.dart';
import '../services/api_exception.dart';
import '../services/estadisticas_service.dart';
import '../theme/app_theme.dart';
import '../utils/descarga_archivo.dart' as descarga;
import '../widgets/grafico_barras_roles.dart';

/// Firma de la función que entrega el archivo al usuario (inyectable en pruebas).
typedef DescargarArchivo = void Function(Uint8List bytes, String nombre, String tipo);

/// Panel de estadísticas generales para el administrador (HU30).
/// Se carga al abrir; "Actualizar" vuelve a consultar con el filtro aplicado (sin tiempo real).
class AdminEstadisticasScreen extends StatefulWidget {
  const AdminEstadisticasScreen({super.key, this.service, this.descargar});

  /// Inyectables para pruebas; por defecto cliente real y descarga del navegador.
  final EstadisticasService? service;
  final DescargarArchivo? descargar;

  @override
  State<AdminEstadisticasScreen> createState() => _AdminEstadisticasScreenState();
}

class _AdminEstadisticasScreenState extends State<AdminEstadisticasScreen> {
  late final EstadisticasService _service = widget.service ?? EstadisticasService();

  bool _cargando = true;
  bool _exportando = false;
  ApiException? _error;
  Estadisticas? _datos;

  // Fechas elegidas en el filtro (aún sin aplicar) y fechas realmente aplicadas.
  DateTime? _desde;
  DateTime? _hasta;
  DateTime? _aplicadoDesde;
  DateTime? _aplicadoHasta;
  String? _errorFiltro;

  /// Evita que una respuesta lenta pise a una consulta más reciente.
  int _consulta = 0;

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
    final numero = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.obtener(desde: _aplicadoDesde, hasta: _aplicadoHasta);
      if (!mounted || numero != _consulta) return;
      setState(() {
        _datos = datos;
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

  Future<void> _elegirFecha({required bool esDesde}) async {
    final ahora = DateTime.now();
    final actual = esDesde ? _desde : _hasta;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(ahora.year + 1, 12, 31),
      helpText: esDesde ? EstadisticasTextos.desde : EstadisticasTextos.hasta,
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (esDesde) {
        _desde = elegida;
      } else {
        _hasta = elegida;
      }
      _errorFiltro = null;
    });
  }

  void _aplicar() {
    final desde = _desde;
    final hasta = _hasta;
    if (desde != null && hasta != null && desde.isAfter(hasta)) {
      // Validación local: no se consulta al backend con un rango imposible.
      setState(() => _errorFiltro = EstadisticasTextos.errorRango);
      return;
    }
    setState(() {
      _errorFiltro = null;
      _aplicadoDesde = desde;
      _aplicadoHasta = hasta;
    });
    _cargar();
  }

  void _limpiar() {
    setState(() {
      _desde = null;
      _hasta = null;
      _aplicadoDesde = null;
      _aplicadoHasta = null;
      _errorFiltro = null;
    });
    _cargar();
  }

  Future<void> _exportar() async {
    final mensajero = ScaffoldMessenger.of(context);
    final entrega = widget.descargar ?? (descarga.descargaDisponible ? descarga.descargarArchivo : null);
    if (entrega == null) {
      mensajero.showSnackBar(const SnackBar(content: Text(EstadisticasTextos.exportarSoloWeb)));
      return;
    }
    setState(() => _exportando = true);
    try {
      final bytes = await _service.exportar(desde: _aplicadoDesde, hasta: _aplicadoHasta);
      entrega(bytes, EstadisticasService.nombreArchivo(), 'text/csv;charset=utf-8');
      mensajero.showSnackBar(const SnackBar(content: Text(EstadisticasTextos.exportado)));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(EstadisticasTextos.titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _cuerpo(context),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final theme = Theme.of(context);

    if (_cargando && _datos == null) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      final definitivo = _error is SinPermisosException || _error is NoAutenticadoException;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(_error!.message, textAlign: TextAlign.center),
              if (!definitivo)
                TextButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text(EstadisticasTextos.reintentar),
                ),
            ],
          ),
        ),
      );
    }

    final datos = _datos!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FiltroFechas(
          desde: _desde,
          hasta: _hasta,
          error: _errorFiltro,
          ocupado: _cargando,
          onDesde: () => _elegirFecha(esDesde: true),
          onHasta: () => _elegirFecha(esDesde: false),
          onAplicar: _aplicar,
          onLimpiar: _limpiar,
        ),
        const SizedBox(height: 8),
        Text(
          EstadisticasTextos.notaFiltro,
          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _Kpis(datos: datos),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EstadisticasTextos.graficoRoles,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Divider(height: 24),
                GraficoBarrasRoles(datos: datos.usuariosActivosPorRol),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text(EstadisticasTextos.actualizar),
            ),
            ElevatedButton.icon(
              onPressed: (_cargando || _exportando) ? null : _exportar,
              icon: const Icon(Icons.download_outlined),
              label: const Text(EstadisticasTextos.exportar),
            ),
            Text(
              EstadisticasTextos.actualizado(datos.generadoEn),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _FiltroFechas extends StatelessWidget {
  const _FiltroFechas({
    required this.desde,
    required this.hasta,
    required this.error,
    required this.ocupado,
    required this.onDesde,
    required this.onHasta,
    required this.onAplicar,
    required this.onLimpiar,
  });

  final DateTime? desde;
  final DateTime? hasta;
  final String? error;
  final bool ocupado;
  final VoidCallback onDesde;
  final VoidCallback onHasta;
  final VoidCallback onAplicar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _BotonFecha(etiqueta: EstadisticasTextos.desde, fecha: desde, onTap: onDesde),
                _BotonFecha(etiqueta: EstadisticasTextos.hasta, fecha: hasta, onTap: onHasta),
                ElevatedButton(
                  onPressed: ocupado ? null : onAplicar,
                  child: const Text(EstadisticasTextos.aplicar),
                ),
                TextButton(
                  onPressed: ocupado ? null : onLimpiar,
                  child: const Text(EstadisticasTextos.limpiar),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotonFecha extends StatelessWidget {
  const _BotonFecha({required this.etiqueta, required this.fecha, required this.onTap});

  final String etiqueta;
  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = fecha == null ? EstadisticasTextos.sinFecha : EstadisticasTextos.fechaCorta(fecha!);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text('$etiqueta: $texto'),
    );
  }
}

/// Fila de 4 tarjetas: 4 columnas en pantalla ancha, 2 en media y 1 en móvil.
class _Kpis extends StatelessWidget {
  const _Kpis({required this.datos});

  final Estadisticas datos;

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      _KpiCard(
        titulo: EstadisticasTextos.kpiMascotas,
        valor: datos.mascotasPublicadas,
        color: AppPalette.mintDark,
        icono: Icons.pets,
      ),
      _KpiCard(
        titulo: EstadisticasTextos.kpiAdopciones,
        valor: datos.adopcionesCompletadas.valor,
        color: AppPalette.peachDark,
        icono: Icons.home_outlined,
        disponible: datos.adopcionesCompletadas.disponible,
        notaNoDisponible: EstadisticasTextos.sinModuloAdopciones, // TODO HU20
      ),
      _KpiCard(
        titulo: EstadisticasTextos.kpiPostulaciones,
        valor: datos.postulacionesEnCurso,
        color: AppPalette.mint,
        icono: Icons.hourglass_empty,
      ),
      _KpiCard(
        titulo: EstadisticasTextos.kpiSeguimiento,
        valor: datos.adopcionesEnSeguimiento.valor,
        color: AppPalette.peach,
        icono: Icons.assignment_outlined,
        disponible: datos.adopcionesEnSeguimiento.disponible,
        notaNoDisponible: EstadisticasTextos.sinModuloSeguimiento, // TODO HU22
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho >= 900 ? 4 : (ancho >= 520 ? 2 : 1);
        const separacion = 12.0;
        final anchoTarjeta = (ancho - separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [for (final t in tarjetas) SizedBox(width: anchoTarjeta, child: t)],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.titulo,
    required this.valor,
    required this.color,
    required this.icono,
    this.disponible = true,
    this.notaNoDisponible,
  });

  final String titulo;
  final int valor;
  final Color color;
  final IconData icono;
  final bool disponible;
  final String? notaNoDisponible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No disponible → todo en gris (tono del tema, no un color fijo).
    final gris = theme.disabledColor;
    final acento = disponible ? color : gris;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: acento),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: disponible ? null : gris,
                            ),
                          ),
                        ),
                        Icon(icono, color: acento, size: 22),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      disponible ? '$valor' : '—',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: disponible ? null : gris,
                      ),
                    ),
                    if (!disponible && notaNoDisponible != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notaNoDisponible!,
                        style: theme.textTheme.bodySmall?.copyWith(color: gris, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
