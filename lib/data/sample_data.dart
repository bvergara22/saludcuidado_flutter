import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../models/estado_cita.dart';
import '../models/servicio.dart';

/// Horarios base de atencion.
/// Trazabilidad backend: CitaService.obtenerHorariosDisponiblesString()
/// -> de 07:00 a 19:00, cada 30 minutos.
const List<String> horariosBase = [
  '07:00', '07:30', '08:00', '08:30', '09:00', '09:30',
  '10:00', '10:30', '11:00', '11:30', '12:00', '12:30',
  '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
  '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
  '19:00',
];

/// CONTRATO: sampleDoctors disponible en memoria
/// (requerido por HomeScreen y DoctoresScreen).
/// Datos tomados del mock "Pantalla 5: Doctores" de Penpot.
final List<Doctor> sampleDoctors = [
  const Doctor(
    id: 'doc-001',
    nombre: 'Dr. Carlos Mendoza',
    especialidad: 'Cardiología',
    iniciales: 'CM',
    rating: 4.9,
    experiencia: 12,
    clinica: 'Clínica SaludCuidado - Sede Norte',
    descripcion:
        'Especialista en cardiología clínica e intervencionista. Enfocado en '
        'prevencion cardiovascular, hipertensión y control de arritmias.',
    color: AppColors.cardiologia,
    horariosDisponibles: [
      '08:00', '08:30', '09:00', '10:00', '10:30',
      '14:00', '14:30', '15:00', '16:00',
    ],
  ),
  const Doctor(
    id: 'doc-002',
    nombre: 'Dra. Ana García',
    especialidad: 'Pediatría',
    iniciales: 'AG',
    rating: 4.8,
    experiencia: 8,
    clinica: 'Clínica SaludCuidado - Sede Centro',
    descripcion:
        'Pediatra con enfoque en crecimiento y desarrollo infantil, control '
        'de niño sano y atención de enfermedades respiratorias.',
    color: AppColors.pediatria,
    horariosDisponibles: [
      '07:00', '07:30', '08:00', '09:00', '09:30',
      '11:00', '15:00', '15:30', '16:30',
    ],
  ),
  const Doctor(
    id: 'doc-003',
    nombre: 'Dr. Luis López',
    especialidad: 'Dermatología',
    iniciales: 'LL',
    rating: 4.7,
    experiencia: 10,
    clinica: 'Clínica SaludCuidado - Sede Norte',
    descripcion:
        'Dermatólogo clinico y estético. Tratamiento de acné, dermatitis, '
        'psoriasis y revision preventiva de lunares.',
    color: AppColors.dermatologia,
    horariosDisponibles: [
      '09:00', '09:30', '10:00', '11:00', '11:30',
      '13:00', '17:00', '17:30', '18:00',
    ],
  ),
  const Doctor(
    id: 'doc-004',
    nombre: 'Dra. María Torres',
    especialidad: 'Neurología',
    iniciales: 'MT',
    rating: 4.9,
    experiencia: 15,
    clinica: 'Clínica SaludCuidado - Sede Sur',
    descripcion:
        'Neuróloga especializada en cefaleas, epilepsia y trastornos del '
        'sueño. Amplia experiencia en electroencefalografía.',
    color: AppColors.neurologia,
    horariosDisponibles: [
      '08:30', '10:00', '10:30', '12:00',
      '14:00', '14:30', '16:00', '16:30',
    ],
  ),
  const Doctor(
    id: 'doc-005',
    nombre: 'Dr. Roberto Sánchez',
    especialidad: 'Traumatología',
    iniciales: 'RS',
    rating: 4.6,
    experiencia: 9,
    clinica: 'Clínica SaludCuidado - Sede Centro',
    descripcion:
        'Traumatólogo y ortopedista. Manejo de lesiones deportivas, fracturas '
        'y rehabilitación osteomuscular.',
    color: AppColors.traumatologia,
    horariosDisponibles: [
      '07:30', '08:00', '09:30', '11:00',
      '13:30', '15:00', '17:00', '18:30',
    ],
  ),
  const Doctor(
    id: 'doc-006',
    nombre: 'Dra. Elena Morales',
    especialidad: 'Ginecología',
    iniciales: 'EM',
    rating: 4.8,
    experiencia: 11,
    clinica: 'Clínica SaludCuidado - Sede Sur',
    descripcion:
        'Ginecóloga y obstetra. Control prenatal, planificación familiar y '
        'detección temprana de cancer de cuello uterino.',
    color: AppColors.ginecologia,
    horariosDisponibles: [
      '08:00', '08:30', '10:00', '10:30',
      '12:00', '14:30', '15:30', '16:00',
    ],
  ),
];

