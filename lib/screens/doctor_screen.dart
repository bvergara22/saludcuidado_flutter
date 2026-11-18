import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/doctor.dart';
import '../widgets/doctor_card.dart';

/// Ficha completa de un médico.
///
/// CONTRATO: DoctorScreen
///   Requiere : un [Doctor] en los argumentos de la ruta
///   Garantiza: muestra su perfil y los próximos días con horarios libres,
///              consultados al servidor; desde aquí se reserva con el
///              médico ya elegido
///   Falla si : no llega el doctor -> pantalla de error en lugar de caer
///              sin servidor -> se muestran los horarios de referencia del
///              propio médico, avisando de que no están confirmados
///
/// Trazabilidad: `doctor-perfil.html` de la plataforma web. Allí la página
/// listaba los datos del médico y un formulario de reserva aparte; aquí la
/// disponibilidad se consulta en vivo, así que lo que se ve ya está libre.
class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key, required this.doctor});

  static const String ruta = '/doctor';

  final Doctor doctor;

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  static const String _origen = 'DoctorScreen';

  /// Cuántos días por delante se consultan. Cinco cabe en una pantalla sin
  /// desplazar y es suficiente para decidir.
  static const int _diasAConsultar = 5;

  final Map<DateTime, List<String>> _libres = {};

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    traza.navegacion(
      _origen,
      'Ficha de ${widget.doctor.nombre}',
      contrato: 'DoctorScreen',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarAgenda());
  }

  /// CONTRATO: _cargarAgenda
  ///   Requiere : la pantalla montada
  ///   Garantiza: [_libres] queda con un día por cada fecha consultada,
  ///              aunque esté vacío, para poder distinguir "sin huecos" de
  ///              "todavía cargando"
  Future<void> _cargarAgenda() async {
    final estado = AppStateScope.leer(context);
    final hoy = DateTime.now();

    for (var i = 1; i <= _diasAConsultar; i++) {
      final fecha = DateTime(hoy.year, hoy.month, hoy.day + i);
      final horas = await estado.horariosDisponibles(widget.doctor, fecha);
      if (!mounted) return;
      setState(() => _libres[fecha] = horas);
    }

    if (mounted) setState(() => _cargando = false);
  }

  void _reservar() {
    traza.accion(_origen, 'Reservar con ${widget.doctor.nombre}');
    Navigator.of(context).pushNamed(
      AppRoutes.reservar,
      arguments: widget.doctor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 232,
            backgroundColor: d.color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _Cabecera(doctor: d),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
            sliver: SliverList.list(
              children: [
                _Cifras(doctor: d),
                const SizedBox(height: 20),
                if (d.descripcion.trim().isNotEmpty) ...[
                  const _Titulo('Sobre el profesional'),
                  const SizedBox(height: 8),
                  Text(
                    d.descripcion,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const _Titulo('Dónde atiende'),
                const SizedBox(height: 8),
                _Fila(icono: Icons.business_outlined, texto: d.clinica),
                if (d.telefono != null && d.telefono!.isNotEmpty)
                  _Fila(icono: Icons.phone_outlined, texto: d.telefono!),
                if (d.correo != null && d.correo!.isNotEmpty)
                  _Fila(icono: Icons.mail_outline_rounded, texto: d.correo!),
                const SizedBox(height: 20),
                const _Titulo('Próximos días con cupo'),
                const SizedBox(height: 10),
                _Agenda(
                  libres: _libres,
                  cargando: _cargando,
                  color: d.color,
                  alTocar: _reservar,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _reservar,
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text('Reservar cita'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [doctor.color, doctor.color.withValues(alpha: 0.72)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.55)),
                ),
                child: DoctorAvatar(doctor: doctor, tamano: 78),
              ),
              const SizedBox(height: 11),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  doctor.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                doctor.especialidad,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calificación, experiencia y duración típica, en una sola fila.
class _Cifras extends StatelessWidget {
  const _Cifras({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Cifra(
            valor: doctor.rating.toStringAsFixed(1),
            etiqueta: 'Calificación',
            icono: Icons.star_rounded,
            color: AppColors.estrella,
          ),
          const _Separador(),
          _Cifra(
            valor: '${doctor.experiencia}',
            etiqueta: doctor.experiencia == 1 ? 'Año' : 'Años',
            icono: Icons.workspace_premium_outlined,
            color: doctor.color,
          ),
          const _Separador(),
          _Cifra(
            valor: '${doctor.horariosDisponibles.length}',
            etiqueta: 'Horas/día',
            icono: Icons.schedule_rounded,
            color: AppColors.exito,
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(height: 5),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.border);
}

/// Los próximos días, cada uno con las horas que el servidor dio por libres.
class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.libres,
    required this.cargando,
    required this.color,
    required this.alTocar,
  });

  final Map<DateTime, List<String>> libres;
  final bool cargando;
  final Color color;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    if (libres.isEmpty && cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    final fechas = libres.keys.toList()..sort();
    final conCupo = fechas.where((f) => libres[f]!.isNotEmpty).toList();

    if (!cargando && conCupo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_outlined,
                size: 19, color: AppColors.textHint),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin cupos en los próximos días. Al reservar puedes mirar '
                'más adelante en el calendario.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final f in conCupo)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radio),
              onTap: alTocar,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radio),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Fechas.conDia(f),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${libres[f]!.length} libre(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Solo un adelanto: la elección real se hace en la
                        // pantalla de reserva, que vuelve a consultar.
                        for (final h in libres[f]!.take(5))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              Fechas.hora12(h),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        if (libres[f]!.length > 5)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              '+${libres[f]!.length - 5} más',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (cargando)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: AppColors.textHint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
