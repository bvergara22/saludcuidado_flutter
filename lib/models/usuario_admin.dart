import 'package:flutter/foundation.dart';

/// Usuario visto desde el panel de administración.
///
/// Es distinto de [Usuario]: aquí interesan el estado de la cuenta, los roles
/// y cuántas citas tiene, cosas que la app del paciente nunca necesita.
///
/// TRAZABILIDAD: `Usuario.java` (username, email, nombre, roles, activo)
/// más el conteo de citas que `AdminController.getUsuarios()` calculaba.
@immutable
class UsuarioAdmin {
  final int id;
  final String nombre;
  final String email;
  final String username;
  final String iniciales;
  final int avatarSemilla;
  final bool activo;
  final List<String> roles;
  final int citas;
  final String creadoEn;

  const UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.email,
    required this.username,
    required this.iniciales,
    required this.avatarSemilla,
    required this.activo,
    required this.roles,
    required this.citas,
    required this.creadoEn,
  });

  bool get esAdmin => roles.contains('ROLE_ADMIN');

  factory UsuarioAdmin.desdeJson(Map<String, dynamic> j) => UsuarioAdmin(
        id: (j['id'] as num).toInt(),
        nombre: j['nombre'] as String? ?? 'Usuario',
        email: j['email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        iniciales: j['iniciales'] as String? ?? '?',
        avatarSemilla: (j['avatarSemilla'] as num?)?.toInt() ?? 0,
        activo: j['activo'] == true,
        roles: (j['roles'] as List?)?.cast<String>() ?? const ['ROLE_USER'],
        citas: (j['citas'] as num?)?.toInt() ?? 0,
        creadoEn: j['creadoEn'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UsuarioAdmin && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
