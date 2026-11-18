import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../data/preferencias.dart';
import '../servicios/biometria.dart';
import '../servicios/notificaciones.dart';

/// Ajustes del dispositivo.
///
/// CONTRATO: AjustesScreen
///   Requiere : AppStateScope en el árbol
///   Garantiza: cada interruptor refleja el estado real del sistema
///              operativo, no solo lo que la app querría
///   Falla si : la plataforma no soporta una función -> esa fila se
///              muestra apagada y explica por qué, en lugar de
///              desaparecer o mentir
///
/// Esta pantalla es la cara visible de `lib/servicios/`: aquí se ve si el
/// teléfono concedió el permiso de notificaciones, qué biometría tiene
/// registrada y cuántos recordatorios hay realmente en cola.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  static const String ruta = '/ajustes';

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  static const String _origen = 'AjustesScreen';

  bool _cargando = true;

  // Estado real del dispositivo, consultado al abrir.
  bool _biometriaDisponible = false;
  String _biometriaDescripcion = '';
  List<PendingNotificationRequest> _pendientes = const [];

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Ajustes abiertos', contrato: 'AjustesScreen');
    _consultarDispositivo();
  }

  /// Pregunta al sistema operativo en qué estado está cada cosa.
  Future<void> _consultarDispositivo() async {
    final disponible = await Biometria.yo.disponible;
    final descripcion = await Biometria.yo.descripcion;
    final pendientes = await Notificaciones.yo.pendientes();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      _biometriaDescripcion = descripcion;
      _pendientes = pendientes;
      _cargando = false;
    });
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ------------------------------------------------------ recordatorios

  Future<void> _cambiarNotificaciones(bool activar) async {
    if (!Notificaciones.yo.soportadas) {
      _avisar('Esta plataforma no programa recordatorios locales.');
      return;
    }
    if (activar) {
      final concedido = await Notificaciones.yo.pedirPermiso();
      if (!concedido) {
        _avisar('El sistema no concedió el permiso de notificaciones.');
        if (mounted) setState(() {});
        return;
      }
    }
    await Preferencias.yo.guardarNotificaciones(activar);
    if (!mounted) return;
    final estado = AppStateScope.leer(context);
    if (activar) {
      final n = await Notificaciones.yo.sincronizar(estado.citas);
      _avisar(n == 0
          ? 'Recordatorios activados. No hay citas futuras que avisar.'
          : 'Recordatorios activados: $n aviso(s) programado(s).');
    } else {
      await Notificaciones.yo.cancelarTodo();
      _avisar('Recordatorios desactivados.');
    }
    await _consultarDispositivo();
  }

  Future<void> _probarNotificacion() async {
    final ok = await Notificaciones.yo.probar();
    _avisar(ok
        ? 'Aviso enviado: míralo en la bandeja de notificaciones.'
        : 'No se pudo enviar. Revisa el permiso del sistema.');
  }

  // ----------------------------------------------------------- biometría

  Future<void> _cambiarBiometria(bool activar) async {
    final r = await Biometria.yo.cambiar(activar);
    if (!mounted) return;
    if (r != ResultadoBiometria.concedido) _avisar(r.mensaje);
    setState(() {});
  }

  // --------------------------------------------------------------- datos

  Future<void> _borrarCache() async {
    final confirmado = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Borrar datos guardados'),
            content: const Text(
              'Se borrarán las citas y el catálogo que este teléfono tiene '
              'guardados para funcionar sin conexión. Tu sesión no se cierra '
              'y nada se borra del servidor.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmado) return;
    await Preferencias.yo.guardarCache(
      citas: const [],
      doctores: const [],
      servicios: const [],
    );
    traza.accion(_origen, 'Caché del dispositivo borrado');
    _avisar('Datos sin conexión borrados.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);
    final prefs = Preferencias.yo;
    final notis = Notificaciones.yo;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                _Seccion(
                  titulo: 'Recordatorios de cita',
                  descripcion: notis.soportadas
                      ? 'Un aviso 24 horas antes y otro una hora antes. Los '
                          'programa el teléfono, así que llegan aunque la app '
                          'esté cerrada.'
                      : 'Esta plataforma no permite programar avisos locales. '
                          'En el teléfono (Android o iOS) sí funcionan.',
                  hijos: [
                    SwitchListTile(
                      value: prefs.notificacionesActivas && notis.soportadas,
                      onChanged: notis.soportadas
                          ? (v) => _cambiarNotificaciones(v)
                          : null,
                      title: const Text('Avisarme antes de cada cita'),
                      subtitle: Text(
                        !notis.soportadas
                            ? 'No disponible aquí'
                            : notis.permitidas
                                ? 'Permiso concedido por el sistema'
                                : 'El sistema aún no ha dado permiso',
                      ),
                    ),
                    if (notis.soportadas) ...[
                      _Dato(
                        icono: Icons.schedule_rounded,
                        etiqueta: 'Avisos en cola',
                        valor: '${_pendientes.length}',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: _probarNotificacion,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Enviar un aviso de prueba'),
                        ),
                      ),
                    ],
                  ],
                ),
                _Seccion(
                  titulo: 'Seguridad',
                  descripcion:
                      'La huella protege la sesión guardada en este teléfono. '
                      'No sustituye a tu contraseña: esa es la que te '
                      'identifica ante el servidor.',
                  hijos: [
                    SwitchListTile(
                      value: prefs.biometriaActiva && _biometriaDisponible,
                      onChanged: _biometriaDisponible
                          ? (v) => _cambiarBiometria(v)
                          : null,
                      title: const Text('Pedir huella al abrir'),
                      subtitle: Text(
                        _biometriaDisponible
                            ? 'Este dispositivo usa $_biometriaDescripcion'
                            : Biometria.yo.soportada
                                ? 'No hay huella ni rostro registrados en el '
                                    'teléfono'
                                : 'No disponible en esta plataforma',
                      ),
                    ),
                  ],
                ),
                _Seccion(
                  titulo: 'Datos sin conexión',
                  descripcion:
                      'La app guarda tus citas y el catálogo para poder '
                      'mostrarlos cuando no hay red.',
                  hijos: [
                    _Dato(
                      icono: Icons.save_outlined,
                      etiqueta: 'Última copia',
                      valor: estado.fechaCache == null
                          ? 'Todavía ninguna'
                          : '${Fechas.conDia(estado.fechaCache!)} a las '
                              '${_hhmm(estado.fechaCache!)}',
                    ),
                    _Dato(
                      icono: Icons.cloud_outlined,
                      etiqueta: 'Mostrando',
                      valor: estado.desdeCache
                          ? 'datos guardados en el teléfono'
                          : estado.enLinea
                              ? 'datos del servidor'
                              : 'datos de demostración',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: _borrarCache,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Borrar datos guardados'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _hhmm(DateTime f) =>
      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.descripcion,
    required this.hijos,
  });

  final String titulo;
  final String descripcion;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radio),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(children: hijos),
          ),
        ],
      ),
    );
  }
}

/// Fila de solo lectura: un hecho del dispositivo, no un ajuste.
class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppColors.textHint),
          const SizedBox(width: 10),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
