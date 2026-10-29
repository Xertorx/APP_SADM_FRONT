import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/mascota_detalle.dart';
import 'package:sadm/screens/mascota_detalle_screen.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/mascota_service.dart';
import 'package:sadm/services/postulacion_service.dart';
import 'package:sadm/theme/app_theme.dart';

Future<List<String>> _abrir(WidgetTester tester, Map<String, dynamic> mascota) async {
  final rutas = <String>[];
  final client = MockClient((request) async {
    rutas.add('${request.method} ${request.url.path}');
    if (request.url.path.endsWith('/resumen')) return http.Response('{}', 404);
    return http.Response.bytes(
      utf8.encode(jsonEncode({'data': mascota})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MascotaDetalleScreen(
                    mascotaId: 7,
                    mascotaService: MascotaService(client: client),
                    postulacionService: PostulacionService(client: client),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return rutas;
}

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  testWidgets('muestra todos los datos y consulta GET /api/mascotas/{id}', (tester) async {
    final rutas = await _abrir(tester, {
      'id': 7,
      'nombre': 'Luna',
      'estado': 'DISPONIBLE',
      'especie': 'PERRO',
      'raza': 'Criollo',
      'edad': 3,
      'unidadEdad': 'ANIOS',
      'tamano': 'MEDIANO',
      'sexo': 'HEMBRA',
      'temperamento': ['JUGUETON', 'CARINOSO'],
      'ubicacion': 'Cali',
      'historialSalud': 'Vacunas al día',
      'fotos': ['http://x/1.jpg', 'http://x/2.jpg'],
    });

    expect(rutas, [
      'GET /SADM/api/mascotas/7',
      'GET /SADM/api/postulaciones/mascotas/7/resumen',
    ]);
    expect(find.text('Ya te postulaste'), findsNothing);
    for (final texto in [
      'Luna',
      'Perro',
      'Criollo',
      '3 años',
      'Mediano',
      'Hembra',
      'Cali',
      'Juguetón',
      'Cariñoso',
      'Vacunas al día',
      'Temperamento',
      'Historial de salud',
      'Solicitar adopción',
      'Volver',
    ]) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    expect(find.text('Sin fotos disponibles'), findsNothing);
  });

  testWidgets('omite los campos opcionales que no vienen y muestra sin fotos', (tester) async {
    await _abrir(tester, {'id': 7, 'nombre': 'Michi', 'estado': 'DISPONIBLE'});

    expect(find.text('Michi'), findsOneWidget);
    expect(find.text('Sin fotos disponibles'), findsOneWidget);
    for (final texto in ['Temperamento', 'Historial de salud', 'Ubicación', 'Raza', 'Sexo']) {
      expect(find.text(texto), findsNothing, reason: texto);
    }
  });

  testWidgets('el botón Volver regresa a la pantalla anterior', (tester) async {
    await _abrir(tester, {'id': 7, 'nombre': 'Luna', 'estado': 'DISPONIBLE'});

    await tester.ensureVisible(find.text('Volver'));
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('abrir'), findsOneWidget);
  });

  test('la galería toma la foto principal primero, sin repetidas y máximo 6', () {
    final mascota = MascotaDetalle.fromJson({
      'id': 1,
      'nombre': 'Luna',
      'estado': 'DISPONIBLE',
      'fotoUrl': '/f/0.jpg',
      'fotos': [
        for (var i = 0; i < 8; i++) {'url': '/f/$i.jpg'},
      ],
    });

    expect(mascota.galeria.length, 6);
    expect(mascota.galeria.first, '/f/0.jpg');
    expect(mascota.galeria.toSet().length, 6);
  });
}
