import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/mascota.dart';
import 'package:sadm/models/mascota_detalle.dart';
import 'package:sadm/models/ubicacion.dart';
import 'package:sadm/screens/mascotas_disponibles_screen.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/busqueda_mascotas_service.dart';
import 'package:sadm/services/ubicacion_service.dart';
import 'package:sadm/theme/app_theme.dart';
import 'package:sadm/utils/geolocalizacion.dart';

/// Proveedor de ubicación simulado: devuelve siempre [resultado] y cuenta las llamadas.
class _ProveedorFalso implements ProveedorUbicacion {
  _ProveedorFalso(this.resultado);

  final ResultadoUbicacion resultado;
  int llamadas = 0;

  @override
  Future<ResultadoUbicacion> obtener() async {
    llamadas++;
    return resultado;
  }
}

http.Response _json(Object cuerpo, [int status = 200]) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _cercanas = [
  {'id': 1, 'nombre': 'Firulais', 'especie': 'PERRO', 'distanciaKm': 0.4},
  {'id': 2, 'nombre': 'Luna', 'especie': 'PERRO', 'distanciaKm': 2.5},
  {'id': 3, 'nombre': 'Vieja', 'especie': 'GATO', 'distanciaKm': null},
];

const _generales = [
  {'id': 1, 'nombre': 'Firulais', 'especie': 'PERRO'},
  {'id': 2, 'nombre': 'Luna', 'especie': 'PERRO'},
];

/// Simula el backend: /mascotas/buscar (con o sin lat/lon) y /perfil/ubicacion.
class _BackendFalso {
  _BackendFalso({this.ubicacionPerfil, this.statusUbicacion = 200});

  /// Ubicación guardada en el perfil; null = 404.
  final Map<String, dynamic>? ubicacionPerfil;
  final int statusUbicacion;

  final busquedas = <Uri>[];
  int consultasUbicacion = 0;

  late final MockClient client = MockClient((request) async {
    if (request.url.path.endsWith('/mascotas/buscar')) {
      busquedas.add(request.url);
      final conCoordenadas = request.url.queryParameters.containsKey('lat');
      return _json(conCoordenadas ? _cercanas : _generales);
    }
    if (request.url.path.endsWith('/perfil/ubicacion')) {
      consultasUbicacion++;
      if (statusUbicacion != 200) {
        return _json({'status': statusUbicacion, 'message': 'Tu sesión expiró.'}, statusUbicacion);
      }
      if (ubicacionPerfil == null) {
        return _json({'status': 404, 'message': 'Aún no registraste tu ubicación de referencia'}, 404);
      }
      return _json({'status': 200, 'message': 'Ubicación consultada', 'data': ubicacionPerfil});
    }
    return _json({'status': 404}, 404);
  });
}