/// Lista de especialidades para los chips de filtro en DoctoresScreen.
/// "Todas" es el valor por defecto del mock.
List<String> get especialidades {
  final unicas = <String>{};
  for (final d in sampleDoctors) {
    unicas.add(d.especialidad);
  }
  return ['Todas', ...unicas];
}

/// CONTRATO: Servicios del grid de HomeScreen.
/// Trazabilidad backend: DataInitializer -> Medicina General (30 min),
/// Odontologia (60 min), Pediatria (45 min). Se amplia con los servicios
/// correspondientes a las especialidades del mock.
const List<Servicio> sampleServicios = [
  Servicio(
    id: 'srv-001',
    nombre: 'Medicina General',
    descripcion: 'Evaluación y seguimiento en medicina general.',
    duracionMinutos: 30,
    icono: Icons.medical_services_outlined,
    color: AppColors.medicinaGeneral,
  ),
  Servicio(
    id: 'srv-002',
    nombre: 'Odontología',
    descripcion:
        'Servicios dentales: limpieza, extracciones y tratamientos de conducto.',
    duracionMinutos: 60,
    icono: Icons.masks_outlined,
    color: AppColors.odontologia,
  ),
  Servicio(
    id: 'srv-003',
    nombre: 'Pediatría',
    descripcion: 'Atención medica especializada para niños y adolescentes.',
    duracionMinutos: 45,
    icono: Icons.child_care_outlined,
    color: AppColors.pediatria,
  ),
  Servicio(
    id: 'srv-004',
    nombre: 'Cardiología',
    descripcion: 'Control cardiovascular, hipertensión y arritmias.',
    duracionMinutos: 40,
    icono: Icons.favorite_outline,
    color: AppColors.cardiologia,
  ),
  Servicio(
    id: 'srv-005',
    nombre: 'Dermatología',
    descripcion: 'Diagnóstico y tratamiento de afecciones de la piel.',
    duracionMinutos: 30,
    icono: Icons.spa_outlined,
    color: AppColors.dermatologia,
  ),
  Servicio(
    id: 'srv-006',
    nombre: 'Laboratorio',
    descripcion: 'Toma de muestras y exámenes de laboratorio clinico.',
    duracionMinutos: 20,
    icono: Icons.science_outlined,
    color: AppColors.neurologia,
  ),
];

/// CONTRATO: sampleCitas disponible en memoria
/// (requerido por HomeScreen, MisCitasScreen y PerfilScreen).
List<Cita> construirSampleCitas() {
  final hoy = DateTime.now();
  DateTime enDias(int dias) => DateTime(hoy.year, hoy.month, hoy.day + dias);

  return [
    Cita(
      id: 'cita-001',
      doctor: sampleDoctors[0],
      fecha: enDias(2),
      hora: '10:00',
      estado: EstadoCita.proxima,
      servicio: 'Cardiología',
    ),
    Cita(
      id: 'cita-002',
      doctor: sampleDoctors[1],
      fecha: enDias(5),
      hora: '09:00',
      estado: EstadoCita.proxima,
      servicio: 'Pediatría',
    ),
    Cita(
      id: 'cita-003',
      doctor: sampleDoctors[2],
      fecha: enDias(-7),
      hora: '11:00',
      estado: EstadoCita.completada,
      servicio: 'Dermatología',
    ),
    Cita(
      id: 'cita-004',
      doctor: sampleDoctors[3],
      fecha: enDias(-14),
      hora: '14:30',
      estado: EstadoCita.completada,
      servicio: 'Neurología',
    ),
    Cita(
      id: 'cita-005',
      doctor: sampleDoctors[4],
      fecha: enDias(-3),
      hora: '15:00',
      estado: EstadoCita.cancelada,
      servicio: 'Traumatología',
    ),
  ];
}
