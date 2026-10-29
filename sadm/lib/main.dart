import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
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
      home: const HomeScreen(),
    );
  }
}
