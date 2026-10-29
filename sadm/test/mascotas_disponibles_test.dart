import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/mascota.dart';
import 'package:sadm/screens/mascotas_disponibles_screen.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/mascota_service.dart';
import 'package:sadm/theme/app_theme.dart';

Future<void> _abrir(WidgetTester tester, MockClient client) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MascotasDisponiblesScreen(service: MascotaService(client: client)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  testWidgets('consulta GET /api/mascotas con el token y lista las mascotas', (tester) async {
    late http.Request enviada;
    final client = MockClient((request) async {
      enviada = request;
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'nombre': 'Luna', 'especie': 'PERRO', 'edad': 3, 'unidadEdad': 'ANIOS'},
            {'id': 2, 'nombre': 'Michi', 'estado': 'DISPONIBLE', 'especie': 'GATO'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await _abrir(tester, client);

    expect(enviada.method, 'GET');
    expect(enviada.url.path, endsWith('/api/mascotas'));
    expect(enviada.headers['Authorization'], 'Bearer token');
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Michi'), findsOneWidget);
    expect(find.text('Perro · 3 años'), findsOneWidget);
  });

  testWidgets('acepta una lista JSON sin envoltorio', (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode([{'id': 1, 'nombre': 'Luna'}]), 200),
    );
    await _abrir(tester, client);

    expect(find.text('Luna'), findsOneWidget);
  });

  testWidgets('lista vacía muestra mensaje', (tester) async {
    final client = MockClient((_) async => http.Response('[]', 200));
    await _abrir(tester, client);

    expect(find.textContaining('no hay mascotas disponibles'), findsOneWidget);
  });

  testWidgets('error del servidor permite reintentar', (tester) async {
    var llamadas = 0;
    final client = MockClient((_) async {
      llamadas++;
      return llamadas == 1
          ? http.Response(jsonEncode({'message': 'Fallo interno'}), 500)
          : http.Response(jsonEncode([{'id': 1, 'nombre': 'Luna'}]), 200);
    });
    await _abrir(tester, client);

    expect(find.text('Fallo interno'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Luna'), findsOneWidget);
  });

  test('crear mascota envía el JWT en Authorization', () async {
    late http.BaseRequest enviada;
    final client = MockClient.streaming((request, body) async {
      enviada = request;
      await body.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'data': {'id': 7}}))),
        201,
      );
    });

    final id = await MascotaService(client: client).crear(
      const Mascota(
        idDador: 1,
        nombre: 'Luna',
        especie: 'PERRO',
        edad: 2,
        unidadEdad: 'ANIOS',
        tamano: 'MEDIANO',
        sexo: 'HEMBRA',
        temperamento: ['JUGUETON'],
        ubicacion: 'Cali',
      ),
      const [],
    );

    expect(id, 7);
    expect(enviada.headers['Authorization'], 'Bearer token');
  });
}