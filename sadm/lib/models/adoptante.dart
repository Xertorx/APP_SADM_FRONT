/// Data model for an "adoptante" (adopter) registration request.
///
/// The JSON keys match exactly what the SADM backend expects.
class Adoptante {
  const Adoptante({
    required this.nombre,
    required this.apellido,
    required this.identificacion,
    required this.fechaNacimiento,
    required this.correo,
    required this.contrasena,
    required this.telefono,
    required this.direccion,
    required this.tipoUsuario,
    required this.estado,
  });

  final String nombre;
  final String apellido;
  final int identificacion;
  final DateTime fechaNacimiento;
  final String correo;
  final String contrasena;
  final String telefono;
  final String direccion;
  final String tipoUsuario;
  final String estado;

  /// Converts this model into the exact JSON payload expected by
  /// `POST /SADM/adoptantes/crear`. No extra fields (like `id`) are sent.
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'apellido': apellido,
      'identificacion': identificacion,
      'fecha_nacimiento': fechaNacimiento.toIso8601String(),
      'correo': correo,
      'contraseña': contrasena,
      'telefono': telefono,
      'direccion': direccion,
      'tipo_usuario': tipoUsuario,
      'estado': estado,
    };
  }
}
