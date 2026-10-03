import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'adoptante_form_screen.dart';
import 'mascota_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SADM - Adopción de mascotas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppPalette.mint,
                    child: Icon(Icons.pets, color: AppPalette.mintDark, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bienvenido a SADM',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Qué quieres hacer hoy?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdoptanteFormScreen()),
                    ),
                    child: const Text('Registrar adoptante'),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MascotaFormScreen()),
                    ),
                    child: const Text('Publicar mascota'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
