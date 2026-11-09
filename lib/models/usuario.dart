/// Usuario autenticado en la sesion movil.
/// Trazabilidad backend: models/mysql/Usuario.java (username, email, nombre, roles)
class Usuario {
  final String nombre;
  final String email;
  final String iniciales;

  /// Semilla del avatar ilustrado del usuario.
  final int avatarSemilla;

  /// Roles concedidos por el backend (ROLE_USER, ROLE_ADMIN).
  final List<String> roles;

  const Usuario({
    required this.nombre,
    required this.email,
    required this.iniciales,
    this.avatarSemilla = 0,
    this.roles = const ['ROLE_USER'],
  });

  bool get esAdmin => roles.contains('ROLE_ADMIN');

  /// Construye un Usuario desde el JSON de la API.
  factory Usuario.desdeJson(Map<String, dynamic> j) {
    final nombre = j['nombre'] as String? ?? 'Usuario';
    return Usuario(
      nombre: nombre,
      email: j['email'] as String? ?? '',
      iniciales: j['iniciales'] as String? ?? _inicialesDe(nombre),
      avatarSemilla: (j['avatarSemilla'] as num?)?.toInt() ?? 0,
      roles: (j['roles'] as List?)?.cast<String>() ?? const ['ROLE_USER'],
    );
  }

  static String _inicialesDe(String nombreCompleto) {
    final partes = nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  /// Construye un usuario a partir del nombre completo, derivando iniciales.
  factory Usuario.desdeNombre(String nombreCompleto, String email) {
    final partes = nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final iniciales = partes.isEmpty
        ? '?'
        : partes.length == 1
            ? partes.first.substring(0, 1).toUpperCase()
            : (partes[0].substring(0, 1) + partes[1].substring(0, 1))
                .toUpperCase();
    return Usuario(
      nombre: nombreCompleto.trim().isEmpty ? 'Usuario' : nombreCompleto.trim(),
      email: email,
      iniciales: iniciales,
    );
  }
}
