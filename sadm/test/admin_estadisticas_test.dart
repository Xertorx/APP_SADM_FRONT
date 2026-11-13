import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/config/estadisticas_textos.dart';
import 'package:sadm/models/estadisticas.dart';
import 'package:sadm/screens/admin_estadisticas_screen.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/estadisticas_service.dart';
import 'package:sadm/theme/app_theme.dart';
import 'package:sadm/widgets/grafico_barras_roles.dart';

http.Response _json(Object cuerpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _datos({
  int publicadas = 12,
  Map<String, int> roles = const {'USUARIO': 8, 'FUNDACION': 1, 'ADMINISTRADOR': 1},
  int enCurso = 3,
  String? desde,
  String? hasta,
}) =>
    {
      'mascotasPublicadas': publicadas,
      'mascotasPorEstado': {'DISPONIBLE': 5, 'PENDIENTE_APROBACION': 7},
      'adopcionesCompletadas': {'valor': 0, 'disponible': false},
      'usuariosActivosPorRol': roles,
      'postulacionesEnCurso': enCurso,
      'adopcionesEnSeguimiento': {'valor': 0, 'disponible': false},
      'desde': desde,
      'hasta': hasta,
      'generadoEn': '2026-11-12T10:30:00',
    };

Map<String, dynamic> _ok([Map<String, dynamic>? data]) =>
    {'status': 200, 'message': 'Estadísticas consultadas', 'data': data ?? _datos()};

Future<void> _abrir(
  WidgetTester tester,
  Widget pantalla, {
  double ancho = 1000,
}) async {
  tester.view.physicalSize = Size(ancho, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: pantalla));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  group('Estadisticas.fromJson', () {
    test('mapea cifras, roles y cifras no disponibles', () {
      final e = Estadisticas.fromJson(_datos(desde: '2026-06-01', hasta: '2026-09-20'));
      expect(e.mascotasPublicadas, 12);
      expect(e.usuariosActivosPorRol['USUARIO'], 8);
      expect(e.totalUsuariosActivos, 10);
      expect(e.postulacionesEnCurso, 3);
      expect(e.adopcionesCompletadas.disponible, isFalse);
      expect(e.adopcionesEnSeguimiento.disponible, isFalse);
      expect(e.desde, '2026-06-01');
      expect(e.generadoEn, DateTime(2026, 11, 12, 10, 30));
    });

    test('desde y hasta pueden venir nulos (histórico)', () {
      final e = Estadisticas.fromJson(_datos());
      expect(e.desde, isNull);
      expect(e.hasta, isNull);
    });
  });

  group('GraficoBarrasRoles.porcentaje', () {
    test('redondea y evita dividir por cero', () {
      expect(GraficoBarrasRoles.porcentaje(620, 1000), 62);
      expect(GraficoBarrasRoles.porcentaje(1, 3), 33);
      expect(GraficoBarrasRoles.porcentaje(0, 0), 0);
    });
  });

  group('EstadisticasService', () {
    test('envía desde/hasta como yyyy-MM-dd con el token', () async {
      late http.Request recibida;
      final service = EstadisticasService(
        client: MockClient((r) async {
          recibida = r;
          return _json(_ok());
        }),
      );
      await service.obtener(desde: DateTime(2026, 6, 1), hasta: DateTime(2026, 9, 20));
      expect(recibida.url.path, endsWith('/admin/estadisticas'));
      expect(recibida.url.queryParameters, {'desde': '2026-06-01', 'hasta': '2026-09-20'});
      expect(recibida.headers['Authorization'], 'Bearer token');
    });

    test('sin fechas no envía parámetros', () async {
      late http.Request recibida;
      final service = EstadisticasService(
        client: MockClient((r) async {
          recibida = r;
          return _json(_ok());
        }),
      );
      await service.obtener();
      expect(recibida.url.queryParameters, isEmpty);
    });

    test('401 → NoAutenticadoException, 403 sin cuerpo → SinPermisosException, 400 → ValidationException',
        () async {
      Future<Object> con(int status, [Object? cuerpo]) async {
        final service = EstadisticasService(
          client: MockClient((r) async => cuerpo == null
              ? http.Response('', status)
              : _json(cuerpo, status)),
        );
        try {
          await service.obtener();
        } catch (e) {
          return e;
        }
        return 'sin error';
      }

      expect(await con(401), isA<NoAutenticadoException>());
      expect(await con(403), isA<SinPermisosException>());
      final e400 = await con(400, {'status': 400, 'message': EstadisticasTextos.errorRango});
      expect(e400, isA<ValidationException>());
      expect((e400 as ValidationException).message, EstadisticasTextos.errorRango);
    });

    test('exportar devuelve los bytes del CSV', () async {
      final service = EstadisticasService(
        client: MockClient((r) async => http.Response.bytes([1, 2, 3], 200)),
      );
      expect(await service.exportar(), Uint8List.fromList([1, 2, 3]));
    });

    test('nombre del archivo: reporte_estadisticas_yyyyMMdd.csv', () {
      expect(EstadisticasService.nombreArchivo(DateTime(2026, 11, 12)), 'reporte_estadisticas_20261112.csv');
    });
  });

  group('AdminEstadisticasScreen', () {
    testWidgets('muestra KPIs, gráfico y hora de generación', (tester) async {
      final service = EstadisticasService(client: MockClient((r) async => _json(_ok())));
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      expect(find.text(EstadisticasTextos.titulo), findsOneWidget);
      expect(find.text(EstadisticasTextos.kpiMascotas), findsOneWidget);
      expect(find.text(EstadisticasTextos.kpiAdopciones), findsOneWidget);
      expect(find.text(EstadisticasTextos.kpiPostulaciones), findsOneWidget);
      expect(find.text(EstadisticasTextos.kpiSeguimiento), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text(EstadisticasTextos.graficoRoles), findsOneWidget);
      expect(find.text('8 (80%)'), findsOneWidget);
      expect(find.text('1 (10%)'), findsNWidgets(2));
      expect(find.text('Actualizado: 12/11/2026 10:30'), findsOneWidget);
      expect(find.text(EstadisticasTextos.notaFiltro), findsOneWidget);
    });

    testWidgets('las cifras no disponibles salen con "—" y el texto de sin módulo', (tester) async {
      final service = EstadisticasService(client: MockClient((r) async => _json(_ok())));
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      expect(find.text(EstadisticasTextos.sinModuloAdopciones), findsOneWidget);
      expect(find.text(EstadisticasTextos.sinModuloSeguimiento), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('rango inválido: muestra el error y no consulta al backend', (tester) async {
      var llamadas = 0;
      final service = EstadisticasService(
        client: MockClient((r) async {
          llamadas++;
          return _json(_ok());
        }),
      );
      await _abrir(tester, AdminEstadisticasScreen(service: service));
      expect(llamadas, 1);

      // Desde = 20 y Hasta = 10 del mes actual → inválido.
      await tester.tap(find.textContaining('${EstadisticasTextos.desde}:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('${EstadisticasTextos.hasta}:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(EstadisticasTextos.aplicar));
      await tester.pumpAndSettle();

      expect(find.text(EstadisticasTextos.errorRango), findsOneWidget);
      expect(llamadas, 1);
    });

    testWidgets('Aplicar envía el rango y Limpiar vuelve al histórico', (tester) async {
      final consultas = <Map<String, String>>[];
      final service = EstadisticasService(
        client: MockClient((r) async {
          consultas.add(r.url.queryParameters);
          return _json(_ok());
        }),
      );
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      await tester.tap(find.textContaining('${EstadisticasTextos.desde}:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EstadisticasTextos.aplicar));
      await tester.pumpAndSettle();

      expect(consultas.last.keys, ['desde']);

      await tester.tap(find.text(EstadisticasTextos.limpiar));
      await tester.pumpAndSettle();
      expect(consultas.last, isEmpty);
    });

    testWidgets('403: muestra el mensaje sin botón Reintentar', (tester) async {
      final service = EstadisticasService(client: MockClient((r) async => http.Response('', 403)));
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      expect(find.text(EstadisticasTextos.errorSinPermisos), findsOneWidget);
      expect(find.text(EstadisticasTextos.reintentar), findsNothing);
    });

    testWidgets('error de red: muestra Reintentar y se recupera', (tester) async {
      var intento = 0;
      final service = EstadisticasService(
        client: MockClient((r) async {
          intento++;
          if (intento == 1) throw http.ClientException('sin red');
          return _json(_ok());
        }),
      );
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      expect(find.text(EstadisticasTextos.reintentar), findsOneWidget);
      await tester.tap(find.text(EstadisticasTextos.reintentar));
      await tester.pumpAndSettle();
      expect(find.text(EstadisticasTextos.kpiMascotas), findsOneWidget);
    });

    testWidgets('Exportar reporte entrega el CSV y muestra "Reporte exportado"', (tester) async {
      String? nombre;
      Uint8List? contenido;
      final service = EstadisticasService(
        client: MockClient((r) async => r.url.path.endsWith('/exportar')
            ? http.Response.bytes([65, 66], 200)
            : _json(_ok())),
      );
      await _abrir(
        tester,
        AdminEstadisticasScreen(
          service: service,
          descargar: (bytes, n, tipo) {
            contenido = bytes;
            nombre = n;
          },
        ),
      );

      await tester.ensureVisible(find.text(EstadisticasTextos.exportar));
      await tester.tap(find.text(EstadisticasTextos.exportar));
      await tester.pumpAndSettle();

      expect(contenido, Uint8List.fromList([65, 66]));
      expect(nombre, startsWith('reporte_estadisticas_'));
      expect(find.text(EstadisticasTextos.exportado), findsOneWidget);
    });

    testWidgets('Exportar fuera de la web avisa que solo está disponible en web', (tester) async {
      final service = EstadisticasService(client: MockClient((r) async => _json(_ok())));
      await _abrir(tester, AdminEstadisticasScreen(service: service));

      await tester.ensureVisible(find.text(EstadisticasTextos.exportar));
      await tester.tap(find.text(EstadisticasTextos.exportar));
      await tester.pumpAndSettle();

      expect(find.text(EstadisticasTextos.exportarSoloWeb), findsOneWidget);
    });
  });
}
