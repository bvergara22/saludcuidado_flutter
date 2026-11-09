import 'package:flutter/material.dart';

/// Un mes de la gráfica de barras.
@immutable
class MesCitas {
  /// Clave "YYYY-MM" que devuelve el backend.
  final String clave;
  final int total;

  const MesCitas({required this.clave, required this.total});

  factory MesCitas.desdeJson(Map<String, dynamic> j) => MesCitas(
        clave: j['mes'] as String? ?? '',
        total: (j['total'] as num?)?.toInt() ?? 0,
      );

  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// "nov" para mostrar debajo de la barra.
  String get etiqueta {
    final partes = clave.split('-');
    if (partes.length != 2) return clave;
    final m = int.tryParse(partes[1]);
    if (m == null || m < 1 || m > 12) return clave;
    return _meses[m - 1];
  }
}

/// Un doctor en la gráfica de dona (citas atendidas).
@immutable
class DoctorPopular {
  final String id;
  final String nombre;
  final String especialidad;
  final Color color;
  final int total;

  const DoctorPopular({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.color,
    required this.total,
  });

  factory DoctorPopular.desdeJson(Map<String, dynamic> j) => DoctorPopular(
        id: j['id'] as String? ?? '',
        nombre: j['nombre'] as String? ?? 'Doctor',
        especialidad: j['especialidad'] as String? ?? '',
        color: Color((j['color'] as num?)?.toInt() ?? 0xFF1A5FBF),
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// Datos del tablero de administración.
///
/// TRAZABILIDAD: `AdminController.getDatosDashboard()` del proyecto web
/// (estadísticas generales + doctores populares + estadísticas mensuales).
@immutable
class ResumenAdmin {
  final int total;
  final int programadas;
  final int completadas;
  final int canceladas;

  final int usuarios;
  final int usuariosActivos;
  final int doctores;
  final int servicios;

  final List<MesCitas> porMes;
  final List<DoctorPopular> populares;

  const ResumenAdmin({
    required this.total,
    required this.programadas,
    required this.completadas,
    required this.canceladas,
    required this.usuarios,
    required this.usuariosActivos,
    required this.doctores,
    required this.servicios,
    required this.porMes,
    required this.populares,
  });

  factory ResumenAdmin.desdeJson(Map<String, dynamic> j) {
    final citas = (j['citas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totales = (j['totales'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;

    return ResumenAdmin(
      total: n(citas, 'total'),
      programadas: n(citas, 'programadas'),
      completadas: n(citas, 'completadas'),
      canceladas: n(citas, 'canceladas'),
      usuarios: n(totales, 'usuarios'),
      usuariosActivos: n(totales, 'usuariosActivos'),
      doctores: n(totales, 'doctores'),
      servicios: n(totales, 'servicios'),
      porMes: ((j['citasPorMes'] as List?) ?? const [])
          .map((e) => MesCitas.desdeJson(e as Map<String, dynamic>))
          .toList(),
      populares: ((j['doctoresPopulares'] as List?) ?? const [])
          .map((e) => DoctorPopular.desdeJson(e as Map<String, dynamic>))
          .where((d) => d.total > 0)
          .toList(),
    );
  }

  /// Porcentaje de citas completadas sobre el total (0 si no hay citas).
  double get tasaCumplimiento => total == 0 ? 0 : completadas / total;
}
