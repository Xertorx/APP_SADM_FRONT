import 'package:intl/intl.dart';

/// Cuenta de usuario tal como la ve el administrador (HU27 + HU28).
/// Nunca contiene contraseña ni identificación: el backend no las envía.

const estadoActivo = 'ACTIVO';
const estadoInhabilitado = 'INHABILITADO';
const rolAdministrador = 'ADMINISTRADOR';

/// Texto en pantalla de un estado del backend: "Activo" / "Inhabilitado".
String estadoTexto(String estado) => switch (estado.toUpperCase()) {
      estadoActivo => 'Activo',
      estadoInhabilitado => 'Inhabilitado',
      _ => estado,
    };

/// Texto en pantalla de un rol del backend.
String rolTexto(String rol) => switch (rol.toUpperCase()) {
      'USUARIO' => 'Usuario',
      'FUNDACION' => 'Fundación',
      rolAdministrador => 'Administrador',
      _ => rol,
    };

/// El backend manda `Date` (ISO o milisegundos) e `Instant` (ISO): se aceptan ambos.
DateTime? _fecha(Object? valor) {
  if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
  if (valor is num) return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

String _texto(Object? valor) => valor is String ? valor : '';

/// dd/MM/yyyy en hora local, o cadena vacía si no hay fecha.
String formatearFechaCorta(DateTime? fecha) =>
    fecha == null ? '' : DateFormat('dd/MM/yyyy').format(fecha.toLocal());

/// dd/MM/yyyy HH:mm en hora local, o cadena vacía si no hay fecha.
String formatearFechaHoraCorta(DateTime? fecha) =>
    fecha == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());

/// Una fila de `GET /api/admin/usuarios`.
class UsuarioAdmin {
  const UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.rol,
    required this.estado,
    this.fechaRegistro,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final String rol;
  final String estado;
  final DateTime? fechaRegistro;

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) => UsuarioAdmin(
        id: (json['id'] as num).toInt(),
        nombre: _texto(json['nombre']),
        apellido: _texto(json['apellido']),
        correo: _texto(json['correo']),
        rol: _texto(json['rol']),
        estado: _texto(json['estado']),
        fechaRegistro: _fecha(json['fechaRegistro']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
        'rol': rol,
        'estado': estado,
        'fechaRegistro': fechaRegistro?.toIso8601String(),
      };

  String get nombreCompleto => '$nombre $apellido'.trim();
  bool get inhabilitado => estado.toUpperCase() == estadoInhabilitado;
}

/// Filtros del lado del cliente (HU27): `null` = "Todos".
List<UsuarioAdmin> filtrarUsuarios(
  List<UsuarioAdmin> usuarios, {
  String? rol,
  String? estado,
}) {
  return usuarios
      .where((u) => rol == null || u.rol.toUpperCase() == rol.toUpperCase())
      .where((u) => estado == null || u.estado.toUpperCase() == estado.toUpperCase())
      .toList(growable: false);
}

/// Una fila del historial de inhabilitaciones/reactivaciones.
class ModeracionHistorial {
  const ModeracionHistorial({
    required this.accion,
    required this.adminNombre,
    this.fecha,
    this.motivo,
  });

  final DateTime? fecha;
  final String accion;
  final String? motivo;
  final String adminNombre;

  factory ModeracionHistorial.fromJson(Map<String, dynamic> json) => ModeracionHistorial(
        fecha: _fecha(json['fecha']),
        accion: _texto(json['accion']),
        motivo: json['motivo'] is String ? json['motivo'] as String : null,
        adminNombre: _texto(json['adminNombre']),
      );

  Map<String, dynamic> toJson() => {
        'fecha': fecha?.toIso8601String(),
        'accion': accion,
        'motivo': motivo,
        'adminNombre': adminNombre,
      };

  bool get esInhabilitacion => accion.toUpperCase() == 'INHABILITAR';
  String get accionTexto => esInhabilitacion ? 'Inhabilitada' : 'Reactivada';
}

/// Botón que corresponde mostrar en el detalle según el estado de la cuenta.
enum AccionCuenta { inhabilitar, reactivar }

/// `GET /api/admin/usuarios/{id}`.
class UsuarioAdminDetalle {
  const UsuarioAdminDetalle({
    required this.usuario,
    required this.telefono,
    required this.direccion,
    required this.tieneFoto,
    required this.mascotasPublicadas,
    required this.postulaciones,
    required this.historial,
  });

  final UsuarioAdmin usuario;
  final String telefono;
  final String direccion;
  final bool tieneFoto;
  final int mascotasPublicadas;
  final int postulaciones;
  final List<ModeracionHistorial> historial;

  factory UsuarioAdminDetalle.fromJson(Map<String, dynamic> json) {
    final actividad = json['actividad'];
    final act = actividad is Map<String, dynamic> ? actividad : const <String, dynamic>{};
    final historial = json['historial'];
    return UsuarioAdminDetalle(
      usuario: UsuarioAdmin.fromJson(json),
      telefono: _texto(json['telefono']),
      direccion: _texto(json['direccion']),
      tieneFoto: json['tieneFoto'] == true,
      mascotasPublicadas: (act['mascotasPublicadas'] as num?)?.toInt() ?? 0,
      postulaciones: (act['postulaciones'] as num?)?.toInt() ?? 0,
      historial: historial is List
          ? historial
              .whereType<Map<String, dynamic>>()
              .map(ModeracionHistorial.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        ...usuario.toJson(),
        'telefono': telefono,
        'direccion': direccion,
        'tieneFoto': tieneFoto,
        'actividad': {
          'mascotasPublicadas': mascotasPublicadas,
          'postulaciones': postulaciones,
        },
        'historial': historial.map((h) => h.toJson()).toList(),
      };

  /// "Inhabilitar cuenta" si está activa, "Reactivar cuenta" si está inhabilitada.
  /// A un administrador no se le ofrece inhabilitar (el backend también lo rechaza).
  AccionCuenta? get accionDisponible {
    if (usuario.inhabilitado) return AccionCuenta.reactivar;
    if (usuario.estado.toUpperCase() == estadoActivo &&
        usuario.rol.toUpperCase() != rolAdministrador) {
      return AccionCuenta.inhabilitar;
    }
    return null;
  }
}
