import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/configuracion_seleccion.dart';
import 'package:sadm/screens/configuracion_seleccion_screen.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/configuracion_seleccion_service.dart';
import 'package:sadm/theme/app_theme.dart';
import 'package:sadm/utils/configuracion_validators.dart';

Map<String, dynamic> _json({
  bool definitiva = false,
  int preguntas = 30,
  int documentos = 20,
  int entrevista = 25,
  int visita = 25,
  bool conElementos = true,
}) =>
    {
      'mascotaId': 12,
      'definitiva': definitiva,
      'preguntas': {
        'puntajeMaximo': preguntas,
        'elementos': [
          if (conElementos)
            {
              'id': 1,
              'texto': '¿Cuántas horas estaría sola la mascota?',
              'tipoRespuesta': 'SELECCION_UNICA',
              'puntaje': 10,
              'opciones': ['Menos de 2', 'De 2 a 5', 'Más de 5'],
            },
        ],
      },
      'documentos': {
        'puntajeMaximo': documentos,
        'elementos': [
          if (conElementos)
            {
              'id': 2,
              'nombre': 'Documento de identidad',
              'descripcion': 'Copia legible',
              'obligatorio': true,
              'puntajeMaximo': 20,
            },
        ],
      },
      'entrevista': {
        'puntajeMaximo': entrevista,
        'criterios': [
          if (conElementos) {'id': 3, 'descripcion': 'Experiencia previa', 'puntajeMaximo': 25},
        ],
      },
      'visitaDomiciliaria': {
        'puntajeMaximo': visita,
        'criterios': [
          if (conElementos) {'id': 4, 'descripcion': 'Espacio seguro', 'puntajeMaximo': 25},
        ],
      },
    };

http.Response _respuesta(Object data, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode({'status': status, 'message': 'ok', 'data': data})),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ConfiguracionSeleccion _config([Map<String, dynamic>? json]) =>
    ConfiguracionSeleccion.fromJson(json ?? _json(), mascotaId: 12);

