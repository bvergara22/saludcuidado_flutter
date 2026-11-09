/// Utilidades de fecha en espanol, sin dependencias externas.
/// (Se evita `intl` para que el proyecto compile con solo el SDK de Flutter.)
class Fechas {
  Fechas._();

  static const List<String> meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static const List<String> mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// DateTime.weekday: 1 = lunes ... 7 = domingo.
  static const List<String> dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  static const List<String> diasCortos = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
  ];

  static String mes(DateTime f) => meses[f.month - 1];

  static String mesCorto(DateTime f) => mesesCortos[f.month - 1];

  static String dia(DateTime f) => dias[f.weekday - 1];

  static String diaCorto(DateTime f) => diasCortos[f.weekday - 1];

  /// "15 de Marzo de 2026"
  static String largo(DateTime f) => '${f.day} de ${mes(f)} de ${f.year}';

  /// "Lunes, 15 de Marzo"
  static String conDia(DateTime f) => '${dia(f)}, ${f.day} de ${mes(f)}';

  /// "15 Mar 2026"
  static String corto(DateTime f) => '${f.day} ${mesCorto(f)} ${f.year}';

  /// "2026-03-15" (clave estable, igual que LocalDate.toString() en el backend).
  static String iso(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  static bool mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool esHoy(DateTime f) => mismoDia(f, DateTime.now());

  /// Texto relativo usado en la tarjeta "Proxima cita" del Home.
  static String relativo(DateTime f) {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    final objetivo = DateTime(f.year, f.month, f.day);
    final dias = objetivo.difference(base).inDays;

    if (dias == 0) return 'Hoy';
    if (dias == 1) return 'Mañana';
    if (dias == -1) return 'Ayer';
    if (dias > 1 && dias < 7) return 'En $dias días';
    if (dias < -1 && dias > -7) return 'Hace ${-dias} días';
    return corto(f);
  }

  /// Convierte "HH:mm" a minutos desde medianoche. -1 si el formato es invalido.
  static int horaAMinutos(String hora) {
    final partes = hora.split(':');
    if (partes.length != 2) return -1;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return -1;
    return h * 60 + m;
  }

  /// "14:30" -> "2:30 PM"
  static String hora12(String hora) {
    final minutos = horaAMinutos(hora);
    if (minutos < 0) return hora;
    final h24 = minutos ~/ 60;
    final m = minutos % 60;
    final periodo = h24 < 12 ? 'AM' : 'PM';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $periodo';
  }
}
