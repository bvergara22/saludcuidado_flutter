import 'package:flutter/material.dart';

/// Servicio medico mostrado en el grid de HomeScreen.
/// Trazabilidad backend: models/mongo/Servicio.java
///   nombre | descripcion | duracionMinutos | icono (ri-*) -> IconData
@immutable
class Servicio {
  final String id;
  final String nombre;
  final String descripcion;
  final int duracionMinutos;
  final IconData icono;
  final Color color;

  /// Nombre del icono tal como lo envía el backend (`stethoscope`, `tooth`…).
  ///
  /// Se conserva porque [icono] no se puede volver a serializar: su
  /// `codePoint` depende de la fuente y el compilador de release poda los
  /// iconos que no se usan de forma literal. Guardando el nombre, el caché
  /// sin conexión vuelve a resolverlo con el mismo catálogo que la API.
  final String iconoNombre;

  const Servicio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.duracionMinutos,
    required this.icono,
    required this.color,
    this.iconoNombre = '',
  });

  String get duracionTexto => '$duracionMinutos min';

  /// Vuelca el servicio al mismo formato que envía la API.
  ///
  /// CONTRATO: `Repositorio.servicioDesdeJson(s.aJson())` devuelve un
  /// servicio equivalente a `s`, icono incluido.
  Map<String, dynamic> aJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'duracionMinutos': duracionMinutos,
        'icono': iconoNombre,
        'color': color.toARGB32(),
      };
}
