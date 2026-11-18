import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/preferencias.dart';
import '../models/cita.dart';
import '../models/estado_cita.dart';

/// Recordatorios de cita en el propio teléfono.
///
/// CONTRATO: Notificaciones
///   Requiere : [iniciar] llamado una vez al arrancar la app
///   Garantiza: cada cita próxima tiene programados hasta dos avisos, uno
///              24 h antes y otro 1 h antes, que el sistema operativo
///              dispara aunque la app esté cerrada
///   Falla si : la plataforma no las soporta (web) o la persona no da
///              permiso -> [soportadas] / [permitidas] son false y todos
///              los métodos no hacen nada, sin lanzar excepciones
///
/// Es una notificación **local**, no push: no hace falta servidor de envío
/// ni Firebase. El teléfono guarda la alarma y la dispara solo. Para avisos
/// que nacen en el servidor (el médico cancela, por ejemplo) haría falta
/// FCM, que es el paso siguiente natural.
class Notificaciones {
  Notificaciones._();

  static final Notificaciones yo = Notificaciones._();

  static const String _origen = 'Notificaciones';

  /// Canal de Android. Importancia alta para que aparezca como aviso
  /// emergente: un recordatorio médico que solo va a la bandeja no sirve.
  static const AndroidNotificationDetails _canalAndroid =
      AndroidNotificationDetails(
    'citas_recordatorios',
    'Recordatorios de cita',
    channelDescription: 'Avisos antes de cada cita médica agendada',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _detalles = NotificationDetails(
    android: _canalAndroid,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _iniciado = false;
  bool _permitidas = false;

  /// La web no tiene programación local de notificaciones: el estándar
  /// exige un service worker y un servidor de push, así que allí la
  /// funcionalidad se apaga entera en vez de fingir que funciona.
  bool get soportadas =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get permitidas => _permitidas;

  /// true cuando además la persona las tiene encendidas en Ajustes.
  bool get activas =>
      soportadas && _permitidas && Preferencias.yo.notificacionesActivas;

  /// CONTRATO: iniciar
  ///   Garantiza: el plugin y la base de zonas horarias quedan listos
  ///   Falla si : la plataforma lo rechaza -> queda [soportadas] en false
  Future<void> iniciar() async {
    if (_iniciado || !soportadas) return;
    _iniciado = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_zonaDelDispositivo());

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      traza.datos(_origen, 'Servicio de recordatorios listo (${tz.local.name})');
    } catch (e) {
      _iniciado = false;
      traza.error(_origen, 'No se pudo iniciar el servicio: $e');
    }
  }

  /// Zona horaria del dispositivo, deducida de su desfase actual respecto
  /// a UTC.
  ///
  /// El paquete `timezone` no sabe en qué zona está el teléfono; solo
  /// conoce la base de datos IANA. Se busca la primera zona cuyo desfase
  /// coincide ahora mismo con el del sistema (en Colombia, UTC-5). Es
  /// suficiente para recordatorios al cuarto de hora, aunque no distingue
  /// entre dos zonas con el mismo desfase y distinto horario de verano.
  /// La solución exacta es el plugin `flutter_timezone`.
  tz.Location _zonaDelDispositivo() {
    final desfase = DateTime.now().timeZoneOffset;
    for (final nombre in tz.timeZoneDatabase.locations.keys) {
      final lugar = tz.timeZoneDatabase.locations[nombre]!;
      if (tz.TZDateTime.now(lugar).timeZoneOffset == desfase) return lugar;
    }
    return tz.UTC;
  }

