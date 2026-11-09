import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../models/doctor.dart';
import 'avatar_ilustrado.dart';

/// Avatar del doctor.
///
/// El mock de Penpot usaba un círculo con iniciales; aquí se sustituye por
/// un avatar ilustrado y animado (estilo Rappi) generado a partir de
/// `doctor.avatarSemilla`, con el color de su especialidad. Si el doctor
/// trae `fotoUrl`, se muestra la foto. `animado: false` lo deja quieto.
class DoctorAvatar extends StatelessWidget {
  final Doctor doctor;
  final double tamano;
  final bool animado;

  const DoctorAvatar({
    super.key,
    required this.doctor,
    this.tamano = 48,
    this.animado = true,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarIlustrado(
      semilla: doctor.avatarSemilla == 0
          ? doctor.id.hashCode.abs()
          : doctor.avatarSemilla,
      tamano: tamano,
      color: doctor.color,
      animado: animado,
      fotoUrl: doctor.fotoUrl,
      iniciales: doctor.iniciales,
    );
  }
}

/// CONTRATO: DoctorCard (PDF 1.3)
///   Requiere : doctor: Doctor, onTap: VoidCallback
///   Garantiza: tarjeta con avatar, nombre, especialidad, rating y
///              experiencia. Ejecuta onTap al presionar
///   Falla si : doctor es null -> error de compilacion
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

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
          child: Row(
            children: [
              DoctorAvatar(doctor: doctor),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.nombre,
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
                      doctor.especialidad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: doctor.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.estrella),
                        const SizedBox(width: 3),
                        Text(
                          doctor.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.work_outline_rounded,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            doctor.experienciaTexto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
