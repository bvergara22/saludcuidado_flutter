import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../models/servicio.dart';
import '../models/usuario.dart';
import '../widgets/avatar_ilustrado.dart';
import '../widgets/doctor_card.dart';
import '../widgets/estados_ui.dart';

/// CONTRATO: HomeScreen (PDF 1.2)
///   Requiere : citas y catalogo disponibles en AppState (API o respaldo)
///   Garantiza: muestra proxima cita, grid de servicios y top 3 doctores.
///              Navega a otras secciones
///   Falla si : el catalogo esta vacio -> lista vacia (no crash)
class HomeScreen extends StatelessWidget {
  /// Permite que el shell cambie de pestana desde el Home.
  final void Function(int indice)? onCambiarPestana;

  const HomeScreen({super.key, this.onCambiarPestana});

  static const String _origen = 'HomeScreen';

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);
    final usuario = estado.usuarioActual;
    final proxima = estado.proximaCita;
    final top = estado.topDoctores;
    final servicios = estado.servicios;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: estado.refrescar,
          child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Encabezado(usuario: usuario),
            BannerConexion(estado: estado),
            const SizedBox(height: 6),

            // ----------------------------------------------- proxima cita
            Padding(
              padding: AppTheme.padPantalla,
              child: Row(
                children: [
                  const _TituloSeccion('Próxima cita'),
                  const Spacer(),
                  if (proxima != null)
                    TextButton(
                      onPressed: () => _irAMisCitas(context),
                      child: const Text('Ver todas'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: AppTheme.padPantalla,
              child: proxima == null
                  ? const _SinProximaCita()
                  : _TarjetaProximaCita(cita: proxima),
            ),

            const SizedBox(height: 26),

            // -------------------------------------------- grid servicios
            const Padding(
              padding: AppTheme.padPantalla,
              child: _TituloSeccion('Servicios'),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: AppTheme.padPantalla,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: servicios.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, i) => _TarjetaServicio(
                  servicio: servicios[i],
                  onTap: () => _reservarServicio(context, servicios[i]),
                ),
              ),
            ),

            const SizedBox(height: 26),

            // ------------------------------------------- top 3 doctores
            Padding(
              padding: AppTheme.padPantalla,
              child: Row(
                children: [
                  const _TituloSeccion('Doctores destacados'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _irADoctores(context),
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // CONTRATO "Falla si": sampleDoctors vacio -> lista vacia, sin crash.
            if (top.isEmpty)
              const Padding(
                padding: AppTheme.padPantalla,
                child: _MensajeVacio(
                  icono: Icons.people_outline_rounded,
                  mensaje: 'No hay doctores disponibles por el momento.',
                ),
              )
            else
              ...top.map(
                (d) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: DoctorCard(
                    doctor: d,
                    onTap: () => _reservarConDoctor(context, d),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ navegacion

  void _irAMisCitas(BuildContext context) {
    traza.navegacion(_origen, 'Ver todas -> pestaña Mis Citas');
    if (onCambiarPestana != null) {
      onCambiarPestana!(2);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.misCitas);
    }
  }

  void _irADoctores(BuildContext context) {
    traza.navegacion(_origen, 'Ver todos -> pestaña Doctores');
    if (onCambiarPestana != null) {
      onCambiarPestana!(1);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.doctores);
    }
  }

  void _reservarConDoctor(BuildContext context, Doctor doctor) {
    traza.navegacion(
      _origen,
      'Doctor ${doctor.nombre} -> ${AppRoutes.reservar} (preseleccionado)',
      contrato: 'ReservarScreen.Requiere (arguments: Doctor?)',
    );
    Navigator.of(context).pushNamed(AppRoutes.reservar, arguments: doctor);
  }

  void _reservarServicio(BuildContext context, Servicio servicio) {
    traza.navegacion(
      _origen,
      'Servicio ${servicio.nombre} -> ${AppRoutes.reservar}',
    );
    Navigator.of(context).pushNamed(AppRoutes.reservar);
  }
}

// ----------------------------------------------------------------- widgets

class _Encabezado extends StatelessWidget {
  final Usuario usuario;

  const _Encabezado({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : hora < 19
            ? 'Buenas tardes'
            : 'Buenas noches';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.gradienteTarjeta,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saludo,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usuario.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar ilustrado del paciente, generado desde su semilla.
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: AvatarUsuario(
              semilla: usuario.avatarSemilla == 0
                  ? usuario.email.hashCode.abs()
                  : usuario.avatarSemilla,
              tamano: 44,
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TarjetaProximaCita extends StatelessWidget {
  final Cita cita;

  const _TarjetaProximaCita({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radioGrande),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.sombraTarjeta,
      ),
      child: Column(
        children: [
          Row(
            children: [
              DoctorAvatar(doctor: cita.doctor, tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita.doctor.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cita.doctor.especialidad,
                      style: TextStyle(
                        fontSize: 13,
                        color: cita.doctor.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Fechas.relativo(cita.fecha),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    Fechas.conDia(cita.fecha),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.access_time_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  Fechas.hora12(cita.hora),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinProximaCita extends StatelessWidget {
  const _SinProximaCita();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radioGrande),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_outlined,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'No tienes citas próximas',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Reserva una cita con el especialista que necesites',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 190,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.reservar),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Reservar cita'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final Servicio servicio;
  final VoidCallback onTap;

  const _TarjetaServicio({required this.servicio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radio),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: servicio.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(servicio.icono, color: servicio.color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                servicio.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                servicio.duracionTexto,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MensajeVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;

  const _MensajeVacio({required this.icono, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 34, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
