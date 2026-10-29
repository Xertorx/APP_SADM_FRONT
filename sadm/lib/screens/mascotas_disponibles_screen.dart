import 'package:flutter/material.dart';

import '../models/mascota_detalle.dart';
import '../services/api_exception.dart';
import '../services/mascota_service.dart';
import '../theme/app_theme.dart';
import '../utils/foto_url.dart';
import 'mascota_detalle_screen.dart';

/// Lists every mascota that can be adopted (`GET /api/mascotas`).
class MascotasDisponiblesScreen extends StatefulWidget {
  const MascotasDisponiblesScreen({super.key, this.service});

  final MascotaService? service;

  @override
  State<MascotasDisponiblesScreen> createState() => _MascotasDisponiblesScreenState();
}

class _MascotasDisponiblesScreenState extends State<MascotasDisponiblesScreen> {
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

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mascotas = await _service.listarDisponibles();
      if (!mounted) return;
      setState(() {
        _mascotas = mascotas;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mascotas en adopción')),
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
  const _Mensaje({required this.icon, required this.texto, this.accion});

  final IconData icon;
  final String texto;
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
            if (accion != null) ...[const SizedBox(height: 12), accion!],
          ],
        ),
      ),
    );
  }
}
