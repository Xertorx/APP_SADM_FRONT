import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'panel_screen.dart';
import 'registro_screen.dart';

/// Public landing page: explains what SADM is and offers login / sign-up.
/// Every other feature requires an authenticated session.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SADM')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _Hero(),
                const SizedBox(height: 20),
                _AccesoButtons(
                  onLogin: () => _abrir(context, const LoginScreen()),
                  onRegistro: () => _abrir(context, const RegistroScreen()),
                  onPanel: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PanelScreen()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionHeading('¿Qué es SADM?'),
                const SizedBox(height: 8),
                Text(
                  'SADM es una plataforma que conecta a personas que quieren dar '
                  'una mascota en adopción con personas dispuestas a darle un '
                  'hogar. Con una sola cuenta puedes publicar mascotas, '
                  'postularte para adoptar y seguir el proceso paso a paso.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const _Beneficios(),
                const SizedBox(height: 32),
                const _SectionHeading('Nuestra comunidad'),
                const SizedBox(height: 12),
                const _Galeria(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Para usar una imagen propia: declarar el asset en pubspec.yaml y
          // reemplazar este contenedor por Image.asset(...).
          const _ImagePlaceholder(
            height: 180,
            icon: Icons.pets,
            label: 'Imagen principal',
          ),
          const SizedBox(height: 20),
          Text(
            'Dale un hogar a quien más lo necesita',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Adopta o da en adopción de forma segura y responsable.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _AccesoButtons extends StatelessWidget {
  const _AccesoButtons({
    required this.onLogin,
    required this.onRegistro,
    required this.onPanel,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegistro;
  final VoidCallback onPanel;

  @override
  Widget build(BuildContext context) {
    if (AuthSession.autenticado) {
      return ElevatedButton.icon(
        onPressed: onPanel,
        icon: const Icon(Icons.dashboard_outlined),
        label: const Text('Ir a mi panel'),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
        ),
        SizedBox(
          width: 240,
          child: OutlinedButton.icon(
            onPressed: onRegistro,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Registrarse'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppPalette.textDark,
              side: const BorderSide(color: AppPalette.mintDark, width: 1.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Beneficios extends StatelessWidget {
  const _Beneficios();

  static const _items = [
    (
      Icons.favorite_border,
      'Adopta',
      'Encuentra a tu compañero ideal y postúlate en pocos pasos.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'Da en adopción',
      'Publica a tu mascota con fotos y datos para que halle un buen hogar.',
    ),
    (
      Icons.verified_user_outlined,
      'Proceso seguro',
      'Cada adopción pasa por etapas de evaluación y seguimiento.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final (icono, titulo, descripcion) in _items)
          SizedBox(
            width: 270,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppPalette.peach,
                      child: Icon(icono, color: AppPalette.textDark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(descripcion),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Galeria extends StatelessWidget {
  const _Galeria();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ImagePlaceholder(width: 200, height: 140, icon: Icons.photo_outlined),
        _ImagePlaceholder(width: 200, height: 140, icon: Icons.photo_outlined),
        _ImagePlaceholder(width: 200, height: 140, icon: Icons.photo_outlined),
        _ImagePlaceholder(width: 200, height: 140, icon: Icons.photo_outlined),
      ],
    );
  }
}

/// Space reserved for images until the real assets are added.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    this.width,
    required this.height,
    required this.icon,
    this.label,
  });

  final double? width;
  final double height;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.mintDark.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppPalette.mintDark),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(label!),
          ],
        ],
      ),
    );
  }
}
