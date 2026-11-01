import 'package:flutter_test/flutter_test.dart';
import 'package:sadm/models/mascota_edicion.dart';

void main() {
  test('interpreta la respuesta de edición aunque falten id y estado', () {
    final edicion = MascotaEdicion.fromJson({
      'nombre': 'Luna',
      'estado': null,
      'edad': '3',
      'tienePostulacionesActivas': true,
    }, id: 7);

    expect(edicion.mascota.id, 7);
    expect(edicion.mascota.nombre, 'Luna');
    expect(edicion.mascota.edad, 3);
    expect(edicion.tienePostulacionesActivas, isTrue);
  });

  test('interpreta los datos anidados bajo "mascota"', () {
    final edicion = MascotaEdicion.fromJson({
      'mascota': {'id': 7, 'nombre': 'Luna', 'estado': 'DISPONIBLE'},
      'tienePostulacionesActivas': false,
    }, id: 7);

    expect(edicion.mascota.nombre, 'Luna');
    expect(edicion.tienePostulacionesActivas, isFalse);
  });
}
