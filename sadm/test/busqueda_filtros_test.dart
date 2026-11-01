import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/filtros_mascota.dart';
import 'package:sadm/screens/mascotas_disponibles_screen.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/busqueda_mascotas_service.dart';
import 'package:sadm/theme/app_theme.dart';

Future<void> _abrir(WidgetTester tester, MockClient client) async {
  // Angosta (<900: filtros en BottomSheet) pero alta, para que todas las casillas queden visibles.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MascotasDisponiblesScreen(service: BusquedaMascotasService(client: client)),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response _json(Object cuerpo) => http.Response(
      jsonEncode(cuerpo),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  group('FiltrosMascota', () {
    test('sin filtros no envía parámetros', () {
      expect(FiltrosMascota.vacio.hayFiltros, isFalse);
      expect(FiltrosMascota.vacio.toQueryParameters(), isEmpty);
    });

    test('toQueryParameters repite las claves múltiples y recorta el nombre', () {
      const filtros = FiltrosMascota(
        especies: {'GATO', 'PERRO'},
        edades: {'JOVEN'},
        tamanos: {'GRANDE', 'MEDIANO'},
        temperamentos: {'SOCIABLE', 'JUGUETON'},
      );

      expect(filtros.toQueryParameters(nombre: '  Firú '), {
        'nombre': ['Firú'],
        'especie': ['PERRO', 'GATO'],
        'edad': ['JOVEN'],
        'tamano': ['MEDIANO', 'GRANDE'],
        'temperamento': ['JUGUETON', 'SOCIABLE'],
      });
    });

    test('la raza solo se conserva con una única especie', () {
      final conRaza = const FiltrosMascota(especies: {'PERRO'}).copyWith(raza: 'Labrador');
      expect(conRaza.raza, 'Labrador');
      expect(conRaza.toQueryParameters()['raza'], ['Labrador']);

      expect(conRaza.copyWith(especies: {'PERRO', 'GATO'}).raza, isNull);
      expect(conRaza.sin(GrupoFiltro.especie, 'PERRO').raza, isNull);
    });

    test('sin quita un valor y activos lo refleja', () {
      const filtros = FiltrosMascota(tamanos: {'MEDIANO', 'GRANDE'}, edades: {'JOVEN'});
      expect(filtros.activos.map((f) => f.etiqueta), ['Joven', 'Mediano', 'Grande']);
      expect(filtros.cantidad, 3);

      final menos = filtros.sin(GrupoFiltro.tamano, 'GRANDE');
      expect(menos.tamanos, {'MEDIANO'});
    });

    test('contador en singular y plural', () {
      expect(textoContador(1), '1 mascota encontrada');
      expect(textoContador(2), '2 mascotas encontradas');
      expect(textoContador(0), '0 mascotas encontradas');
    });
  });

  group('MascotasDisponiblesScreen', () {
    testWidgets('muestra el contador, singular con una mascota', (tester) async {
      final client = MockClient((_) async => _json([{'id': 1, 'nombre': 'Firulais'}]));
      await _abrir(tester, client);

      expect(find.text('1 mascota encontrada'), findsOneWidget);
    });

    testWidgets('muestra el contador plural', (tester) async {
      final client = MockClient(
        (_) async => _json([
          {'id': 1, 'nombre': 'Firulais'},
          {'id': 2, 'nombre': 'Firulín'},
        ]),
      );
      await _abrir(tester, client);

      expect(find.text('2 mascotas encontradas'), findsOneWidget);
    });

    testWidgets('el texto se envía tras 300 ms de espera (debounce) y una sola vez', (tester) async {
      final enviadas = <Uri>[];
      final client = MockClient((request) async {
        enviadas.add(request.url);
        return _json([{'id': 1, 'nombre': 'Firulais'}]);
      });
      await _abrir(tester, client);
      expect(enviadas, hasLength(1)); // carga inicial

      await tester.enterText(find.byType(TextField), 'f');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'firú');
      await tester.pump(const Duration(milliseconds: 299));
      expect(enviadas, hasLength(1)); // todavía no

      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(enviadas, hasLength(2));
      expect(enviadas.last.queryParametersAll['nombre'], ['firú']);
    });

    testWidgets('sin coincidencias por nombre muestra el mensaje exacto', (tester) async {
      final client = MockClient((request) async {
        return _json(request.url.queryParameters.containsKey('nombre') ? [] : [{'id': 1, 'nombre': 'Luna'}]);
      });
      await _abrir(tester, client);

      await tester.enterText(find.byType(TextField), 'xyzabc');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron mascotas con ese nombre'), findsOneWidget);
    });

    testWidgets('"Limpiar búsqueda" vacía el texto y recarga sin nombre', (tester) async {
      final enviadas = <Uri>[];
      final client = MockClient((request) async {
        enviadas.add(request.url);
        return _json([{'id': 1, 'nombre': 'Luna'}]);
      });
      await _abrir(tester, client);

      await tester.enterText(find.byType(TextField), 'lu');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(enviadas.last.queryParameters['nombre'], 'lu');

      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();

      expect(enviadas.last.queryParameters.containsKey('nombre'), isFalse);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('aplicar y limpiar filtros desde el panel', (tester) async {
      final enviadas = <Uri>[];
      final client = MockClient((request) async {
        enviadas.add(request.url);
        final hayFiltro = request.url.queryParametersAll.containsKey('tamano');
        return _json(hayFiltro ? [] : [{'id': 1, 'nombre': 'Luna'}]);
      });
      await _abrir(tester, client);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mediano'));
      await tester.pump();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(enviadas.last.queryParametersAll['tamano'], ['MEDIANO']);
      expect(find.text('Filtros activos:'), findsOneWidget);
      expect(
        find.text('No hay mascotas que coincidan con los filtros seleccionados'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(enviadas.last.queryParametersAll.containsKey('tamano'), isFalse);
      expect(find.text('Filtros activos:'), findsNothing);
      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets('el chip ✕ quita un filtro y vuelve a consultar', (tester) async {
      final enviadas = <Uri>[];
      final client = MockClient((request) async {
        enviadas.add(request.url);
        return _json([{'id': 1, 'nombre': 'Luna'}]);
      });
      await _abrir(tester, client);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grande'));
      await tester.pump();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(enviadas.last.queryParametersAll['tamano'], ['GRANDE']);

      await tester.tap(find.byTooltip('Quitar Grande'));
      await tester.pumpAndSettle();

      expect(enviadas.last.queryParametersAll.containsKey('tamano'), isFalse);
    });

    testWidgets('la raza está deshabilitada sin especie y pide razas con una', (tester) async {
      final enviadas = <Uri>[];
      final client = MockClient((request) async {
        enviadas.add(request.url);
        if (request.url.path.endsWith('/razas')) return _json(['Criollo', 'Labrador']);
        return _json([{'id': 1, 'nombre': 'Luna'}]);
      });
      await _abrir(tester, client);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una sola especie'), findsOneWidget);

      await tester.tap(find.text('Perro'));
      await tester.pumpAndSettle();

      expect(enviadas.any((u) => u.path.endsWith('/razas') && u.queryParameters['especie'] == 'PERRO'), isTrue);
      expect(find.text('Todas las razas'), findsOneWidget);
    });
  });
}
