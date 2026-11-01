/// Perfil del usuario autenticado (`GET /api/perfil`). El correo es de solo lectura.
class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.ubicacion,
    required this.tieneFoto,
    this.fotoActualizadaEn,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final String ubicacion;
  final bool tieneFoto;
  final String? fotoActualizadaEn;

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: (json['id'] as num?)?.toInt() ?? -1,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      ubicacion: json['ubicacion'] as String? ?? '',
      tieneFoto: json['tieneFoto'] == true,
      fotoActualizadaEn: json['fotoActualizadaEn'] as String?,
    );
  }
}

/// Datos que se envían en la parte `datos` del `PUT /api/perfil`.
/// El correo no viaja; los tres campos de contraseña son opcionales en bloque.
class PerfilActualizacion {
  const PerfilActualizacion({
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.ubicacion,
    this.contrasenaActual = '',
    this.contrasenaNueva = '',
    this.confirmarContrasena = '',
    this.quitarFoto = false,
  });

  final String nombre;
  final String apellido;
  final String telefono;
  final String ubicacion;
  final String contrasenaActual;
  final String contrasenaNueva;
  final String confirmarContrasena;
  final bool quitarFoto;

  Map<String, dynamic> toJson() => {
        'nombre': nombre.trim(),
        'apellido': apellido.trim(),
        'telefono': telefono.trim(),
        'ubicacion': ubicacion.trim(),
        'contrasenaActual': contrasenaActual,
        'contrasenaNueva': contrasenaNueva,
        'confirmarContrasena': confirmarContrasena,
        'quitarFoto': quitarFoto,
      };
}
