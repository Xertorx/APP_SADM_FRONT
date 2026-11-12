import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/config/admin_usuarios_textos.dart';
import 'package:sadm/models/usuario_admin.dart';
import 'package:sadm/screens/admin_usuario_detalle_screen.dart';
import 'package:sadm/screens/admin_usuarios_screen.dart';
import 'package:sadm/screens/inhabilitar_cuenta_dialog.dart';
import 'package:sadm/services/admin_usuarios_service.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/theme/app_theme.dart';
import 'package:sadm/utils/admin_validators.dart';

http.Response _json(Object cuerpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _fila({
  int id = 1,
  String nombre = 'María',
  String apellido = 'González',
  String rol = 'USUARIO',
  String estado = 'ACTIVO',
  Object? fecha = '2026-09-15T10:00:00.000+00:00',
}) =>
    {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'correo': 'maria$id@correo.com',
      'rol': rol,
      'estado': estado,
      'fechaRegistro': fecha,
    };

Map<String, dynamic> _detalle({
  String estado = 'ACTIVO',
  String rol = 'USUARIO',
  List<Map<String, dynamic>> historial = const [],
}) =>
    {
      ..._fila(estado: estado, rol: rol),
      'telefono': '3001234567',
      'direccion': 'Bogotá, Suba',
      'tieneFoto': false,
      'actividad': {'mascotasPublicadas': 3, 'postulaciones': 2},
      'historial': historial,
    };

Future<void> _abrir(WidgetTester tester, Widget pantalla, {double ancho = 900}) async {
  tester.view.physicalSize = Size(ancho, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: pantalla));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  group('Modelo', () {
    test('interpreta una fila (fecha ISO) y no expone datos sensibles', () {
      final u = UsuarioAdmin.fromJson(_fila());
      expect(u.id, 1);
      expect(u.nombreCompleto, 'María González');
      expect(u.estado, 'ACTIVO');
      expect(u.fechaRegistro, isNotNull);
      expect(u.toJson().keys, isNot(contains('passwordHash')));
      expect(u.toJson().keys, isNot(contains('identificacion')));
    });

    test('acepta la fecha como milisegundos y tolera campos ausentes', () {
      final u = UsuarioAdmin.fromJson({'id': 2, 'fechaRegistro': 1789000000000});
      expect(u.fechaRegistro, DateTime.fromMillisecondsSinceEpoch(1789000000000));
      expect(u.nombre, isEmpty);
      expect(UsuarioAdmin.fromJson({'id': 3}).fechaRegistro, isNull);
    });

    test('interpreta el detalle con actividad e historial', () {
      final d = UsuarioAdminDetalle.fromJson(_detalle(historial: [
        {
          'fecha': '2026-10-01T15:00:00Z',
          'accion': 'INHABILITAR',
          'motivo': 'Datos falsos en publicaciones',
          'adminNombre': 'Diego Admin',
        },
        {'fecha': '2026-10-02T15:00:00Z', 'accion': 'REACTIVAR', 'motivo': null, 'adminNombre': 'Diego Admin'},
      ]));
      expect(d.mascotasPublicadas, 3);
      expect(d.postulaciones, 2);
      expect(d.telefono, '3001234567');
      expect(d.historial, hasLength(2));
      expect(d.historial.first.esInhabilitacion, isTrue);
      expect(d.historial.first.motivo, 'Datos falsos en publicaciones');
      expect(d.historial.last.motivo, isNull);
      expect(d.historial.last.accionTexto, 'Reactivada');
    });

    test('estado y rol se muestran en español', () {
      expect(estadoTexto('ACTIVO'), 'Activo');
      expect(estadoTexto('INHABILITADO'), 'Inhabilitado');
      expect(rolTexto('FUNDACION'), 'Fundación');
    });

    test('filtrarUsuarios combina rol y estado (null = Todos)', () {
      final lista = [
        UsuarioAdmin.fromJson(_fila(id: 1)),
        UsuarioAdmin.fromJson(_fila(id: 2, rol: 'FUNDACION')),
        UsuarioAdmin.fromJson(_fila(id: 3, estado: 'INHABILITADO')),
      ];
      expect(filtrarUsuarios(lista), hasLength(3));
      expect(filtrarUsuarios(lista, rol: 'FUNDACION').map((u) => u.id), [2]);
      expect(filtrarUsuarios(lista, estado: 'INHABILITADO').map((u) => u.id), [3]);
      expect(filtrarUsuarios(lista, rol: 'FUNDACION', estado: 'INHABILITADO'), isEmpty);
    });
  });

  group('Botón según estado', () {
    test('activa → Inhabilitar; inhabilitada → Reactivar', () {
      expect(UsuarioAdminDetalle.fromJson(_detalle()).accionDisponible, AccionCuenta.inhabilitar);
      expect(
        UsuarioAdminDetalle.fromJson(_detalle(estado: 'INHABILITADO')).accionDisponible,
        AccionCuenta.reactivar,
      );
    });

    test('a un administrador no se le ofrece inhabilitar', () {
      expect(UsuarioAdminDetalle.fromJson(_detalle(rol: 'ADMINISTRADOR')).accionDisponible, isNull);
    });
  });

  group('Motivo obligatorio', () {
    test('vacío o solo espacios → "El motivo es obligatorio"', () {
      expect(AdminValidators.motivo(null), 'El motivo es obligatorio');
      expect(AdminValidators.motivo(''), 'El motivo es obligatorio');
      expect(AdminValidators.motivo('     '), 'El motivo es obligatorio');
    });

    test('debe tener entre 10 y 300 caracteres', () {
      expect(AdminValidators.motivo('corto'), AdminUsuariosTextos.motivoLongitud);
      expect(AdminValidators.motivo('a' * 301), AdminUsuariosTextos.motivoLongitud);
      expect(AdminValidators.motivo('a' * 10), isNull);
      expect(AdminValidators.motivo('a' * 300), isNull);
    });
  });

  group('AdminUsuariosService', () {
    test('buscar manda el nombre y el token', () async {
      late http.Request pedido;
      final service = AdminUsuariosService(client: MockClient((r) async {
        pedido = r;
        return _json({'status': 200, 'data': [_fila()]});
      }));
      final lista = await service.buscar('  mar ');
      expect(lista, hasLength(1));
      expect(pedido.url.path, endsWith('/admin/usuarios'));
      expect(pedido.url.queryParameters['nombre'], 'mar');
      expect(pedido.headers['Authorization'], 'Bearer token');
    });

    test('mapea 401, 403, 404 y 409', () async {
      Future<Object> con(int status, String mensaje) {
        final s = AdminUsuariosService(
          client: MockClient((_) async => _json({'status': status, 'message': mensaje}, status)),
        );
        return s.reactivar(1).then<Object>((_) => 'ok').catchError((Object e) => e);
      }

      expect(await con(401, 'x'), isA<NoAutenticadoException>());
      expect(await con(403, 'x'), isA<SinPermisosException>());
      expect(await con(404, 'El usuario no existe'), isA<NotFoundException>());
      final conflicto = await con(409, 'La cuenta ya está activa');
      expect(conflicto, isA<ValidationException>());
      expect((conflicto as ApiException).message, 'La cuenta ya está activa');
    });
  });

  group('Pantalla de búsqueda', () {
    testWidgets('sin coincidencias muestra el mensaje exacto', (tester) async {
      final service = AdminUsuariosService(
        client: MockClient((_) async => _json({'status': 200, 'data': []})),
      );
      await _abrir(tester, AdminUsuariosScreen(service: service));

      expect(find.text('No se encontraron usuarios con ese nombre'), findsOneWidget);
      expect(find.text('Buscar usuario por nombre...'), findsOneWidget);
    });

    testWidgets('en pantalla ancha muestra tabla con estado en español y "Ver detalle"', (tester) async {
      final service = AdminUsuariosService(
        client: MockClient((_) async => _json({
              'status': 200,
              'data': [_fila(), _fila(id: 2, nombre: 'Pedro', estado: 'INHABILITADO')],
            })),
      );
      await _abrir(tester, AdminUsuariosScreen(service: service));

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('María González'), findsOneWidget);
      expect(find.text('Activo'), findsWidgets);
      expect(find.text('Inhabilitado'), findsWidgets);
      expect(find.text('Ver detalle'), findsNWidgets(2));
      expect(find.textContaining('2 usuarios encontrados'), findsOneWidget);
    });

    testWidgets('en pantalla angosta muestra tarjetas', (tester) async {
      final service = AdminUsuariosService(
        client: MockClient((_) async => _json({'status': 200, 'data': [_fila()]})),
      );
      await _abrir(tester, AdminUsuariosScreen(service: service), ancho: 500);

      expect(find.byType(DataTable), findsNothing);
      expect(find.text('María González'), findsOneWidget);
      expect(find.text('Ver detalle'), findsOneWidget);
    });

    testWidgets('el botón Buscar envía el texto escrito', (tester) async {
      final consultas = <String?>[];
      final service = AdminUsuariosService(client: MockClient((r) async {
        consultas.add(r.url.queryParameters['nombre']);
        return _json({'status': 200, 'data': []});
      }));
      await _abrir(tester, AdminUsuariosScreen(service: service));

      await tester.enterText(find.byType(TextField), 'mar');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(consultas, ['', 'mar']); // la primera es la carga inicial (todos)
    });

    testWidgets('el filtro de Estado se aplica en el cliente', (tester) async {
      var pedidos = 0;
      final service = AdminUsuariosService(client: MockClient((_) async {
        pedidos++;
        return _json({
          'status': 200,
          'data': [_fila(), _fila(id: 2, nombre: 'Pedro', estado: 'INHABILITADO')],
        });
      }));
      await _abrir(tester, AdminUsuariosScreen(service: service));

      await tester.tap(find.text('Todos').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inhabilitado').last);
      await tester.pumpAndSettle();

      expect(find.text('Pedro González'), findsOneWidget);
      expect(find.text('María González'), findsNothing);
      expect(pedidos, 1); // sin nueva llamada al backend
    });
  });

  group('Pantalla de detalle', () {
    Future<void> abrirDetalle(WidgetTester tester, Map<String, dynamic> datos) async {
      final service = AdminUsuariosService(
        client: MockClient((_) async => _json({'status': 200, 'data': datos})),
      );
      await _abrir(tester, AdminUsuarioDetalleScreen(usuarioId: 1, service: service));
    }

    testWidgets('cuenta activa → botón "Inhabilitar cuenta" y actividad', (tester) async {
      await abrirDetalle(tester, _detalle());

      expect(find.text('Inhabilitar cuenta'), findsOneWidget);
      expect(find.text('Reactivar cuenta'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Mascotas publicadas'), findsOneWidget);
      expect(find.text('Sin inhabilitaciones ni reactivaciones'), findsOneWidget);
    });

    testWidgets('cuenta inhabilitada → botón "Reactivar cuenta"', (tester) async {
      await abrirDetalle(tester, _detalle(estado: 'INHABILITADO'));

      expect(find.text('Reactivar cuenta'), findsOneWidget);
      expect(find.text('Inhabilitar cuenta'), findsNothing);
    });

    testWidgets('reactivar muestra el éxito y cambia el botón', (tester) async {
      final service = AdminUsuariosService(client: MockClient((r) async {
        if (r.method == 'POST') return _json({'status': 200, 'data': _detalle()});
        return _json({'status': 200, 'data': _detalle(estado: 'INHABILITADO')});
      }));
      await _abrir(tester, AdminUsuarioDetalleScreen(usuarioId: 1, service: service));

      await tester.tap(find.text('Reactivar cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta reactivada correctamente'), findsOneWidget);
      expect(find.text('Inhabilitar cuenta'), findsOneWidget);
    });

    testWidgets('usuario inexistente muestra el error y no ofrece reintentar', (tester) async {
      final service = AdminUsuariosService(
        client: MockClient((_) async => _json({'status': 404, 'message': 'El usuario no existe'}, 404)),
      );
      await _abrir(tester, AdminUsuarioDetalleScreen(usuarioId: 9, service: service));

      expect(find.text('El usuario no existe'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('Diálogo de inhabilitación', () {
    Future<List<http.Request>> abrirDialogo(WidgetTester tester) async {
      final pedidos = <http.Request>[];
      final service = AdminUsuariosService(client: MockClient((r) async {
        pedidos.add(r);
        return _json({'status': 200, 'data': _detalle(estado: 'INHABILITADO')});
      }));
      await _abrir(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<UsuarioAdminDetalle>(
                context: context,
                builder: (_) => InhabilitarCuentaDialog(
                  usuario: UsuarioAdmin.fromJson(_fila()),
                  service: service,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return pedidos;
    }

    testWidgets('pide confirmación con el nombre y no envía sin motivo', (tester) async {
      final pedidos = await abrirDialogo(tester);

      expect(find.text('¿Confirmas inhabilitar la cuenta de María González?'), findsOneWidget);

      await tester.tap(find.text('Inhabilitar cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('El motivo es obligatorio'), findsOneWidget);
      expect(pedidos, isEmpty);
    });

    testWidgets('con motivo válido envía la solicitud y se cierra', (tester) async {
      final pedidos = await abrirDialogo(tester);

      await tester.enterText(find.byType(TextFormField), 'Publicó mascotas con datos falsos');
      await tester.tap(find.text('Inhabilitar cuenta'));
      await tester.pumpAndSettle();

      expect(pedidos, hasLength(1));
      expect(pedidos.single.url.path, endsWith('/admin/usuarios/1/inhabilitar'));
      expect(jsonDecode(pedidos.single.body)['motivo'], 'Publicó mascotas con datos falsos');
      expect(find.byType(InhabilitarCuentaDialog), findsNothing);
    });
  });

  group('AuthSession.rol', () {
    String jwtCon(Map<String, Object> payload) {
      String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      return '${b64({'alg': 'HS256'})}.${b64(payload)}.firma';
    }

    test('lee el claim role del token', () {
      AuthSession.iniciar(jwtCon({'userId': 5, 'role': 'ADMINISTRADOR'}));
      expect(AuthSession.rol, 'ADMINISTRADOR');
      expect(AuthSession.esAdministrador, isTrue);

      AuthSession.iniciar(jwtCon({'userId': 6, 'role': 'USUARIO'}));
      expect(AuthSession.esAdministrador, isFalse);
    });

    test('un token opaco no da rol y limpiar lo borra', () {
      AuthSession.iniciar('token-opaco');
      expect(AuthSession.rol, isNull);
      expect(AuthSession.esAdministrador, isFalse);

      AuthSession.iniciar(jwtCon({'userId': 5, 'role': 'ADMINISTRADOR'}));
      AuthSession.limpiar();
      expect(AuthSession.rol, isNull);
    });
  });
}
