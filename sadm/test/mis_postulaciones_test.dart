import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/config/mis_postulaciones_textos.dart';
import 'package:sadm/models/mi_postulacion.dart';
import 'package:sadm/screens/mis_postulaciones_screen.dart';
import 'package:sadm/screens/progreso_etapas.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/mis_postulaciones_service.dart';
import 'package:sadm/theme/app_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _activa() => {
      'id': 34,
      'fechaPostulacion': '2026-10-14T23:30:00Z',
      'mascotaId': 12,
      'mascotaNombre': 'Luna',
      'primeraFotoId': null,
      'dadorNombre': 'Carlos Ruiz',
      'nombreProceso': 'Proceso de adopción de Luna',
      'etapaActual': 1,
      'totalEtapas': 4,
      'puntaje': 5,
      'estado': 'ACTIVA',
      'estadoEtiqueta': 'Activa',
      'estadoDetalle': 'Etapa 1 en curso',
      'fechaActualizacion': '2026-10-14T23:30:00Z',
    };

Map<String, dynamic> _descartada() => {
      ..._activa(),
      'id': 30,
      'mascotaId': 7,
      'mascotaNombre': 'Toby',
      'primeraFotoId': 9,
      'puntaje': 0,
      'estado': 'DESCARTADA',
      'estadoEtiqueta': 'Descartada',
      'estadoDetalle': 'Cancelada por el dador',
      'fechaActualizacion': '2026-09-18T10:00:00Z',
    };

Widget _app(MisPostulacionesService service) => MaterialApp(
      theme: buildAppTheme(),
      home: MisPostulacionesScreen(service: service),
    );

MisPostulacionesService _servicio(http.Response Function(http.Request) handler) =>
    MisPostulacionesService(client: MockClient((r) async => handler(r)));

void main() {
  setUp(() => AuthSession.iniciar('token-de-prueba'));
  tearDown(AuthSession.limpiar);

  group('modelo', () {
    test('fromJson mapea los campos y estados', () {
      final p = MiPostulacion.fromJson(_descartada());
      expect(p.id, 30);
      expect(p.mascotaNombre, 'Toby');
      expect(p.estado, EstadoMiPostulacion.descartada);
      expect(p.esDescartada, isTrue);
      expect(p.estadoDetalle, 'Cancelada por el dador');
      expect(p.fotoPath, '/SADM/api/mascotas/fotos/9/imagen');
      expect(p.fechaActualizacion, isNotNull);
    });

    test('sin foto no hay ruta de imagen y la etapa se acota a 1..total', () {
      final p = MiPostulacion.fromJson({..._activa(), 'etapaActual': 9});
      expect(p.fotoPath, isNull);
      expect(p.etapaActual, 4);
      expect(p.esActiva, isTrue);
    });

    test('toJson/fromJson conserva los datos', () {
      final original = MiPostulacion.fromJson(_activa());
      final copia = MiPostulacion.fromJson(original.toJson());
      expect(copia.id, original.id);
      expect(copia.estado, original.estado);
      expect(copia.puntaje, original.puntaje);
    });
  });

  group('mapeo de estado y etapa en la barra', () {
    test('activa: ✓ antes, ▶ la actual, pendientes después', () {
      expect(
        segmentosDeProgreso(estado: EstadoMiPostulacion.activa, etapaActual: 3),
        [
          SegmentoEtapa.completada,
          SegmentoEtapa.completada,
          SegmentoEtapa.actual,
          SegmentoEtapa.pendiente,
        ],
      );
    });

    test('descartada: ✕ en la etapa donde quedó y las siguientes pendientes', () {
      expect(
        segmentosDeProgreso(estado: EstadoMiPostulacion.descartada, etapaActual: 2),
        [
          SegmentoEtapa.completada,
          SegmentoEtapa.descartada,
          SegmentoEtapa.pendiente,
          SegmentoEtapa.pendiente,
        ],
      );
    });

    test('ganadora: las 4 completadas', () {
      expect(
        segmentosDeProgreso(estado: EstadoMiPostulacion.ganadora, etapaActual: 4),
        everyElement(SegmentoEtapa.completada),
      );
    });

    test('nombres de etapa del CLAUDE.md', () {
      expect(MisPostulacionesTextos.etapas, ['Formulario', 'Documentos', 'Entrevista', 'Visita']);
    });
  });

  group('pantalla', () {
    testWidgets('lista vacía muestra el mensaje y el botón', (tester) async {
      await tester.pumpWidget(_app(_servicio((_) => _json({'status': 200, 'data': []}))));
      await tester.pumpAndSettle();

      expect(find.text('Aún no te has postulado a ninguna mascota'), findsOneWidget);
      expect(
        find.text('Explora las mascotas disponibles y postúlate a la que se ajuste a tu hogar.'),
        findsOneWidget,
      );
      expect(find.text('Ver mascotas disponibles'), findsOneWidget);
    });

    testWidgets('con postulaciones muestra tarjetas, contadores y filtra por pestaña',
        (tester) async {
      await tester.pumpWidget(_app(_servicio(
        (_) => _json({'status': 200, 'data': [_activa(), _descartada()]}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Todas 2'), findsOneWidget);
      expect(find.text('Activas 1'), findsOneWidget);
      expect(find.text('Ganadora 0'), findsOneWidget);
      expect(find.text('Descartadas 1'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Toby'), findsOneWidget);
      expect(find.text('Puntaje acumulado: 5'), findsOneWidget);
      expect(find.text('Puntaje acumulado: 0'), findsOneWidget);
      expect(find.text('Motivo: Cancelada por el dador'), findsOneWidget);
      expect(find.text('Ver detalle'), findsNWidgets(2));

      await tester.tap(find.text('Descartadas 1'));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsNothing);
      expect(find.text('Toby'), findsOneWidget);
    });

    testWidgets('error muestra Reintentar y se recupera', (tester) async {
      var llamadas = 0;
      await tester.pumpWidget(_app(_servicio((_) {
        llamadas++;
        return llamadas == 1
            ? http.Response('', 500)
            : _json({'status': 200, 'data': [_activa()]});
      })));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
    });
  });

  group('servicio', () {
    test('envía el token y mapea 401 a NoAutenticadoException', () async {
      String? auth;
      final service = _servicio((r) {
        auth = r.headers['Authorization'];
        return http.Response('', 401);
      });
      await expectLater(service.listar(), throwsA(isA<NoAutenticadoException>()));
      expect(auth, 'Bearer token-de-prueba');
    });

    test('403 es SinPermisosException', () async {
      final service = _servicio((_) => http.Response('', 403));
      await expectLater(service.listar(), throwsA(isA<SinPermisosException>()));
    });
  });
}
