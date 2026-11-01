import 'package:flutter_test/flutter_test.dart';
import 'package:sadm/models/perfil.dart';
import 'package:sadm/utils/perfil_validators.dart';

void main() {
  group('bloque de contraseña opcional', () {
    test('con los tres vacíos no exige nada', () {
      expect(PerfilValidators.contrasenaActual('', '', ''), isNull);
      expect(PerfilValidators.contrasenaNueva('', '', ''), isNull);
      expect(PerfilValidators.confirmar('', '', ''), isNull);
    });

    test('si se llena cualquiera, la actual es obligatoria', () {
      const msg = 'Debes ingresar tu contraseña actual para cambiar la contraseña';
      expect(PerfilValidators.contrasenaActual('', 'Nueva1234', ''), msg);
      expect(PerfilValidators.contrasenaActual('', '', 'x'), msg);
      expect(PerfilValidators.contrasenaActual('Vieja123', '', ''), isNull);
    });

    test('si solo se llena la actual, la nueva pasa a ser obligatoria', () {
      expect(
        PerfilValidators.contrasenaNueva('Vieja123', '', ''),
        'La nueva contraseña debe tener entre 8 y 72 caracteres, una mayúscula y un número',
      );
    });
  });

  group('nueva contraseña', () {
    const formato =
        'La nueva contraseña debe tener entre 8 y 72 caracteres, una mayúscula y un número';

    test('rechaza corta, sin mayúscula, sin número o muy larga', () {
      expect(PerfilValidators.contrasenaNueva('Vieja123', 'Ab1', 'Ab1'), formato);
      expect(PerfilValidators.contrasenaNueva('Vieja123', 'nueva1234', 'nueva1234'), formato);
      expect(PerfilValidators.contrasenaNueva('Vieja123', 'NuevaClave', 'NuevaClave'), formato);
      final larga = 'A1${'a' * 71}';
      expect(PerfilValidators.contrasenaNueva('Vieja123', larga, larga), formato);
    });

    test('acepta una válida', () {
      expect(PerfilValidators.contrasenaNueva('Vieja123', 'Nueva1234', 'Nueva1234'), isNull);
    });

    test('debe ser diferente a la actual', () {
      expect(
        PerfilValidators.contrasenaNueva('Vieja123', 'Vieja123', 'Vieja123'),
        'La nueva contraseña debe ser diferente a la actual',
      );
    });
  });

  group('confirmación', () {
    test('debe coincidir con la nueva', () {
      expect(
        PerfilValidators.confirmar('Vieja123', 'Nueva1234', 'Otra12345'),
        'Las contraseñas no coinciden',
      );
      expect(PerfilValidators.confirmar('Vieja123', 'Nueva1234', ''), 'Las contraseñas no coinciden');
      expect(PerfilValidators.confirmar('Vieja123', 'Nueva1234', 'Nueva1234'), isNull);
    });
  });

  group('datos de contacto', () {
    test('nombre y apellido: 3–50 y solo letras', () {
      expect(PerfilValidators.nombre(''), 'El nombre es obligatorio');
      expect(PerfilValidators.nombre('Di'), 'El nombre debe tener entre 3 y 50 caracteres');
      expect(PerfilValidators.nombre('Diego1'), 'El nombre solo puede contener letras');
      expect(PerfilValidators.apellido('García'), isNull);
      expect(PerfilValidators.apellido('Gar#'), 'El apellido solo puede contener letras');
    });

    test('teléfono y ubicación', () {
      expect(PerfilValidators.telefono('123'), 'El teléfono debe contener entre 7 y 15 dígitos');
      expect(PerfilValidators.telefono('+573001112222'), isNull);
      expect(PerfilValidators.ubicacion('abc'), 'La ubicación debe tener entre 5 y 150 caracteres');
      expect(PerfilValidators.ubicacion('Bogotá, Colombia'), isNull);
    });
  });

  group('foto', () {
    test('solo JPG o PNG', () {
      expect(
        PerfilValidators.foto(nombreArchivo: 'a.gif', tipo: 'image/gif', bytes: 10),
        'La foto debe ser JPG o PNG',
      );
      expect(PerfilValidators.foto(nombreArchivo: 'a.png', tipo: 'image/png', bytes: 10), isNull);
      expect(PerfilValidators.foto(nombreArchivo: 'a.JPG', tipo: null, bytes: 10), isNull);
    });

    test('máximo 5 MB', () {
      expect(
        PerfilValidators.foto(
          nombreArchivo: 'a.png',
          tipo: 'image/png',
          bytes: PerfilValidators.maxBytesFoto + 1,
        ),
        'La foto no puede superar 5 MB',
      );
    });
  });

  test('PerfilActualizacion no envía el correo y serializa el bloque', () {
    final json = const PerfilActualizacion(
      nombre: ' Diego ',
      apellido: 'García',
      telefono: '3001112222',
      ubicacion: 'Bogotá',
    ).toJson();
    expect(json.containsKey('correo'), isFalse);
    expect(json['nombre'], 'Diego');
    expect(json['quitarFoto'], false);
  });
}
