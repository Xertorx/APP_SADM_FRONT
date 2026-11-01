import 'package:flutter/material.dart';

import '../models/mascota_detalle.dart';
import '../services/api_exception.dart';
import '../services/mascota_service.dart';
import '../theme/app_theme.dart';
import '../utils/foto_url.dart';
import 'mascota_form_screen.dart';

/// "Dar en adopción": the usuario's published mascotas, with access to edit
/// each one and to register a new one.
class MisMascotasScreen extends StatefulWidget {
  const MisMascotasScreen({super.key, this.service});

  final MascotaService? service;

  @override
  State<MisMascotasScreen> createState() => _MisMascotasScreenState();
}

class _MisMascotasScreenState extends State<MisMascotasScreen> {
  late final MascotaService _service;

  bool _cargando = true;
  String? _error;
  List<MascotaDetalle> _mascotas = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MascotaService();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool mostrarSpinner = true}) async {
    if (mostrarSpinner) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final mascotas = await _service.listarMias();
      if (!mounted) return;
      setState(() {
        _mascotas = mascotas;
        _error = null;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  Future<void> _registrar() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MascotaFormScreen(service: _service)),
    );
    if (mounted) await _cargar(mostrarSpinner: false);
  }

  Future<void> _editar(MascotaDetalle mascota) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MascotaFormScreen(mascotaId: mascota.id, service: _service),
      ),
    );
    if (!mounted) return;
    if (guardado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación actualizada correctamente.')),
      );
    }
    await _cargar(mostrarSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dar en adopción')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _cargar(mostrarSpinner: false),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ElevatedButton.icon(
            onPressed: _registrar,
            icon: const Icon(Icons.add),
            label: const Text('Registrar nueva mascota'),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Mis mascotas publicadas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            _Mensaje(
              icon: Icons.error_outline,
              texto: _error!,
              accion: TextButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            )
          else if (_mascotas.isEmpty)
            const _Mensaje(
              icon: Icons.pets_outlined,
              texto: 'Aún no has publicado mascotas.',
            )
          else
            for (final mascota in _mascotas) ...[
              _MascotaTile(mascota: mascota, onEditar: () => _editar(mascota)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _MascotaTile extends StatelessWidget {
  const _MascotaTile({required this.mascota, required this.onEditar});

  final MascotaDetalle mascota;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foto = resolverUrlFoto(mascota.fotoUrl ?? mascota.galeria.firstOrNull);
    const placeholder = CircleAvatar(
      radius: 32,
      backgroundColor: AppPalette.mint,
      child: Icon(Icons.pets, color: AppPalette.mintDark, size: 30),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEditar,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          mascota.nombre,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (mascota.estado.isNotEmpty)
                          Text(mascota.estadoTexto, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (mascota.datosClave.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(mascota.datosClave, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar ${mascota.nombre}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEditar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icon, required this.texto, this.accion});

  final IconData icon;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppPalette.mintDark),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(texto, textAlign: TextAlign.center),
          ),
          if (accion != null) ...[const SizedBox(height: 12), accion!],
        ],
      ),
    );
  }
}
