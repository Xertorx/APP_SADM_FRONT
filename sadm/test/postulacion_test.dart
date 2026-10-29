import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sadm/screens/mascota_detalle_screen.dart';
import 'package:sadm/screens/postulacion_dialog.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/mascota_service.dart';
import 'package:sadm/services/postulacion_service.dart';
import 'package:sadm/theme/app_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _postulacionJson() => {
      'id': 1,
      'mascotaId': 7,
      'fechaPostulacion': '2026-10-14T12:00:00Z',
      'estado': 'ETAPA_1_EN_CURSO',
      'puntaje': 0,
    };

/// In-memory stand-in for the backend, served through a [MockClient].
class FakeApi {
  String estado = 'DISPONIBLE';
  Map<String, dynamic>? postulacion;
  Completer<void>? crearGate;
  http.Response Function()? crearError;
  bool resumenFalla = false;

  int postCalls = 0;
  int resumenCalls = 0;
  final rutas = <String>[];

  late final client = MockClient(_handle);

  Map<String, dynamic> get _mascota => {
        'id': 7,
        'nombre': 'Luna',
        'estado': estado,
        'especie': 'PERRO',
        'raza': 'Criollo',
        'edad': 3,
        'unidadEdad': 'ANIOS',
        'tamano': 'MEDIANO',
      };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    rutas.add('${request.method} $path');

    // Con sesión iniciada, toda petición debe llevar el JWT.
    if (AuthSession.autenticado) {
      expect(request.headers['Authorization'], 'Bearer ${AuthSession.token}');
    }

    if (request.method == 'GET' && path.endsWith('/api/mascotas/7')) {
      return _json(_mascota);
    }
    if (request.method == 'GET' && path.endsWith('/api/postulaciones/mascotas/7/resumen')) {
      resumenCalls++;
      if (resumenFalla) return _json({'message': 'boom'}, 500);
      return postulacion == null ? _json({}, 404) : _json({'mascotaId': 7});
    }
    if (request.method == 'POST' && path.endsWith('/api/postulaciones')) {
      postCalls++;
      expect(path, '/SADM/api/postulaciones');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'mascotaId': 7});
      if (crearGate != null) await crearGate!.future;
      if (crearError != null) return crearError!();
      postulacion = _postulacionJson();
      return _json(postulacion!, 201);
    }
    return _json({}, 404);
  }
}

Finder _boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.bySubtype<ElevatedButton>(),
    );

bool _habilitado(WidgetTester tester, String texto) =>
    tester.widget<ElevatedButton>(_boton(texto)).onPressed != null;

