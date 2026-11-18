import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/tour_app.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import 'chat_screen.dart';

/// Preguntas frecuentes.
///
/// CONTRATO: AyudaScreen
///   Requiere : nada
///   Garantiza: responde sin servidor, porque alguien que no consigue
///              conectarse es justo quien más necesita leer esto
///   Falla si : nunca; es contenido fijo
///
/// Trazabilidad: la plataforma web no tenía una página de ayuda. Se añade
/// porque en móvil no hay un administrador al lado al que preguntarle.
class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  static const String ruta = '/ayuda';

  static const List<List<String>> _preguntas = [
    [
      '¿Cómo reservo una cita?',
      'Entra en la pestaña Doctores, toca al médico que quieras y pulsa '
          '«Reservar cita» en su ficha. Elige día y hora entre los que '
          'aparezcan: solo se muestran los que están realmente libres.',
    ],
    [
      '¿Puedo cambiar una cita sin cancelarla?',
      'Sí. En Mis Citas, cada cita próxima tiene el botón «Reprogramar». '
          'La cita se mueve al nuevo día u hora conservando su historial, '
          'así que no pierdes el registro ni tienes que empezar de cero.',
    ],
    [
      '¿Qué son las citas «vencidas»?',
      'Son citas que seguían programadas pero cuya fecha ya pasó. Se '
          'separan en su propia pestaña para que no se confundan con las '
          'próximas. Desde ahí puedes reprogramarlas o cancelarlas.',
    ],
    [
      '¿Por qué no veo horarios libres de un médico?',
      'Porque ya están todos reservados ese día. Prueba con otra fecha: en '
          'la ficha del médico aparecen los próximos días con cupo.',
    ],
    [
      '¿La app funciona sin internet?',
      'En parte. Tus citas y el catálogo quedan guardados en el teléfono, '
          'así que puedes consultarlos sin conexión; verás un aviso '
          'indicando de cuándo es la copia. Lo que no se puede hacer sin '
          'conexión es reservar, cancelar ni reprogramar, porque eso exige '
          'comprobar en el servidor que el horario sigue libre.',
    ],
    [
      '¿Cómo activo los recordatorios?',
      'En Perfil > Ajustes del dispositivo. Recibirás un aviso un día '
          'antes de cada cita y otro una hora antes. Si el sistema te pide '
          'permiso para enviar notificaciones, tienes que concederlo.',
    ],
    [
      '¿Puedo entrar con la huella?',
      'Sí, en Perfil > Ajustes del dispositivo, si tu teléfono tiene lector '
          'y ya has registrado una huella. La huella protege la sesión '
          'guardada en el teléfono; no sustituye a tu contraseña, que sigue '
          'siendo necesaria para entrar desde otro dispositivo.',
    ],
    [
      '¿Qué hago si olvidé mi contraseña?',
      'Escribe al correo de soporte desde la dirección con la que te '
          'registraste y te la restablecemos. Esta versión no envía correos '
          'automáticos de recuperación.',
    ],
    [
      '¿Mis datos médicos están seguros?',
      'Tu contraseña nunca se guarda tal cual: se almacena derivada con '
          'PBKDF2 y una sal distinta para cada usuario. Cada sesión usa un '
          'token propio, y al cambiar la contraseña se cierran las sesiones '
          'abiertas en otros dispositivos.',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y soporte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          // Antes de la lista, los dos atajos que resuelven la mayoría de
          // las dudas sin tener que leer nada.
          Row(
            children: [
              Expanded(
                child: _Atajo(
                  icono: Icons.lightbulb_outline_rounded,
                  titulo: 'Ver el recorrido',
                  cuerpo: 'Te explica la app paso a paso',
                  onTap: () {
                    traza.accion('AyudaScreen', 'Repetir recorrido guiado');
                    final esAdmin =
                        AppStateScope.leer(context).usuarioActual.esAdmin;
                    Navigator.of(context).pop();
                    TourApp.repetir(context, esAdmin: esAdmin);
                  },
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _Atajo(
                  icono: Icons.forum_outlined,
                  titulo: 'Pregúntale a ${Asistente.nombre}',
                  cuerpo: 'Resuelve dudas sobre tus citas',
                  onTap: () {
                    traza.navegacion('AyudaScreen', AppRoutes.asistente);
                    Navigator.of(context).pushNamed(AppRoutes.asistente);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Preguntas frecuentes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final p in _preguntas)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _Pregunta(titulo: p[0], cuerpo: p[1]),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radio),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_rounded,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 9),
                    Text(
                      '¿Sigues con dudas?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  'Escríbenos a soporte@saludcuidado.com o llama al '
                  '(605) 555-0100, de lunes a viernes de 7:00 a 18:00.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
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

class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.icono,
    required this.titulo,
    required this.cuerpo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String cuerpo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radio),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 21, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              cuerpo,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pregunta extends StatefulWidget {
  const _Pregunta({required this.titulo, required this.cuerpo});

  final String titulo;
  final String cuerpo;

  @override
  State<_Pregunta> createState() => _PreguntaState();
}

class _PreguntaState extends State<_Pregunta> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(
          color: _abierta
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radio),
            onTap: () => setState(() => _abierta = !_abierta),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          if (_abierta)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.cuerpo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
