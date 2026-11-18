import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../widgets/tour_guiado.dart';

/// Recorrido que explica la app una vez iniciada la sesión.
///
/// Es distinto de la bienvenida de `OnboardingScreen`: aquella se ve antes
/// de entrar y cuenta para qué sirve la app; este se ve ya dentro y enseña
/// a usarla, señalando los elementos reales de la pantalla.
///
/// Se muestra una sola vez por dispositivo. Si el usuario lo salta, no
/// vuelve a aparecer solo; se puede repetir desde Perfil.
class TourApp {
  TourApp._();

  /// Los pasos, en el orden en que alguien descubriría la app.
  ///
  /// Se habla de lo que el usuario quiere hacer ("reservar", "que no se me
  /// olvide"), no de cómo está construido por dentro.
  static List<PasoTour> pasos({required bool esAdmin}) => [
        const PasoTour(
          titulo: 'Bienvenido a SaludCuidado',
          cuerpo:
              'Te enseño en menos de un minuto lo que puedes hacer aquí. '
              'Puedes saltártelo y repetirlo cuando quieras desde Perfil.',
          icono: Icons.waving_hand_rounded,
        ),
        PasoTour(
          titulo: 'Pregunta lo que necesites',
          cuerpo:
              'El asistente responde con tus datos reales: cuándo es tu '
              'próxima cita, qué médicos hay de una especialidad o qué '
              'horas tiene libres alguien un día concreto.',
          icono: Icons.support_agent_rounded,
          ancla: AnclasTour.asistente,
          margen: 8,
        ),
        PasoTour(
          titulo: 'Elige a tu médico',
          cuerpo:
              'Búscalo por especialidad o por nombre. Al tocarlo entras en '
              'su ficha: su experiencia, dónde atiende y los próximos días '
              'con cupo. Desde ahí reservas.',
          icono: Icons.people_rounded,
          ancla: AnclasTour.doctores,
        ),
        PasoTour(
          titulo: 'Tus citas, siempre a mano',
          cuerpo:
              'Aquí están las próximas, las completadas y las canceladas. '
              'Una cita próxima la puedes reprogramar a otro día u hora, o '
              'cancelarla, sin tener que volver a empezar.',
          icono: Icons.calendar_today_rounded,
          ancla: AnclasTour.misCitas,
        ),
        PasoTour(
          titulo: 'Ajústalo a ti',
          cuerpo:
              'En Perfil activas los recordatorios de tus citas y la huella '
              'para entrar. Tus citas quedan guardadas en el teléfono, así '
              'que puedes consultarlas aunque te quedes sin internet.',
          icono: Icons.person_rounded,
          ancla: AnclasTour.perfil,
        ),
        if (esAdmin)
          const PasoTour(
            titulo: 'Tienes panel de administración',
            cuerpo:
                'Tu cuenta es de administrador, así que ves una pestaña más '
                'con el panel: médicos, servicios y todas las citas de la '
                'clínica.',
            icono: Icons.shield_rounded,
          ),
        const PasoTour(
          titulo: 'Eso es todo',
          cuerpo:
              'Ya puedes reservar tu primera cita. Si algo no te cuadra, '
              'pregúntale al asistente.',
          icono: Icons.check_circle_rounded,
        ),
      ];

  /// CONTRATO: mostrarSiTocaAsync
  ///   Requiere : un contexto montado, después de iniciar sesión
  ///   Garantiza: el recorrido se muestra como mucho una vez por
  ///              dispositivo, y queda marcado tanto si se completa como si
  ///              se salta
  ///   Falla si : no hay almacenamiento -> no se muestra, en lugar de
  ///              repetirse en cada arranque, que sería peor
  static Future<void> mostrarSiToca(
    BuildContext context, {
    required bool esAdmin,
  }) async {
    final prefs = Preferencias.yo;
    // Sin almacenamiento no se puede recordar que ya se vio. Mostrarlo en
    // cada entrada resultaría molesto, así que se omite.
    if (!prefs.disponible || prefs.tourVisto) return;

    // Se marca ANTES de mostrarlo: si la app se cierra a mitad del
    // recorrido, no vuelve a aparecer sin que el usuario lo pida.
    await prefs.marcarTourVisto(true);

    if (!context.mounted) return;
    await mostrarTour(context, pasos(esAdmin: esAdmin));
  }

  /// Repite el recorrido a petición del usuario (desde Perfil).
  static Future<void> repetir(
    BuildContext context, {
    required bool esAdmin,
  }) =>
      mostrarTour(context, pasos(esAdmin: esAdmin));
}