Future<void> _abrir(
  WidgetTester tester,
  _BackendFalso backend,
  _ProveedorFalso proveedor,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MascotasDisponiblesScreen(
        service: BusquedaMascotasService(client: backend.client),
        ubicacionService: UbicacionService(client: backend.client),
        proveedorUbicacion: proveedor,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pulsarBuscarCerca(WidgetTester tester) async {
  await tester.tap(find.text('Buscar cerca de mí'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AuthSession.token = 'token');
  tearDown(AuthSession.limpiar);

  group('formatearDistancia', () {
    test('1 decimal', () {
      expect(formatearDistancia(2.5), '2.5 km');
      expect(formatearDistancia(12.34), '12.3 km');
      expect(formatearDistancia(1.0), '1.0 km');
    });

    test('«< 1 km» si es menor a 1', () {
      expect(formatearDistancia(0.4), '< 1 km');
      expect(formatearDistancia(0.0), '< 1 km');
      expect(formatearDistancia(0.99), '< 1 km');
    });

    test('«Distancia no disponible» si no hay dato', () {
      expect(formatearDistancia(null), 'Distancia no disponible');
    });
  });

  group('modelos', () {
    test('MascotaDetalle lee distanciaKm (entero o decimal) y tolera null', () {
      expect(MascotaDetalle.fromJson({'id': 1, 'nombre': 'A', 'distanciaKm': 2.5}).distanciaKm, 2.5);
      expect(MascotaDetalle.fromJson({'id': 1, 'nombre': 'A', 'distanciaKm': 3}).distanciaKm, 3.0);
      expect(MascotaDetalle.fromJson({'id': 1, 'nombre': 'A', 'distanciaKm': null}).distanciaKm, isNull);
      expect(MascotaDetalle.fromJson({'id': 1, 'nombre': 'A'}).distanciaKm, isNull);
    });

    Mascota mascota({double? lat, double? lon}) => Mascota(
          idDador: 1,
          nombre: 'Firulais',
          especie: 'PERRO',
          edad: 2,
          unidadEdad: 'ANIOS',
          tamano: 'MEDIANO',
          sexo: 'MACHO',
          temperamento: const ['JUGUETON'],
          ubicacion: 'Suba',
          latitud: lat,
          longitud: lon,
        );

    test('Mascota.toJson envía las coordenadas solo si están las dos', () {
      expect(mascota().toJson().containsKey('latitud'), isFalse);
      expect(mascota(lat: 4.7).toJson().containsKey('latitud'), isFalse);
      final json = mascota(lat: 4.741, lon: -74.083).toJson();
      expect(json['latitud'], 4.741);
      expect(json['longitud'], -74.083);
    });
  });

  group('BusquedaMascotasService', () {
    test('sin coordenadas no envía lat ni lon', () async {
      final backend = _BackendFalso();
      final service = BusquedaMascotasService(client: backend.client);
      await service.buscar(nombre: 'lu');
      expect(backend.busquedas.single.queryParameters.containsKey('lat'), isFalse);
      expect(backend.busquedas.single.queryParameters.containsKey('lon'), isFalse);
    });

    test('con coordenadas envía lat y lon y lee distanciaKm', () async {
      final backend = _BackendFalso();
      final service = BusquedaMascotasService(client: backend.client);
      final lista = await service.buscar(lat: 4.65, lon: -74.06);
      expect(backend.busquedas.single.queryParameters['lat'], '4.650000');
      expect(backend.busquedas.single.queryParameters['lon'], '-74.060000');
      expect(lista.map((m) => m.distanciaKm), [0.4, 2.5, null]);
    });
  });

  group('UbicacionService', () {
    test('obtener devuelve null si el perfil no tiene ubicación (404)', () async {
      final service = UbicacionService(client: _BackendFalso().client);
      expect(await service.obtener(), isNull);
    });

    test('obtener lee la ubicación guardada', () async {
      final backend = _BackendFalso(
        ubicacionPerfil: {'latitud': 4.741, 'longitud': -74.083, 'localidad': 'SUBA'},
      );
      final ubicacion = await UbicacionService(client: backend.client).obtener();
      expect(ubicacion?.latitud, 4.741);
      expect(ubicacion?.localidad, 'SUBA');
    });

    test('un 401 se traduce a NoAutenticadoException', () async {
      final service = UbicacionService(client: _BackendFalso(statusUbicacion: 401).client);
      expect(service.obtener(), throwsA(isA<NoAutenticadoException>()));
    });

    test('un 400 muestra el mensaje del campo', () async {
      final client = MockClient(
        (_) async => _json({
          'status': 400,
          'message': 'Error de validación',
          'data': {'latitud': 'La latitud debe estar entre -90 y 90'},
        }, 400),
      );
      final service = UbicacionService(client: client);
      expect(
        service.guardar(const Ubicacion(latitud: 100, longitud: -74)),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'La latitud debe estar entre -90 y 90',
        )),
      );
    });
  });

  group('Buscar cerca de mí', () {
    testWidgets('permiso concedido: busca con lat/lon, ordena y muestra distancias', (tester) async {
      final backend = _BackendFalso();
      final proveedor = _ProveedorFalso(const UbicacionObtenida(4.65, -74.06));
      await _abrir(tester, backend, proveedor);
      expect(find.text('Buscar cerca de mí'), findsOneWidget);
      expect(find.text('0.4 km'), findsNothing);

      await _pulsarBuscarCerca(tester);
      expect(find.text('¿Permitir acceso a su ubicación?'), findsOneWidget);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(proveedor.llamadas, 1);
      expect(backend.consultasUbicacion, 0, reason: 'con GPS no hace falta la ubicación del perfil');
      final ultima = backend.busquedas.last.queryParameters;
      expect(ultima['lat'], '4.650000');
      expect(ultima['lon'], '-74.060000');

      expect(find.text('Geolocalización activa'), findsOneWidget);
      expect(find.text('Desactivar geolocalización'), findsOneWidget);
      expect(find.text('< 1 km'), findsOneWidget);
      expect(find.text('2.5 km'), findsOneWidget);
      expect(find.text('Distancia no disponible'), findsOneWidget);
      expect(find.textContaining('No pudimos acceder'), findsNothing);
    });

    testWidgets('desactivar vuelve al listado general sin lat/lon', (tester) async {
      final backend = _BackendFalso();
      await _abrir(tester, backend, _ProveedorFalso(const UbicacionObtenida(4.65, -74.06)));
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desactivar geolocalización'));
      await tester.pumpAndSettle();

      expect(backend.busquedas.last.queryParameters.containsKey('lat'), isFalse);
      expect(find.text('Buscar cerca de mí'), findsOneWidget);
      expect(find.text('Desactivar geolocalización'), findsNothing);
      expect(find.text('< 1 km'), findsNothing);
      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets('permiso negado con ubicación en el perfil: usa la del perfil y avisa', (tester) async {
      final backend = _BackendFalso(
        ubicacionPerfil: {'latitud': 4.741, 'longitud': -74.083, 'localidad': 'SUBA'},
      );
      await _abrir(tester, backend, _ProveedorFalso(const PermisoNegado()));
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(backend.consultasUbicacion, 1);
      expect(backend.busquedas.last.queryParameters['lat'], '4.741000');
      expect(backend.busquedas.last.queryParameters['lon'], '-74.083000');
      expect(
        find.text('No pudimos acceder a tu ubicación. Mostrando resultados según tu ubicación registrada'),
        findsOneWidget,
      );
      expect(find.text('Ubicación de tu perfil'), findsOneWidget);
      expect(find.text('Ir a mi perfil'), findsNothing);
      expect(find.text('2.5 km'), findsOneWidget);
    });

    testWidgets('«Ahora no» también usa la ubicación del perfil sin pedir el GPS', (tester) async {
      final backend = _BackendFalso(
        ubicacionPerfil: {'latitud': 4.741, 'longitud': -74.083},
      );
      final proveedor = _ProveedorFalso(const UbicacionObtenida(1, 1));
      await _abrir(tester, backend, proveedor);
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(proveedor.llamadas, 0);
      expect(backend.busquedas.last.queryParameters['lat'], '4.741000');
      expect(find.textContaining('Mostrando resultados según tu ubicación registrada'), findsOneWidget);
    });

    testWidgets('fallo del GPS (no disponible) también usa la ubicación del perfil', (tester) async {
      final backend = _BackendFalso(ubicacionPerfil: {'latitud': 4.741, 'longitud': -74.083});
      await _abrir(tester, backend, _ProveedorFalso(const UbicacionNoDisponible()));
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(backend.busquedas.last.queryParameters['lat'], '4.741000');
      expect(find.textContaining('No pudimos acceder a tu ubicación'), findsOneWidget);
    });

    testWidgets('permiso negado y sin ubicación en el perfil: aviso + «Ir a mi perfil», lista general', (tester) async {
      final backend = _BackendFalso(); // perfil sin ubicación → 404
      await _abrir(tester, backend, _ProveedorFalso(const PermisoNegado()));
      final busquedasAntes = backend.busquedas.length;
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos acceder a tu ubicación. Registra tu ubicación de referencia en tu perfil'),
        findsOneWidget,
      );
      expect(find.text('Ir a mi perfil'), findsOneWidget);
      expect(find.text('Buscar cerca de mí'), findsOneWidget, reason: 'no queda activa la geolocalización');
      expect(backend.busquedas.length, busquedasAntes, reason: 'sigue el listado general, sin nueva búsqueda');
      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets('sesión expirada (401) al leer la ubicación del perfil muestra el mensaje', (tester) async {
      final backend = _BackendFalso(statusUbicacion: 401);
      await _abrir(tester, backend, _ProveedorFalso(const PermisoNegado()));
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión expiró.'), findsOneWidget);
      expect(find.text('Buscar cerca de mí'), findsOneWidget);
    });

    testWidgets('cerrar el diálogo sin elegir no hace nada', (tester) async {
      final backend = _BackendFalso();
      final proveedor = _ProveedorFalso(const UbicacionObtenida(4.65, -74.06));
      await _abrir(tester, backend, proveedor);
      await _pulsarBuscarCerca(tester);

      await tester.tapAt(const Offset(5, 5)); // fuera del diálogo
      await tester.pumpAndSettle();

      expect(proveedor.llamadas, 0);
      expect(backend.consultasUbicacion, 0);
      expect(find.text('Buscar cerca de mí'), findsOneWidget);
    });

    testWidgets('la cercanía se combina con la búsqueda por nombre', (tester) async {
      final backend = _BackendFalso();
      await _abrir(tester, backend, _ProveedorFalso(const UbicacionObtenida(4.65, -74.06)));
      await _pulsarBuscarCerca(tester);
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'lun');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final ultima = backend.busquedas.last.queryParameters;
      expect(ultima['nombre'], 'lun');
      expect(ultima['lat'], '4.650000');
    });
  });
}
