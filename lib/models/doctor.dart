import 'package:flutter/material.dart';

/// CONTRATO: Doctor (PDF 1.1)
///   Requiere : id, nombre, especialidad, iniciales, rating, experiencia,
///              clinica, descripcion, color, horariosDisponibles
///   Garantiza: objeto Doctor valido con todos sus campos accesibles
///   Falla si : algun campo requerido es null -> error de compilacion
///              (se garantiza con parametros `required` + campos no-nullable)
///
/// Trazabilidad backend: models/mongo/Doctor.java
///   nombre+apellido -> nombre | especialidad -> especialidad
///   descripcion -> descripcion | imagenUrl -> (sustituido por iniciales + color)
@immutable
class Doctor {
  final String id;
  final String nombre;
  final String especialidad;
  final String iniciales;
  final double rating;
  final int experiencia;
  final String clinica;
  final String descripcion;
  final Color color;
  final List<String> horariosDisponibles;

  /// Semilla que determina los rasgos del avatar ilustrado (tono de piel,
  /// peinado, accesorios). Estable por doctor, así que su cara nunca cambia.
  final int avatarSemilla;

  /// URL de una foto real. Si existe, el avatar la muestra en lugar de la
  /// ilustración generada.
  final String? fotoUrl;

  /// Campos sueltos que solo envía la API de administración
  /// (`GET /api/admin/doctores`). La vista del paciente recibe únicamente
  /// [nombre] ya compuesto ("Dra. Laura Pérez"), así que aquí son nulos.
  /// El formulario de administración los necesita para poder editar cada
  /// parte por separado. Trazabilidad: `Doctor.java` (titulo, nombre,
  /// apellido, correo, telefono).
  final String? titulo;
  final String? nombrePila;
  final String? apellido;
  final String? correo;
  final String? telefono;

  const Doctor({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.iniciales,
    required this.rating,
    required this.experiencia,
    required this.clinica,
    required this.descripcion,
    required this.color,
    required this.horariosDisponibles,
    this.avatarSemilla = 0,
    this.fotoUrl,
    this.titulo,
    this.nombrePila,
    this.apellido,
    this.correo,
    this.telefono,
  });

  /// Construye un Doctor a partir del JSON que envía la API.
  factory Doctor.desdeJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    return Doctor(
      id: id,
      nombre: j['nombre'] as String? ?? 'Doctor',
      especialidad: j['especialidad'] as String? ?? 'General',
      iniciales: j['iniciales'] as String? ?? '?',
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      experiencia: (j['experiencia'] as num?)?.toInt() ?? 0,
      clinica: j['clinica'] as String? ?? '',
      descripcion: j['descripcion'] as String? ?? '',
      color: Color((j['color'] as num?)?.toInt() ?? 0xFF1A5FBF),
      horariosDisponibles:
          (j['horariosDisponibles'] as List?)?.cast<String>() ?? const [],
      avatarSemilla:
          (j['avatarSemilla'] as num?)?.toInt() ?? id.hashCode.abs(),
      fotoUrl: j['fotoUrl'] as String?,
      titulo: j['titulo'] as String?,
      nombrePila: j['nombrePila'] as String?,
      apellido: j['apellido'] as String?,
      correo: j['correo'] as String?,
      telefono: j['telefono'] as String?,
    );
  }

  /// Color de fondo del avatar (misma tonalidad, baja opacidad).
  Color get colorFondo => color.withValues(alpha: 0.14);

  /// "12 anos exp." tal como aparece en el mock de Penpot.
  String get experienciaTexto => '$experiencia años exp.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Doctor && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Doctor($id, $nombre, $especialidad)';
}
