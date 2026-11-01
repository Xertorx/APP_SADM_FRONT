import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/config/app_config.dart';
import 'package:sadm/models/dador_publico.dart';
import 'package:sadm/models/mascota_detalle.dart';
import 'package:sadm/screens/mascota_detalle_screen.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/dador_service.dart';
import 'package:sadm/services/mascota_service.dart';
import 'package:sadm/services/postulacion_service.dart';
import 'package:sadm/services/resumen_postulacion_service.dart';
import 'package:sadm/theme/app_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

MascotaDetalle _mascota({String estado = 'DISPONIBLE', int? idDador}) =>
    MascotaDetalle(id: 7, nombre: 'Firulais', estado: estado, idDador: idDador);

/// Abre el detalle de la mascota 7 con un backend simulado. [estadoPostulacion] null = sin postulación.
Future<List<String>> _abrir(
  WidgetTester tester, {
  Map<String, dynamic>? mascota,
  String? estadoPostulacion,
  Map<String, dynamic>? dador,
}) async {
  final rutas = <String>[];
  final client = MockClient((request) async {
    final path = request.url.path;
    rutas.add('${request.method} $path');
    if (path.endsWith('/mascotas/7')) {
      return _json({
        'id': 7,
        'nombre': 'Firulais',
        'estado': 'DISPONIBLE',
        'idDador': 3,
        ...?mascota,
      });
    }
    if (path.endsWith('/resumen')) {
      return _json({
        'status': 200,
        'data': {
          'postulacionActiva': estadoPostulacion != null,
          'estado': ?estadoPostulacion,
        },
      });
    }
    if (path.endsWith('/perfil/publico/3') && dador != null) {
      return _json({'status': 200, 'data': dador});
    }
    return _json({'message': 'no existe'}, 404);
  });

  await tester.binding.setSurfaceSize(const Size(420, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MascotaDetalleScreen(
        mascotaId: 7,
        mascotaService: MascotaService(client: client),
        postulacionService: PostulacionService(client: client),
        resumenService: ResumenPostulacionService(client: client),
        dadorService: DadorService(client: client),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return rutas;
}

Finder _boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.bySubtype<ElevatedButton>(),
    );

bool _habilitado(WidgetTester tester, String texto) =>
    tester.widget<ElevatedButton>(_boton(texto)).onPressed != null;

const _maria = {
  'id': 3,
  'nombre': 'María',
  'apellido': 'González',
  'tieneFoto': false,
  'miembroDesde': '2025-03-15T12:00:00.000+00:00',
};

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  group('Modelo', () {
    test('fotosIds se convierte en URLs de /mascotas/fotos/{id}/imagen', () {
      final mascota = MascotaDetalle.fromJson({
        'id': 7,
        'nombre': 'Firulais',
        'estado': 'DISPONIBLE',
        'fotosIds': [5, 9],
      });

      expect(mascota.fotos, [
        '${AppConfig.baseUrl}/mascotas/fotos/5/imagen',
        '${AppConfig.baseUrl}/mascotas/fotos/9/imagen',
      ]);
      expect(mascota.galeria, mascota.fotos);
    });

    test('fotoUrl y fotos siguen funcionando junto con fotosIds, sin repetir', () {
      final mascota = MascotaDetalle.fromJson({
        'id': 7,
        'nombre': 'Firulais',
        'estado': 'DISPONIBLE',
        'fotoUrl': 'http://x/principal.jpg',
        'fotos': ['http://x/2.jpg'],
        'fotosIds': [5],
      });

      expect(mascota.galeria, [
        'http://x/principal.jpg',
        'http://x/2.jpg',
        '${AppConfig.baseUrl}/mascotas/fotos/5/imagen',
      ]);
    });

    test('sin fotosIds la galería queda vacía', () {
      expect(_mascota().galeria, isEmpty);
    });

    test('"Publicada hace N días · ubicación"', () {
      final mascota = MascotaDetalle.fromJson({
        'id': 7,
        'nombre': 'Firulais',
        'estado': 'DISPONIBLE',
        'ubicacion': 'Bogotá, Suba',
        'fechaPublicacion': '2026-10-20T10:00:00Z',
      });

      expect(
        mascota.encabezadoPublicacion(ahora: DateTime.utc(2026, 11, 1, 12)),
        'Publicada hace 12 días · Bogotá, Suba',
      );
      expect(
        mascota.encabezadoPublicacion(ahora: DateTime.utc(2026, 10, 20, 15)),
        'Publicada hoy · Bogotá, Suba',
      );
      expect(
        mascota.encabezadoPublicacion(ahora: DateTime.utc(2026, 10, 21, 12)),
        'Publicada hace 1 día · Bogotá, Suba',
      );
    });

    test('sin fecha de publicación no hay encabezado', () {
      expect(_mascota().encabezadoPublicacion(), isNull);
    });
  });

  group('Dador público', () {
    test('"Miembro desde marzo de 2025"', () {
      final dador = DadorPublico.fromJson(Map<String, dynamic>.from(_maria));

      expect(dador.nombreCompleto, 'María González');
      expect(dador.miembroDesdeTexto, 'Miembro desde marzo de 2025');
    });

    test('sin fecha de registro no hay texto de "Miembro desde"', () {
      final dador = DadorPublico.fromJson({..._maria, 'miembroDesde': null});

      expect(dador.miembroDesde, isNull);
      expect(dador.miembroDesdeTexto, isNull);
    });

    test('acepta la fecha como milisegundos', () {
      final dador = DadorPublico.fromJson({
        ..._maria,
        'miembroDesde': DateTime(2025, 3, 15).millisecondsSinceEpoch,
      });

      expect(dador.miembroDesdeTexto, 'Miembro desde marzo de 2025');
    });
  });

  group('Lógica del botón', () {
    test('el dueño ve "propia" aunque esté postulado o reservada', () {
      AuthSession.usuarioId = 3;
      final mascota = _mascota(estado: 'RESERVADA', idDador: 3);

      expect(
        mascota.accionPostulacion(autenticado: true, estadoPostulacion: 'ETAPA_1_EN_CURSO'),
        AccionPostulacion.propia,
      );
    });

    test('caso B: con estado de postulación', () {
      expect(
        _mascota().accionPostulacion(autenticado: true, estadoPostulacion: 'ETAPA_1_EN_CURSO'),
        AccionPostulacion.yaPostulado,
      );
    });

    test('caso C: reservada y adoptada', () {
      expect(_mascota(estado: 'RESERVADA').accionPostulacion(autenticado: true),
          AccionPostulacion.cerrada);
      expect(_mascota(estado: 'ADOPTADA').accionPostulacion(autenticado: true),
          AccionPostulacion.cerrada);
    });

    test('caso A: disponible sin postulación', () {
      expect(_mascota().accionPostulacion(autenticado: true), AccionPostulacion.postular);
    });

    test('sin sesión pide iniciar sesión; otros estados siguen como antes', () {
      expect(_mascota().accionPostulacion(autenticado: false), AccionPostulacion.requiereLogin);
      expect(_mascota(estado: 'PENDIENTE_APROBACION').accionPostulacion(autenticado: true),
          AccionPostulacion.noDisponible);
    });
  });

  group('Pantalla', () {
    testWidgets('muestra "Publicado por" con nombre y fecha de registro, sin datos de contacto',
        (tester) async {
      final rutas = await _abrir(tester, dador: _maria);

      expect(rutas, contains('GET /SADM/api/perfil/publico/3'));
      expect(find.text('Publicado por'), findsOneWidget);
      expect(find.text('María González'), findsOneWidget);
      expect(find.text('Miembro desde marzo de 2025'), findsOneWidget);
      expect(
        find.text('Los datos de contacto se comparten solo tras aprobar su postulación'),
        findsOneWidget,
      );
    });

    testWidgets('oculta "Miembro desde" si el dador no tiene fecha de registro', (tester) async {
      await _abrir(tester, dador: {..._maria, 'miembroDesde': null});

      expect(find.text('María González'), findsOneWidget);
      expect(find.textContaining('Miembro desde'), findsNothing);
    });

    testWidgets('encabezado "Publicada hace N días · ubicación"', (tester) async {
      final fecha = DateTime.now().subtract(const Duration(days: 12, hours: 1));
      await _abrir(tester, mascota: {
        'ubicacion': 'Bogotá, Suba',
        'fechaPublicacion': fecha.toUtc().toIso8601String(),
      });

      expect(find.text('Publicada hace 12 días · Bogotá, Suba'), findsOneWidget);
    });

    testWidgets('caso A: disponible y sin postulación muestra el botón habilitado', (tester) async {
      await _abrir(tester, dador: _maria);

      expect(_habilitado(tester, 'Solicitar adopción'), isTrue);
    });

    testWidgets('caso B: reemplaza el botón por el estado de la postulación', (tester) async {
      await _abrir(tester, estadoPostulacion: 'ETAPA_1_EN_CURSO', dador: _maria);

      expect(find.text('Ya te has postulado a esta mascota. Estado:'), findsOneWidget);
      expect(find.text('Etapa 1 en curso'), findsOneWidget);
      expect(find.text('Solicitar adopción'), findsNothing);
    });

    testWidgets('caso C adoptada: "No disponible" deshabilitado y su mensaje', (tester) async {
      await _abrir(tester, mascota: {'estado': 'ADOPTADA'}, dador: _maria);

      expect(_habilitado(tester, 'No disponible'), isFalse);
      expect(find.text('Esta mascota ya fue adoptada'), findsOneWidget);
      expect(find.text('Solicitar adopción'), findsNothing);
    });

    testWidgets('caso C reservada: "No disponible" deshabilitado y su mensaje', (tester) async {
      await _abrir(tester, mascota: {'estado': 'RESERVADA'}, dador: _maria);

      expect(_habilitado(tester, 'No disponible'), isFalse);
      expect(find.text('Esta mascota está reservada'), findsOneWidget);
    });

    testWidgets('el dueño ve "Esta es tu publicación", sin botón de postularse', (tester) async {
      AuthSession.usuarioId = 3;
      final rutas = await _abrir(tester, dador: _maria);

      expect(find.text('Esta es tu publicación'), findsOneWidget);
      expect(find.text('Solicitar adopción'), findsNothing);
      expect(find.text('Editar publicación'), findsOneWidget);
      expect(rutas.any((r) => r.endsWith('/resumen')), isFalse);
    });

    testWidgets('si falla el perfil del dador igual se muestra la mascota', (tester) async {
      await _abrir(tester);

      expect(find.text('Firulais'), findsOneWidget);
      expect(find.text('Publicado por'), findsOneWidget);
      // El 404 del backend se muestra como mensaje dentro de la sección, sin romper la pantalla.
      expect(find.text('no existe'), findsOneWidget);
      expect(_habilitado(tester, 'Solicitar adopción'), isTrue);
    });
  });
}
