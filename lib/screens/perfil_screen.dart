import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../widgets/avatar_ilustrado.dart';

/// CONTRATO: PerfilScreen (PDF 1.2)
///   Requiere : sampleCitas: List<Cita> para calcular estadisticas
///   Garantiza: muestra avatar, nombre, email, estadisticas de citas y menu
///              de opciones. El boton cerrar sesion muestra dialogo de
///              confirmacion y navega a /login
///   Falla si : sin fallo; las estadisticas muestran 0 si no hay citas
class PerfilScreen extends StatelessWidget {
  final bool mostrarAtras;

  const PerfilScreen({super.key, this.mostrarAtras = false});

  static const String _origen = 'PerfilScreen';

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);
    final usuario = estado.usuarioActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: mostrarAtras,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // ------------------------------------------------ cabecera
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
            decoration: const BoxDecoration(
              gradient: AppColors.gradienteTarjeta,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6), width: 2),
                  ),
                  child: AvatarUsuario(
                    semilla: usuario.avatarSemilla == 0
                        ? usuario.email.hashCode.abs()
                        : usuario.avatarSemilla,
                    tamano: 82,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  usuario.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usuario.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 11),
                // Insignia de conexión: hace visible si los datos vienen de
                // la base de datos o del respaldo local.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estado.enLinea
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estado.enLinea
                            ? 'Conectado al servidor'
                            : 'Modo demostración',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --------------------------------------------- estadisticas
          // CONTRATO "Falla si": muestran 0 cuando no hay citas.
          Padding(
            padding: AppTheme.padPantalla,
            child: Row(
              children: [
                Expanded(
                  child: _Estadistica(
                    valor: estado.totalCitas,
                    etiqueta: 'Total',
                    icono: Icons.event_note_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Estadistica(
                    valor: estado.totalProximas,
                    etiqueta: 'Próximas',
                    icono: Icons.schedule_rounded,
                    color: AppColors.medicinaGeneral,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Estadistica(
                    valor: estado.totalCompletadas,
                    etiqueta: 'Completadas',
                    icono: Icons.check_circle_outline_rounded,
                    color: AppColors.exito,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Estadistica(
                    valor: estado.totalCanceladas,
                    etiqueta: 'Canceladas',
                    icono: Icons.cancel_outlined,
                    color: AppColors.peligro,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ------------------------------------------ menu de opciones
          const Padding(
            padding: AppTheme.padPantalla,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cuenta',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _grupoOpciones([
            _Opcion(
              icono: Icons.person_outline_rounded,
              titulo: 'Datos personales',
              onTap: () => _enDesarrollo(context, 'Datos personales'),
            ),
            _Opcion(
              icono: Icons.event_note_outlined,
              titulo: 'Historial de citas',
              onTap: () {
                traza.navegacion(_origen, 'Historial -> ${AppRoutes.misCitas}');
                Navigator.of(context).pushNamed(AppRoutes.misCitas);
              },
            ),
            _Opcion(
              icono: Icons.notifications_none_rounded,
              titulo: 'Notificaciones',
              onTap: () => _enDesarrollo(context, 'Notificaciones'),
            ),
          ]),

          // ------------------------------------------------ solo admin
          // CONTRATO: esta entrada solo existe si el usuario tiene
          // ROLE_ADMIN. Ocultarla es comodidad, no seguridad: cada
          // endpoint /api/admin/** vuelve a exigir el rol (403).
          if (usuario.esAdmin) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: AppTheme.padPantalla,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Administración',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _grupoOpciones([
              _Opcion(
                icono: Icons.admin_panel_settings_outlined,
                titulo: 'Panel de administración',
                subtitulo: 'Citas de todos, doctores, servicios y usuarios',
                onTap: () {
                  traza.navegacion(_origen, 'Abrir ${AppRoutes.admin}');
                  Navigator.of(context).pushNamed(AppRoutes.admin);
                },
              ),
            ]),
          ],

          const SizedBox(height: 20),
          const Padding(
            padding: AppTheme.padPantalla,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aplicación',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _grupoOpciones([
            _Opcion(
              icono: Icons.timeline_rounded,
              titulo: 'Trazabilidad del flujo',
              subtitulo: 'Registro de navegación, acciones y validaciones',
              onTap: () {
                traza.navegacion(_origen, 'Abrir ${AppRoutes.trazabilidad}');
                Navigator.of(context).pushNamed(AppRoutes.trazabilidad);
              },
            ),
            _Opcion(
              icono: Icons.auto_awesome_rounded,
              titulo: 'Ver introducción de nuevo',
              subtitulo: 'Reproduce la bienvenida animada',
              onTap: () {
                AppStateScope.leer(context).reiniciarOnboarding();
                traza.navegacion(_origen, 'Abrir ${AppRoutes.onboarding}');
                Navigator.of(context).pushNamed(AppRoutes.onboarding);
              },
            ),
            _Opcion(
              icono: Icons.help_outline_rounded,
              titulo: 'Ayuda y soporte',
              onTap: () => _enDesarrollo(context, 'Ayuda y soporte'),
            ),
            _Opcion(
              icono: Icons.info_outline_rounded,
              titulo: 'Acerca de SaludCuidado',
              subtitulo: 'Versión 1.0.0',
              onTap: () => _acercaDe(context),
            ),
          ]),

          const SizedBox(height: 24),

          // --------------------------------------------- cerrar sesion
          Padding(
            padding: AppTheme.padPantalla,
            child: OutlinedButton.icon(
              onPressed: () => _confirmarCierre(context),
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.peligro,
                side: const BorderSide(color: AppColors.peligro),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radio),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- acciones

  static void _enDesarrollo(BuildContext context, String opcion) {
    traza.accion(_origen, 'Opcion "$opcion" (no incluida en el prototipo)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$opcion no está incluido en el prototipo')),
    );
  }

  static void _acercaDe(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SaludCuidado',
      applicationVersion: '1.0.0',
      applicationLegalese:
          'Fundación Tecnológico Comfenalco - Computación Móvil\n'
          'Brandon Llamas, Carlos Gómez, Camilo Mackensie, Aurelio Guzmán',
      children: const [
        SizedBox(height: 12),
        Text(
          'Aplicación móvil de gestión de citas médicas construida en Flutter '
          'a partir de los mocks de Penpot y de los contratos del documento '
          'de entregables.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
  }

  /// CONTRATO: muestra dialogo de confirmacion y navega a /login.
  static Future<void> _confirmarCierre(BuildContext context) async {
    traza.accion(_origen, 'Solicitud de cierre de sesión');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radio),
        ),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmado != true || !context.mounted) {
      traza.accion(_origen, 'Cierre de sesión cancelado');
      return;
    }

    AppStateScope.leer(context).cerrarSesion();
    traza.navegacion(_origen, 'Cierre confirmado -> ${AppRoutes.login}',
        contrato: 'PerfilScreen.Garantiza');
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (ruta) => false);
  }

  // -------------------------------------------------------------- widgets

  static Widget _grupoOpciones(List<_Opcion> opciones) {
    return Padding(
      padding: AppTheme.padPantalla,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (int i = 0; i < opciones.length; i++) ...[
              opciones[i],
              if (i < opciones.length - 1)
                const Divider(height: 1, indent: 56),
            ],
          ],
        ),
      ),
    );
  }
}

class _Estadistica extends StatelessWidget {
  final int valor;
  final String etiqueta;
  final IconData icono;
  final Color color;

  const _Estadistica({
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(height: 7),
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icono, size: 18, color: AppColors.primary),
      ),
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 21),
    );
  }
}
