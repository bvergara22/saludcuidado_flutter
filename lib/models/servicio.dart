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

  const Servicio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.duracionMinutos,
    required this.icono,
    required this.color,
  });

  String get duracionTexto => '$duracionMinutos min';
}