  /// CONTRATO: pedirPermiso
  ///   Garantiza: devuelve true solo si el sistema concedió el permiso
  ///   Falla si : la persona lo deniega -> false, y la app lo dice en
  ///              Ajustes en lugar de callarse
  ///
  /// En Android 13+ (API 33) `POST_NOTIFICATIONS` es un permiso en tiempo
  /// de ejecución, igual que la cámara.
  Future<bool> pedirPermiso() async {
    if (!soportadas) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        _permitidas = await android?.requestNotificationsPermission() ?? false;
      } else {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        _permitidas = await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      traza.accion(_origen,
          'Permiso de notificaciones ${_permitidas ? "concedido" : "denegado"}');
    } catch (e) {
      _permitidas = false;
      traza.error(_origen, 'Permiso no resuelto: $e');
    }
    return _permitidas;
  }

  // ---------------------------------------------------------- programación

  /// Identificador estable y no negativo para cada aviso de cada cita.
  ///
  /// El sistema identifica las alarmas por un entero, así que hay que
  /// derivarlo del id de la cita de forma determinista: el mismo id debe
  /// dar siempre el mismo número para poder cancelarlo después.
  static int idAviso(String citaId, int aviso) =>
      (citaId.hashCode & 0x7FFFFFF) * 4 + aviso;

  /// CONTRATO: programar
  ///   Requiere : una cita PROGRAMADA
  ///   Garantiza: quedan agendados los avisos que todavía caen en el
  ///              futuro (24 h antes y 1 h antes)
  ///   Falla si : la cita ya pasó o está cancelada -> no programa nada
  ///
  /// Devuelve cuántos avisos quedaron agendados.
  Future<int> programar(Cita cita) async {
    if (!activas) return 0;
    if (cita.estado != EstadoCita.proxima) return 0;

    final momento = cita.momento;
    final ahora = DateTime.now();
    var puestos = 0;

    final avisos = <int, (DateTime, String)>{
      0: (
        momento.subtract(const Duration(hours: 24)),
        'Mañana tienes cita con ${cita.doctor.nombre}',
      ),
      1: (
        momento.subtract(const Duration(hours: 1)),
        'En una hora: ${cita.doctor.nombre}',
      ),
    };

    for (final entrada in avisos.entries) {
      final (cuando, titulo) = entrada.value;
      // Un aviso cuyo momento ya pasó no se programa: el sistema lo
      // dispararía al instante y sería ruido, no un recordatorio.
      if (!cuando.isAfter(ahora)) continue;
      try {
        await _plugin.zonedSchedule(
          id: idAviso(cita.id, entrada.key),
          title: titulo,
          body: '${cita.doctor.especialidad} · ${Fechas.conDia(cita.fecha)} '
              'a las ${Fechas.hora12(cita.hora)} · ${cita.doctor.clinica}',
          scheduledDate: tz.TZDateTime.from(cuando, tz.local),
          notificationDetails: _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: cita.id,
        );
        puestos++;
      } catch (e) {
        traza.error(_origen, 'Aviso no programado para ${cita.id}: $e');
      }
    }

    if (puestos > 0) {
      traza.accion(
        _origen,
        '$puestos recordatorio(s) programados para la cita ${cita.id}',
        contrato: 'Notificaciones.Garantiza',
      );
    }
    return puestos;
  }

  /// Quita los avisos de una cita (al cancelarla o reprogramarla).
  Future<void> cancelar(String citaId) async {
    if (!soportadas) return;
    for (var i = 0; i < 2; i++) {
      try {
        await _plugin.cancel(id: idAviso(citaId, i));
      } catch (_) {
        // Cancelar un aviso que no existe no es un error.
      }
    }
    traza.datos(_origen, 'Recordatorios retirados de la cita $citaId');
  }

  /// CONTRATO: sincronizar
  ///   Garantiza: los avisos del teléfono reflejan exactamente las citas
  ///              próximas que se le pasan, ni más ni menos
  ///
  /// Se llama después de cada carga de citas. Borra todo y reprograma, que
  /// es más simple y más seguro que intentar un diferencial: así una cita
  /// cancelada desde el panel de administración deja de avisar aquí.
  Future<int> sincronizar(List<Cita> citas) async {
    if (!activas) return 0;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    var total = 0;
    for (final c in citas) {
      if (c.vencida) continue;
      total += await programar(c);
    }
    traza.datos(_origen, 'Recordatorios sincronizados: $total programados');
    return total;
  }

  /// Avisos que el sistema tiene pendientes. Lo usa la pantalla de Ajustes
  /// para poder enseñar que esto no es decorativo.
  Future<List<PendingNotificationRequest>> pendientes() async {
    if (!soportadas) return const [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  /// Aviso inmediato, para que en Ajustes se pueda comprobar que llegan.
  Future<bool> probar() async {
    if (!soportadas || !_permitidas) return false;
    try {
      await _plugin.show(
        id: 999999,
        title: 'Los recordatorios funcionan',
        body: 'Así se verá el aviso antes de cada cita.',
        notificationDetails: _detalles,
      );
      traza.accion(_origen, 'Notificación de prueba enviada');
      return true;
    } catch (e) {
      traza.error(_origen, 'Prueba fallida: $e');
      return false;
    }
  }

  Future<void> cancelarTodo() async {
    if (!soportadas) return;
    try {
      await _plugin.cancelAll();
      traza.accion(_origen, 'Todos los recordatorios retirados');
    } catch (_) {}
  }
}
