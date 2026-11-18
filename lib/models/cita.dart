import '../core/fechas.dart';
import 'doctor.dart';
import 'estado_cita.dart';

/// CONTRATO: Cita (PDF 1.1)
///   Requiere : id, doctor (Doctor existente), fecha, hora, estado (EstadoCita)
///   Garantiza: objeto Cita valido enlazado a un doctor
///   Falla si : doctor es null o estado no es un valor de EstadoCita
///              -> error de compilacion (tipos no-nullable)
///
/// Trazabilidad backend: models/mongo/Cita.java
///   fecha (LocalDate) -> DateTime | hora (LocalTime) -> String "HH:mm"
///   doctorId/doctorNombre -> doctor (objeto embebido)
///   estado (String) -> EstadoCita
class Cita {
  final String id;
  final Doctor doctor;
  final DateTime fecha;
  final String hora;
  final EstadoCita estado;

  /// Campo auxiliar trazado desde el backend (Cita.servicioNombre).
  final String servicio;

  /// Paciente dueño de la cita.
  ///
  /// Solo llega en la API de administración (`GET /api/admin/citas`), que es
  /// la única que ve citas de otras personas. En la vista del paciente es
  /// null, porque la cita ya es suya: trazabilidad de `Cita.usuarioId` /
  /// `Cita.usuarioUsername` del backend Java.
  final String? pacienteNombre;
  final String? pacienteEmail;
  final int pacienteSemilla;

  /// Construye una Cita a partir del JSON de la API.
  /// Lanza [FormatException] si falta el doctor, porque el contrato exige
  /// que toda cita esté enlazada a uno.
  factory Cita.desdeJson(Map<String, dynamic> j) {
    final doctorJson = j['doctor'];
    if (doctorJson is! Map<String, dynamic>) {
      throw const FormatException('La cita llegó sin doctor asociado.');
    }
    final fecha = DateTime.tryParse(j['fecha'] as String? ?? '');
    if (fecha == null) {
      throw FormatException('Fecha inválida en la cita: ${j['fecha']}');
    }
    final paciente = j['paciente'];
    return Cita(
      id: j['id'] as String,
      doctor: Doctor.desdeJson(doctorJson),
      fecha: fecha,
      hora: j['hora'] as String? ?? '00:00',
      estado: EstadoCita.desdeBackend(j['estado'] as String? ?? 'PROGRAMADA'),
      servicio: j['servicio'] as String? ?? 'Medicina General',
      pacienteNombre:
          paciente is Map ? paciente['nombre'] as String? : null,
      pacienteEmail: paciente is Map ? paciente['email'] as String? : null,
      pacienteSemilla: paciente is Map
          ? ((paciente['avatarSemilla'] as num?)?.toInt() ?? 0)
          : 0,
    );
  }

  const Cita({
    required this.id,
    required this.doctor,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.servicio = 'Medicina General',
    this.pacienteNombre,
    this.pacienteEmail,
    this.pacienteSemilla = 0,
  });

  Cita copyWith({EstadoCita? estado}) => Cita(
        id: id,
        doctor: doctor,
        fecha: fecha,
        hora: hora,
        estado: estado ?? this.estado,
        servicio: servicio,
        pacienteNombre: pacienteNombre,
        pacienteEmail: pacienteEmail,
        pacienteSemilla: pacienteSemilla,
      );

  /// Vuelca la cita al mismo formato que envía la API, para el caché
  /// sin conexión. `Cita.desdeJson(c.aJson())` devuelve una cita igual.
  Map<String, dynamic> aJson() => {
        'id': id,
        'doctor': doctor.aJson(),
        'fecha': Fechas.iso(fecha),
        'hora': hora,
        'estado': estado.estadoBackend,
        'servicio': servicio,
        if (pacienteNombre != null)
          'paciente': {
            'nombre': pacienteNombre,
            'email': pacienteEmail,
            'avatarSemilla': pacienteSemilla,
          },
      };

  /// Instante exacto de la cita, combinando fecha y hora "HH:mm".
  DateTime get momento {
    final partes = hora.split(':');
    final h = int.tryParse(partes.first) ?? 0;
    final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  /// CONTRATO: una cita está vencida cuando sigue PROGRAMADA y su hora
  /// ya pasó. Ni se completó ni se canceló: simplemente no se asistió.
  ///
  /// El backend guarda tres estados (PROGRAMADA, COMPLETADA, CANCELADA) y
  /// ninguno significa "se le pasó la hora". En vez de reescribir el estado
  /// en la base de datos —que sería afirmar algo que nadie comprobó— la app
  /// lo deduce de la fecha. Así una cita del martes pasado deja de
  /// anunciarse como «Próxima» sin inventar que se atendió.
  bool vencidaA(DateTime ahora) =>
      estado == EstadoCita.proxima && momento.isBefore(ahora);

  bool get vencida => vencidaA(DateTime.now());

  /// Clave de ocupacion usada por HorariosService (fecha + hora).
  String get claveSlot =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')} $hora';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Cita && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Cita($id, ${doctor.nombre}, $claveSlot, ${estado.name})';
}
