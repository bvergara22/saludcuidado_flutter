import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/doctor.dart';
import '../models/servicio.dart';
import '../widgets/doctor_card.dart';

/// Catálogo de servicios de la clínica.
///
/// CONTRATO: ServiciosScreen
///   Requiere : nada; usa los servicios y médicos ya cargados en AppState
///   Garantiza: cada servicio muestra su duración y los médicos que lo
///              atienden, y desde ahí se llega a la ficha de cada uno
///   Falla si : un servicio no tiene médicos -> se dice, en lugar de
///              dejar un hueco en blanco
///
/// Trazabilidad: `servicios.html` de la plataforma web. Allí el catálogo
/// era una lista informativa sin salida; aquí cada servicio enlaza con
/// quién lo atiende, que es lo que de verdad se quiere saber.
///
/// La correspondencia servicio -> médicos se hace por el nombre del
/// servicio contra la especialidad del médico, que es el criterio que ya
/// usa la semilla del backend. No hay tabla que los relacione: si algún
/// día la hubiera, este es el único punto que habría que cambiar.
class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, this.destacado});

  static const String ruta = '/servicios';

  /// Id del servicio que debe aparecer abierto al entrar. Se usa cuando se
  /// llega tocando un servicio concreto en Inicio.
  final String? destacado;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  static const String _origen = 'ServiciosScreen';

  String? _abierto;

  @override
  void initState() {
    super.initState();
    _abierto = widget.destacado;
    traza.navegacion(
      _origen,
      'Catálogo de servicios'
      '${widget.destacado == null ? '' : ' (abierto: ${widget.destacado})'}',
      contrato: 'ServiciosScreen',
    );
  }

  void _alternar(Servicio s) {
    setState(() => _abierto = _abierto == s.id ? null : s.id);
    traza.accion(
      _origen,
      _abierto == null ? 'Cerrado ${s.nombre}' : 'Abierto ${s.nombre}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);
    final servicios = estado.servicios;

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: servicios.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay servicios para mostrar.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                const Text(
                  'Cada servicio indica cuánto dura la consulta y qué '
                  'médicos lo atienden.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final s in servicios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _TarjetaServicio(
                      servicio: s,
                      medicos: _medicosDe(estado.doctores, s),
                      abierta: _abierto == s.id,
                      alAlternar: () => _alternar(s),
                    ),
                  ),
              ],
            ),
    );
  }

  static List<Doctor> _medicosDe(List<Doctor> todos, Servicio s) {
    final nombre = s.nombre.trim().toLowerCase();
    return todos
        .where((d) => d.especialidad.trim().toLowerCase() == nombre)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
  }
}

class _TarjetaServicio extends StatelessWidget {
  const _TarjetaServicio({
    required this.servicio,
    required this.medicos,
    required this.abierta,
    required this.alAlternar,
  });

  final Servicio servicio;
  final List<Doctor> medicos;
  final bool abierta;
  final VoidCallback alAlternar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(
          color: abierta
              ? servicio.color.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radio),
            onTap: alAlternar,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: servicio.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(servicio.icono,
                        size: 22, color: servicio.color),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          servicio.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${servicio.duracionTexto} · '
                          '${medicos.length} médico(s)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          if (abierta) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (servicio.descripcion.trim().isNotEmpty) ...[
                    Text(
                      servicio.descripcion,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (medicos.isEmpty)
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 17, color: AppColors.textHint),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ahora mismo no hay ningún médico asignado a '
                            'este servicio.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    for (final d in medicos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DoctorCard(
                          doctor: d,
                          onTap: () {
                            traza.navegacion(
                              'ServiciosScreen',
                              '${servicio.nombre} -> ficha de ${d.nombre}',
                            );
                            Navigator.of(context).pushNamed(
                              AppRoutes.ficha,
                              arguments: d,
                            );
                          },
                        ),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
