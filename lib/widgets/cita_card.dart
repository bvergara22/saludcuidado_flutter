import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../models/cita.dart';
import '../models/estado_cita.dart';
import 'doctor_card.dart';

/// Badge de estado con el color correspondiente a EstadoCita.
class EstadoBadge extends StatelessWidget {
  final EstadoCita estado;

  const EstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 13, color: estado.color),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: estado.color,
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
  final VoidCallback? onTap;

  const CitaCard({
    super.key,
    required this.cita,
    this.onCancelar,
    this.onTap,
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
                  EstadoBadge(estado: cita.estado),
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
              if (onCancelar != null &&
                  cita.estado == EstadoCita.proxima) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Cancelar cita'),
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
            ],
          ),
        ),
      ),
    );
  }
}