void main() {
  setUp(() => AuthSession.iniciar('token-de-prueba'));
  tearDown(AuthSession.limpiar);

  group('ConfiguracionSeleccion', () {
    test('interpreta la respuesta del backend', () {
      final c = _config();
      expect(c.mascotaId, 12);
      expect(c.definitiva, isFalse);
      expect(c.puntajeDistribuido, 100);
      expect(c.puntosPendientes, 0);
      expect(c.puntosExcedentes, 0);
      final pregunta = c.preguntas.elementos.single;
      expect(pregunta.id, 1);
      expect(pregunta.tipoRespuesta, TipoRespuesta.seleccionUnica);
      expect(pregunta.opciones, hasLength(3));
      expect(c.documentos.elementos.single.obligatorio, isTrue);
      expect(c.entrevista.elementos.single.puntajeMaximo, 25);
      expect(c.visitaDomiciliaria.elementos.single.descripcion, 'Espacio seguro');
    });

    test('una configuración vacía tiene 100 puntos pendientes', () {
      final c = _config({'mascotaId': 5, 'definitiva': false});
      expect(c.puntajeDistribuido, 0);
      expect(c.puntosPendientes, 100);
      expect(c.etapas.every((e) => e.datos.elementos.isEmpty), isTrue);
    });

    test('calcula puntos excedentes', () {
      final c = _config(_json(preguntas: 50));
      expect(c.puntajeDistribuido, 120);
      expect(c.puntosExcedentes, 20);
      expect(c.puntosPendientes, 0);
    });

    test('toJson envía las cuatro etapas, ids existentes y opciones vacías si no aplica', () {
      final c = _config().copyWith(
        preguntas: _config().preguntas.conElementos(const [
          PreguntaSeleccion(
            id: 1,
            texto: 'q',
            tipoRespuesta: TipoRespuesta.siNo,
            puntaje: 5,
            opciones: ['x', 'y'],
          ),
          PreguntaSeleccion(texto: 'nueva', tipoRespuesta: TipoRespuesta.texto, puntaje: 5),
        ]),
      );
      final json = c.toJson();
      final elementos = (json['preguntas'] as Map)['elementos'] as List;
      expect(elementos[0]['id'], 1);
      expect(elementos[0]['opciones'], isEmpty);
      expect(elementos[1].containsKey('id'), isFalse);
      expect(elementos[1]['tipoRespuesta'], 'TEXTO');
      expect((json['entrevista'] as Map)['criterios'], isNotEmpty);
      expect((json['visitaDomiciliaria'] as Map)['puntajeMaximo'], 25);
      expect((json['documentos'] as Map)['puntajeMaximo'], 20);
    });
  });

  group('ConfiguracionValidators', () {
    test('una configuración correcta no tiene errores', () {
      expect(ConfiguracionValidators.paraFinalizar(_config()), isEmpty);
    });

    test('exige al menos un criterio por etapa', () {
      final errores = ConfiguracionValidators.paraFinalizar(_config(_json(conElementos: false)));
      expect(errores.where((e) => e.contains('al menos un criterio')), hasLength(4));
      expect(ConfiguracionValidators.paraGuardar(_config(_json(conElementos: false))), isEmpty);
    });

    test('exige exactamente 100 puntos', () {
      expect(
        ConfiguracionValidators.distribucion(_config(_json(visita: 20))).single,
        contains('Faltan 5 puntos'),
      );
      expect(
        ConfiguracionValidators.distribucion(_config(_json(visita: 30))).single,
        contains('5 puntos de más'),
      );
    });

    test('un criterio no puede superar el máximo de su etapa', () {
      final errores = ConfiguracionValidators.paraFinalizar(_config(_json(documentos: 10)));
      expect(errores.any((e) => e.contains('supera el máximo')), isTrue);
    });

    test('la suma de criterios no puede superar el máximo de la etapa', () {
      final c = _config();
      final con = c.copyWith(
        entrevista: c.entrevista.conElementos(const [
          CriterioSeleccion(descripcion: 'a', puntajeMaximo: 20),
          CriterioSeleccion(descripcion: 'b', puntajeMaximo: 20),
        ]),
      );
      expect(
        ConfiguracionValidators.paraGuardar(con).single,
        contains('suman 40 pts y superan el máximo'),
      );
    });

    test('puntajes negativos y fuera de rango', () {
      expect(ConfiguracionValidators.puntaje('-1'), contains('negativo'));
      expect(ConfiguracionValidators.puntaje('101'), contains('100'));
      expect(ConfiguracionValidators.puntaje(''), isNotNull);
      expect(ConfiguracionValidators.puntaje('abc'), isNotNull);
      expect(ConfiguracionValidators.puntaje('0'), isNull);
      expect(
        ConfiguracionValidators.paraGuardar(_config(_json(preguntas: -5))).first,
        contains('negativo'),
      );
    });

    test('opciones según el tipo de respuesta', () {
      expect(ConfiguracionValidators.opciones(TipoRespuesta.texto, const []), isNull);
      expect(ConfiguracionValidators.opciones(TipoRespuesta.siNo, const []), isNull);
      expect(ConfiguracionValidators.opciones(TipoRespuesta.seleccionUnica, const ['a']), isNotNull);
      expect(
        ConfiguracionValidators.opciones(TipoRespuesta.seleccionMultiple, const ['a', 'A']),
        contains('distintas'),
      );
      expect(
        ConfiguracionValidators.opciones(TipoRespuesta.seleccionMultiple, const ['a', 'b']),
        isNull,
      );
    });
  });

  group('ConfiguracionSeleccionService', () {
    test('obtener hace GET con el token y la ruta de la mascota', () async {
      late http.Request recibida;
      final service = ConfiguracionSeleccionService(
        client: MockClient((r) async {
          recibida = r;
          return _respuesta(_json());
        }),
      );

      final c = await service.obtener(12);

      expect(recibida.method, 'GET');
      expect(recibida.url.path, endsWith('/mascotas/12/configuracion-seleccion'));
      expect(recibida.headers['Authorization'], 'Bearer token-de-prueba');
      expect(c.puntajeDistribuido, 100);
    });

    test('guardar hace PUT con el agregado completo y devuelve los ids', () async {
      late http.Request recibida;
      final service = ConfiguracionSeleccionService(
        client: MockClient((r) async {
          recibida = r;
          return _respuesta(_json());
        }),
      );

      await service.guardar(_config());

      expect(recibida.method, 'PUT');
      expect(recibida.headers['Content-Type'], contains('application/json'));
      final cuerpo = jsonDecode(recibida.body) as Map<String, dynamic>;
      expect(cuerpo.keys, containsAll(['preguntas', 'documentos', 'entrevista', 'visitaDomiciliaria']));
    });

    test('finalizar y publicar usan POST sin body', () async {
      final llamadas = <String>[];
      final service = ConfiguracionSeleccionService(
        client: MockClient((r) async {
          llamadas.add('${r.method} ${r.url.path}');
          expect(r.body, isEmpty);
          return r.url.path.endsWith('/finalizar')
              ? _respuesta(_json(definitiva: true))
              : _respuesta({});
        }),
      );

      expect((await service.finalizar(12)).definitiva, isTrue);
      await service.publicar(12);

      expect(llamadas[0], endsWith('POST /SADM/api/mascotas/12/configuracion-seleccion/finalizar'));
      expect(llamadas[1], endsWith('POST /SADM/api/mascotas/12/publicar'));
    });

    test('traduce los errores HTTP', () async {
      ConfiguracionSeleccionService con(int status, [String? mensaje]) =>
          ConfiguracionSeleccionService(
            client: MockClient((_) async => http.Response.bytes(
                  utf8.encode(jsonEncode({'status': status, 'message': mensaje, 'data': null})),
                  status,
                )),
          );

      await expectLater(
        con(400, 'Distribución inválida').finalizar(1),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Distribución inválida')),
      );
      await expectLater(con(403).obtener(1), throwsA(isA<SinPermisosException>()));
      await expectLater(con(404).obtener(1), throwsA(isA<NotFoundException>()));
      await expectLater(con(409, 'No editable').guardar(_config()), throwsA(isA<ConflictoException>()));
      await expectLater(
        ConfiguracionSeleccionService(client: MockClient((_) async => throw Exception('x')))
            .obtener(1),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('ConfiguracionSeleccionScreen', () {
    late List<String> llamadas;
    late Map<String, dynamic> servidor;
    late Map<String, dynamic>? ultimoPut;

    ConfiguracionSeleccionService fake() => ConfiguracionSeleccionService(
          client: MockClient((r) async {
            llamadas.add('${r.method} ${r.url.path.split('/mascotas/').last}');
            if (r.method == 'PUT') {
              ultimoPut = jsonDecode(r.body) as Map<String, dynamic>;
              servidor = {..._json(), ...ultimoPut!, 'mascotaId': 12};
              return _respuesta(servidor);
            }
            if (r.url.path.endsWith('/finalizar')) {
              return _respuesta({...servidor, 'definitiva': true});
            }
            if (r.url.path.endsWith('/publicar')) return _respuesta({});
            return _respuesta(servidor);
          }),
        );

    Future<void> abrir(WidgetTester tester, {bool soloLectura = false}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ConfiguracionSeleccionScreen(
            mascotaId: 12,
            nombreMascota: 'Firulais',
            soloLectura: soloLectura,
            service: fake(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      llamadas = [];
      ultimoPut = null;
      servidor = _json();
    });

    testWidgets('carga la configuración existente y muestra la distribución', (tester) async {
      await abrir(tester);

      expect(llamadas, ['GET 12/configuracion-seleccion']);
      expect(find.text('100 / 100'), findsOneWidget);
      expect(find.text('Distribución completa: 100 puntos asignados.'), findsOneWidget);
      expect(find.text('¿Cuántas horas estaría sola la mascota?'), findsOneWidget);
      expect(find.text('Finalizar configuración'), findsOneWidget);
    });

    testWidgets('modificar un máximo actualiza total, pendientes y bloquea finalizar',
        (tester) async {
      await abrir(tester);

      await tester.enterText(find.byKey(const Key('maximo-visita')), '10');
      await tester.pump();

      expect(find.text('85 / 100'), findsOneWidget);
      expect(find.text('Pendientes: 15 pts por distribuir'), findsOneWidget);
      final finalizar = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Finalizar configuración'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(finalizar.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('maximo-visita')), '40');
      await tester.pump();
      expect(find.text('115 / 100'), findsOneWidget);
      expect(find.text('Excedentes: 15 pts de más'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('maximo-visita')), '-3');
      await tester.pump();
      expect(find.text('El puntaje no puede ser negativo'), findsOneWidget);
    });

    testWidgets('los datos se conservan al cambiar de etapa', (tester) async {
      await abrir(tester);

      await tester.tap(find.byKey(const Key('etapa-documentos')));
      await tester.pump();
      expect(find.text('Documento de identidad'), findsOneWidget);
      await tester.tap(find.byKey(const Key('etapa-entrevista')));
      await tester.pump();
      await tester.tap(find.text('Agregar criterio'));
      await tester.pumpAndSettle();
      expect(find.text('Disponible en la etapa: 0 de 25 pts'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('etapa-preguntas')));
      await tester.pump();
      expect(find.text('¿Cuántas horas estaría sola la mascota?'), findsOneWidget);
    });

    testWidgets('agrega un criterio, no permite superar el máximo y guarda con PUT',
        (tester) async {
      servidor = _json(entrevista: 40);
      await abrir(tester);

      await tester.tap(find.byKey(const Key('etapa-entrevista')));
      await tester.pump();
      await tester.tap(find.text('Agregar criterio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción del criterio'), 'Trato');
      await tester.enterText(find.widgetWithText(TextFormField, 'Puntaje máximo'), '20');
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Supera el máximo de la etapa'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Puntaje máximo'), '15');
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();

      expect(find.text('Trato'), findsOneWidget);
      expect(find.text('Hay cambios sin guardar.'), findsOneWidget);

      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();

      expect(llamadas.last, 'PUT 12/configuracion-seleccion');
      final criterios = (ultimoPut!['entrevista'] as Map)['criterios'] as List;
      expect(criterios, hasLength(2));
      expect(criterios.first['id'], 3);
      expect(criterios.last.containsKey('id'), isFalse);
      expect(find.text('Configuración guardada como borrador.'), findsOneWidget);
    });

    testWidgets('finaliza y luego permite enviar a revisión', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Finalizar configuración'));
      await tester.pumpAndSettle();
      expect(llamadas.last, 'POST 12/configuracion-seleccion/finalizar');
      expect(find.textContaining('Configuración finalizada'), findsOneWidget);

      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(llamadas.last, 'POST 12/publicar');
      expect(find.textContaining('en revisión por el administrador'), findsOneWidget);
      expect(find.text('Guardar borrador'), findsNothing);
    });

    testWidgets('una configuración vacía no se puede finalizar y explica por qué', (tester) async {
      servidor = {'mascotaId': 12, 'definitiva': false};
      await abrir(tester);

      expect(find.text('Pendientes: 100 pts por distribuir'), findsOneWidget);
      expect(find.text('Para finalizar la configuración'), findsOneWidget);
      expect(find.textContaining('Preguntas: agrega al menos un criterio.'), findsOneWidget);
    });

    testWidgets('en solo lectura oculta las acciones de edición', (tester) async {
      await abrir(tester, soloLectura: true);

      expect(find.textContaining('bloqueada'), findsOneWidget);
      expect(find.text('Agregar pregunta'), findsNothing);
      expect(find.text('Guardar borrador'), findsNothing);
    });
  });
}
