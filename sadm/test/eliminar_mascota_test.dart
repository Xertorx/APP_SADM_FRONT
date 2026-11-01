import 'package:flutter_test/flutter_test.dart';
import 'package:sadm/models/mascota_eliminacion.dart';
import 'package:sadm/screens/eliminar_mascota_dialog.dart';

void main() {
  group('MascotaEliminacion', () {
    test('interpreta la respuesta del backend', () {
      final datos = MascotaEliminacion.fromJson({
        'id': 12,
        'nombre': 'Firulais',
        'especie': 'PERRO',
        'raza': 'Labrador',
        'edad': 3,
        'unidadEdad': 'ANIOS',
        'fechaPublicacion': '2026-10-20T10:00:00.000+00:00',
        'primeraFotoId': 5,
        'postulacionesActivas': 3,
      });

      expect(datos.id, 12);
      expect(datos.nombre, 'Firulais');
      expect(datos.datosClave, 'Perro · Labrador · 3 años');
      expect(datos.primeraFotoId, 5);
      expect(datos.fotoUrl, endsWith('/mascotas/fotos/5'));
      expect(datos.postulacionesActivas, 3);
      expect(datos.tienePostulacionesActivas, isTrue);
    });

    test('tolera campos opcionales ausentes', () {
      final datos = MascotaEliminacion.fromJson({
        'id': 1,
        'nombre': 'Luna',
        'postulacionesActivas': 0,
      });

      expect(datos.tienePostulacionesActivas, isFalse);
      expect(datos.fotoUrl, isNull);
      expect(datos.datosClave, isEmpty);
      expect(datos.publicadaHace(), isNull);
    });

    test('calcula "Publicada hace N días"', () {
      final datos = MascotaEliminacion.fromJson({
        'id': 1,
        'nombre': 'Luna',
        'fechaPublicacion': DateTime(2026, 10, 20).millisecondsSinceEpoch,
        'postulacionesActivas': 0,
      });

      expect(datos.publicadaHace(DateTime(2026, 11, 1)), 'Publicada hace 12 días');
      expect(datos.publicadaHace(DateTime(2026, 10, 21)), 'Publicada hace 1 día');
      expect(datos.publicadaHace(DateTime(2026, 10, 20, 8)), 'Publicada hoy');
    });
  });

  group('puedeConfirmarEliminacion', () {
    test('sin postulaciones no exige la casilla', () {
      expect(
        puedeConfirmarEliminacion(postulacionesActivas: 0, casillaMarcada: false, enviando: false),
        isTrue,
      );
    });

    test('con postulaciones exige la casilla marcada', () {
      expect(
        puedeConfirmarEliminacion(postulacionesActivas: 3, casillaMarcada: false, enviando: false),
        isFalse,
      );
      expect(
        puedeConfirmarEliminacion(postulacionesActivas: 3, casillaMarcada: true, enviando: false),
        isTrue,
      );
    });

    test('mientras se envía queda deshabilitado', () {
      expect(
        puedeConfirmarEliminacion(postulacionesActivas: 0, casillaMarcada: true, enviando: true),
        isFalse,
      );
    });
  });
}
