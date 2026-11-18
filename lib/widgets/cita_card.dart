import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../models/cita.dart';
import '../models/estado_cita.dart';
import 'doctor_card.dart';

/// Badge de estado con el color correspondiente a EstadoCita.
class EstadoBadge extends StatelessWidget {
  final EstadoCita estado;

  /// Cuando la cita sigue PROGRAMADA pero su hora ya pasó. No es un estado
  /// del backend, así que la insignia se construye aparte.
  final bool vencida;

  const EstadoBadge({super.key, required this.estado, this.vencida = false});

  @override
  Widget build(BuildContext context) {
    final color = vencida ? AppColors.acento : estado.color;
    final icono = vencida ? Icons.history_rounded : estado.icono;
    final texto = vencida ? 'Vencida' : estado.etiqueta;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// CONTRATO: CitaCard (PDF 1.3)
///   Requiere : cita: Cita
///   Garantiza: tarjeta con info del doctor, fecha, hora y badge de estado
///              (color segun EstadoCita)
///   Falla si : cita es null -> error de compilacion
class CitaCard extends StatelessWidget {
  final Cita cita;
  final VoidCallback? onCancelar;

  /// Mover la cita a otra fecha y hora. Null en las pestañas donde no
  /// tiene sentido (una cita completada no se mueve).
  final VoidCallback? onReprogramar;
  final VoidCallback? onTap;

  /// Pinta la insignia como «Vencida» en lugar de «Próxima».
  final bool vencida;

  const CitaCard({
    super.key,
    required this.cita,
    this.onCancelar,
    this.onReprogramar,
    this.onTap,
    this.vencida = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radio),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DoctorAvatar(doctor: cita.doctor, tamano: 44),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cita.doctor.especialidad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cita.doctor.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  EstadoBadge(estado: cita.estado, vencida: vencida),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 11),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      Fechas.conDia(cita.fecha),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(Icons.access_time_rounded,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    Fechas.hora12(cita.hora),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (onReprogramar != null || onCancelar != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onReprogramar != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReprogramar,
                          icon: const Icon(Icons.edit_calendar_outlined,
                              size: 17),
                          label: const Text('Reprogramar'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    if (onReprogramar != null && onCancelar != null)
                      const SizedBox(width: 10),
                    if (onCancelar != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancelar,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.peligro,
                            side: const BorderSide(color: AppColors.peligro),
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