Future<void> _abrirPantalla(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MascotaDetalleScreen(
        mascotaId: 7,
        mascotaService: MascotaService(client: api.client),
        postulacionService: PostulacionService(client: api.client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirConfirmacion(WidgetTester tester) async {
  await tester.tap(_boton('Solicitar adopción'));
  await tester.pumpAndSettle();
}

Future<void> _abrirYAceptar(WidgetTester tester) async {
  await _abrirConfirmacion(tester);
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  setUp(() {
    AuthSession.token = 'token-de-prueba';
  });

  group('Punto de entrada', () {
    testWidgets('botón habilitado si la mascota está disponible', (tester) async {
      await _abrirPantalla(tester, FakeApi());

      expect(find.text('Luna'), findsOneWidget);
      expect(_habilitado(tester, 'Solicitar adopción'), isTrue);
      expect(find.text('Ya te postulaste'), findsNothing);
    });

    testWidgets('deshabilitado con explicación si no está disponible', (tester) async {
      await _abrirPantalla(tester, FakeApi()..estado = 'ADOPTADA');

      expect(_habilitado(tester, 'Solicitar adopción'), isFalse);
      expect(find.textContaining('no está disponible'), findsOneWidget);
    });

    testWidgets('al abrir el detalle consulta el resumen de postulación y no hay aviso si no existe',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);

      expect(api.rutas, [
        'GET /SADM/api/mascotas/7',
        'GET /SADM/api/postulaciones/mascotas/7/resumen',
      ]);
      expect(_habilitado(tester, 'Solicitar adopción'), isTrue);
      expect(find.text('Ya te postulaste'), findsNothing);
    });

    testWidgets('resumen 200: muestra "Ya te postulaste" y deshabilita el botón', (tester) async {
      await _abrirPantalla(tester, FakeApi()..postulacion = _postulacionJson());

      expect(find.byType(EstadoChip), findsNWidgets(2));
      expect(find.text('Ya te postulaste'), findsOneWidget);
      expect(_habilitado(tester, 'Solicitar adopción'), isFalse);
      expect(find.text('Ya tienes una postulación activa para esta mascota.'), findsOneWidget);
    });

    testWidgets('si el resumen falla igual se muestra la mascota y se puede solicitar',
        (tester) async {
      await _abrirPantalla(tester, FakeApi()..resumenFalla = true);

      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Ya te postulaste'), findsNothing);
      expect(_habilitado(tester, 'Solicitar adopción'), isTrue);
    });

    testWidgets('sin sesión muestra mensaje, no permite postular y no consulta el resumen',
        (tester) async {
      AuthSession.limpiar();
      final api = FakeApi();
      await _abrirPantalla(tester, api);

      expect(_habilitado(tester, 'Solicitar adopción'), isFalse);
      expect(find.textContaining('Inicia sesión'), findsOneWidget);
      expect(api.resumenCalls, 0);
    });
  });

  group('Confirmación previa', () {
    testWidgets('el modal muestra el resumen del proceso y los términos, sin llamar a ningún resumen',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirConfirmacion(tester);

      expect(find.text('¿Quieres solicitar la adopción de Luna?'), findsOneWidget);
      expect(find.text('Resumen del proceso de adopción'), findsOneWidget);
      expect(
        find.textContaining('Etapa 1 — Evaluación inicial', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Revisión del perfil y entrevista', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Etapa 2 — Visita al hogar', findRichText: true), findsOneWidget);
      expect(find.textContaining('Verificación del entorno', findRichText: true), findsOneWidget);
      expect(find.textContaining('Etapa 3 — Decisión final', findRichText: true), findsOneWidget);
      expect(find.textContaining('Selección del adoptante', findRichText: true), findsOneWidget);
      expect(find.text('Términos y condiciones'), findsOneWidget);
      expect(find.text('Acepto los términos y condiciones'), findsOneWidget);
      expect(api.rutas.where((r) => r.startsWith('POST')), isEmpty);
    });

    testWidgets('no se puede confirmar sin aceptar los términos', (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirConfirmacion(tester);

      expect(_habilitado(tester, 'Confirmar postulación'), isFalse);
      expect(find.text('Debes aceptar los términos y condiciones para confirmar.'),
          findsOneWidget);

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(_habilitado(tester, 'Confirmar postulación'), isTrue);
      expect(api.postCalls, 0);
    });

    testWidgets('cancelar no envía ninguna postulación', (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirConfirmacion(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.postCalls, 0);
      expect(find.text('Confirmar postulación'), findsNothing);
      expect(find.text('Solicitar adopción'), findsOneWidget);
    });
  });

  group('Confirmación', () {
    testWidgets('éxito muestra Etapa 1 en curso, puntaje 0 y actualiza el detalle',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirYAceptar(tester);

      await tester.tap(_boton('Confirmar postulación'));
      await tester.pumpAndSettle();

      expect(find.text('¡Postulación registrada!'), findsOneWidget);
      expect(find.textContaining('de octubre de 2026'), findsOneWidget);
      expect(find.text('Etapa 1 en curso'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(api.postCalls, 1);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya te postulaste'), findsOneWidget);
      expect(find.text('Solicitar adopción'), findsNothing);
    });

    testWidgets('doble clic en confirmar genera una sola petición', (tester) async {
      final api = FakeApi()..crearGate = Completer<void>();
      await _abrirPantalla(tester, api);
      await _abrirYAceptar(tester);

      final confirmar = _boton('Confirmar postulación');
      await tester.tap(confirmar);
      await tester.tap(confirmar);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(api.postCalls, 1);

      api.crearGate!.complete();
      await tester.pumpAndSettle();
      expect(api.postCalls, 1);
    });

    testWidgets('POSTULACION_DUPLICADA muestra el mensaje y refresca el detalle',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirYAceptar(tester);

      api.postulacion = _postulacionJson();
      api.crearError = () => _json({'codigo': 'POSTULACION_DUPLICADA'}, 409);

      await tester.tap(_boton('Confirmar postulación'));
      await tester.pumpAndSettle();

      expect(find.text('Ya te has postulado a esta mascota'), findsOneWidget);
      expect(_habilitado(tester, 'Confirmar postulación'), isFalse);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya te postulaste'), findsOneWidget);
    });

    testWidgets('MASCOTA_NO_DISPONIBLE muestra el mensaje y refresca el detalle',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirYAceptar(tester);

      api.estado = 'ADOPTADA';
      api.crearError = () => _json({'codigo': 'MASCOTA_NO_DISPONIBLE'}, 409);

      await tester.tap(_boton('Confirmar postulación'));
      await tester.pumpAndSettle();

      expect(find.text('Esta mascota ya no está disponible'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(_habilitado(tester, 'Solicitar adopción'), isFalse);
      expect(find.textContaining('no está disponible para postulaciones'), findsOneWidget);
    });

    testWidgets('error 5xx ofrece reintentar y permite completar la postulación',
        (tester) async {
      final api = FakeApi();
      await _abrirPantalla(tester, api);
      await _abrirYAceptar(tester);

      api.crearError = () => _json({'message': 'fallo'}, 500);
      await tester.tap(_boton('Confirmar postulación'));
      await tester.pumpAndSettle();

      expect(find.text('fallo'), findsOneWidget);
      expect(_habilitado(tester, 'Confirmar postulación'), isTrue);

      api.crearError = null;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('¡Postulación registrada!'), findsOneWidget);
    });
  });
}
