import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../models/estado_cita.dart';
import 'sample_data.dart';

/// Reglas de disponibilidad de horarios.
///
/// TRAZABILIDAD BACKEND (ejemplo_99 / Spring Boot):
///   CitaService.obtenerHorariosDisponiblesString(LocalDate fecha):
///     1. Genera horarios de 07:00 a 19:00 cada 30 minutos.
///     2. Si la fecha es hoy, descarta los horarios ya pasados.
///     3. Descarta los horarios ya ocupados por citas existentes.
///   CitaService.crearCita(...): lanza error si la hora elegida no esta
///   dentro de los horarios disponibles.
///
/// Esta clase reimplementa esas tres reglas en el cliente movil.
class HorariosService {
  HorariosService._();

  static const String _origen = 'HorariosService';

  /// Regla 1 + 2 + 3 aplicadas en orden, acotadas ademas a la agenda
  /// propia del doctor (Doctor.horariosDisponibles del contrato movil).
  static List<String> disponibles({
    required Doctor doctor,
    required DateTime fecha,
    required List<Cita> citasExistentes,
  }) {
    // Regla 1: rejilla base 07:00-19:00 cada 30 min, acotada al doctor.
    var horarios = horariosBase
        .where((h) => doctor.horariosDisponibles.contains(h))
        .toList();

    // Regla 2: si la fecha es hoy, se descartan los horarios ya pasados.
    if (Fechas.esHoy(fecha)) {
      final ahora = DateTime.now();
      final minutosAhora = ahora.hour * 60 + ahora.minute;
      horarios = horarios
          .where((h) => Fechas.horaAMinutos(h) > minutosAhora)
          .toList();
    }

    // Regla 3: se descartan los horarios ocupados por citas no canceladas
    // del mismo doctor en esa fecha.
    final ocupados = citasExistentes
        .where((c) =>
            c.doctor.id == doctor.id &&
            c.estado != EstadoCita.cancelada &&
            Fechas.mismoDia(c.fecha, fecha))
        .map((c) => c.hora)
        .toSet();

    final resultado =
        horarios.where((h) => !ocupados.contains(h)).toList();

    traza.datos(
      _origen,
      'Horarios para ${doctor.nombre} el ${Fechas.iso(fecha)}: '
      '${resultado.length} disponibles, ${ocupados.length} ocupados',
      contrato: 'CitaService.obtenerHorariosDisponiblesString',
    );

    return resultado;
  }

  /// Equivalente a la verificacion previa de CitaService.crearCita().
  static bool estaDisponible({
    required Doctor doctor,
    required DateTime fecha,
    required String hora,
    required List<Cita> citasExistentes,
  }) {
    return disponibles(
      doctor: doctor,
      fecha: fecha,
      citasExistentes: citasExistentes,
    ).contains(hora);
  }

  /// Dias seleccionables en el paso 2 de ReservarScreen:
  /// desde hoy hasta 30 dias adelante, excluyendo domingos
  /// (la clinica no atiende ese dia).
  static List<DateTime> diasSeleccionables({int cantidad = 30}) {
    final hoy = DateTime.now();
    final dias = <DateTime>[];
    var offset = 0;
    while (dias.length < cantidad) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + offset);
      if (d.weekday != DateTime.sunday) {
        dias.add(d);
      }
      offset++;
    }
    return dias;
  }
}
