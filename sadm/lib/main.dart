import 'package:flutter/material.dart';

import 'screens/adoptante_form_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SadmApp());
}

class SadmApp extends StatelessWidget {
  const SadmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SADM - Adopción de mascotas',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AdoptanteFormScreen(),
    );
  }
}
