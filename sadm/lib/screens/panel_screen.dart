import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'mascota_form_screen.dart';
import 'mascotas_disponibles_screen.dart';

/// Authenticated area: a usuario can adopt as well as give pets up for adoption.
class PanelScreen extends StatelessWidget {
  const PanelScreen({super.key});

  void _cerrarSesion(BuildContext context) {
    AuthSession.limpiar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi panel'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '¿Qué quieres hacer hoy?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _AccionCard(
                  icon: Icons.favorite_border,
                  titulo: 'Adoptar una mascota',
                  descripcion: 'Mira las mascotas disponibles y postúlate para adoptar una.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MascotasDisponiblesScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _AccionCard(
                  icon: Icons.volunteer_activism_outlined,
                  titulo: 'Dar en adopción',
                  descripcion: 'Publica una mascota para que encuentre un nuevo hogar.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MascotaFormScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccionCard extends StatelessWidget {
  const _AccionCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppPalette.mint,
                child: Icon(icon, color: AppPalette.mintDark, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(descripcion, style: theme.textTheme.bodyMedium),
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
