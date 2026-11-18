import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/api/api_cliente.dart';
import '../data/app_state.dart';
import '../models/mensaje_chat.dart';
import '../widgets/cita_card.dart';
import '../widgets/doctor_card.dart';

/// Asistente de SaludCuidado.
///
/// CONTRATO: ChatScreen
///   Requiere : sesión iniciada y servidor disponible
///   Garantiza: cada respuesta del asistente sale de una consulta a la
///              base de datos, y las citas y médicos que menciona se
///              muestran como tarjetas reales, no como texto
///   Falla si : no hay servidor -> se explica que el asistente necesita
///              conexión, porque consulta datos vivos
///
/// Trazabilidad: `chatbot.html` + `ChatController.java` de la plataforma
/// web. El asistente del backend resuelve por reglas sobre SQL; no es un
/// modelo de lenguaje, y la propia pantalla lo dice para no prometer algo
/// que no hace.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const String ruta = '/asistente';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _origen = 'ChatScreen';

  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<MensajeChat> _mensajes = [];

  bool _esperando = false;

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Asistente abierto', contrato: 'ChatScreen');
    _mensajes.add(MensajeChat(
      autor: Autor.asistente,
      texto: 'Hola. Puedo consultar tus citas, los médicos de la clínica y '
          'sus horarios libres.\n\n'
          'Pregúntame algo o toca una de las sugerencias.',
      sugerencias: const [
        '¿Cuándo es mi próxima cita?',
        '¿Qué citas tengo?',
        'Muéstrame los pediatras',
        '¿Qué servicios ofrecen?',
      ],
    ));
  }

  @override
  void dispose() {
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _alFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  /// CONTRATO: _enviar
  ///   Requiere : texto no vacío y que no haya otra pregunta en curso
  ///   Garantiza: la pregunta aparece al instante y la respuesta sustituye
  ///              al indicador de "escribiendo"
  ///   Falla si : el servidor no responde -> burbuja de error, y la
  ///              conversación continúa
  Future<void> _enviar(String texto) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty || _esperando) return;

    _campo.clear();
    setState(() {
      _mensajes
        ..add(MensajeChat.dePersona(mensaje))
        ..add(MensajeChat.pensando());
      _esperando = true;
    });
    _alFondo();
    traza.accion(_origen, 'Pregunta enviada: "$mensaje"');

    final estado = AppStateScope.leer(context);
    final repo = estado.repositorio;

    MensajeChat respuesta;
    if (repo == null || !estado.enLinea) {
      respuesta = MensajeChat.deError(
        'El asistente necesita conexión con el servidor: sus respuestas '
        'salen de consultar la base de datos en ese momento, así que no '
        'tiene una versión guardada que ofrecerte.',
      );
      traza.error(_origen, 'Asistente no disponible: sin servidor');
    } else {
      try {
        respuesta = await repo.chat(mensaje);
        traza.datos(
          _origen,
          'Respuesta del asistente (intención: ${respuesta.intencion})',
          contrato: 'POST /api/chat',
        );
      } on ApiExcepcion catch (e) {
        respuesta = MensajeChat.deError(e.mensaje);
        traza.error(_origen, 'El asistente respondió error: ${e.mensaje}');
      } on SinConexion catch (e) {
        respuesta = MensajeChat.deError(
          'No pude llegar al servidor. Revisa tu conexión y vuelve a '
          'intentarlo.',
        );
        traza.error(_origen, 'Asistente sin conexión: ${e.detalle}');
      }
    }

    if (!mounted) return;
    setState(() {
      _mensajes.removeWhere((m) => m.escribiendo);
      _mensajes.add(respuesta);
      _esperando = false;
    });
    _alFondo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente'),
        actions: [
          IconButton(
            tooltip: 'Cómo funciona',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _explicar,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              itemCount: _mensajes.length,
              itemBuilder: (context, i) => _Burbuja(
                mensaje: _mensajes[i],
                onSugerencia: _esperando ? null : _enviar,
              ),
            ),
          ),
          _barraEscritura(),
        ],
      ),
    );
  }

  void _explicar() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cómo funciona'),
        content: const Text(
          'Este asistente no es una inteligencia artificial. Reconoce un '
          'conjunto concreto de preguntas y responde consultando la base de '
          'datos de la clínica.\n\n'
          'Lo hace así a propósito: cada respuesta sale de una consulta '
          'verificable, y sobre datos médicos no puede inventarse una cita '
          'que no existe.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _barraEscritura() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _campo,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _enviar,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: Material(
                color: _esperando ? AppColors.border : AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _esperando ? null : () => _enviar(_campo.text),
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: _esperando ? AppColors.textHint : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje, required this.onSugerencia});

  final MensajeChat mensaje;
  final void Function(String)? onSugerencia;

  @override
  Widget build(BuildContext context) {
    final esPersona = mensaje.autor == Autor.persona;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            esPersona ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                esPersona ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!esPersona) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mensaje.error
                        ? AppColors.peligro.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    mensaje.error
                        ? Icons.cloud_off_rounded
                        : Icons.support_agent_rounded,
                    size: 17,
                    color:
                        mensaje.error ? AppColors.peligro : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: esPersona
                        ? AppColors.primary
                        : mensaje.error
                            ? AppColors.peligro.withValues(alpha: 0.07)
                            : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(esPersona ? 16 : 4),
                      bottomRight: Radius.circular(esPersona ? 4 : 16),
                    ),
                    border: esPersona
                        ? null
                        : Border.all(
                            color: mensaje.error
                                ? AppColors.peligro.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                  ),
                  child: mensaje.escribiendo
                      ? const _Puntos()
                      : Text(
                          mensaje.texto,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: esPersona
                                ? Colors.white
                                : mensaje.error
                                    ? AppColors.peligro
                                    : AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Las citas y los médicos que el asistente consultó se muestran
          // como tarjetas: lo mismo que se ve en el resto de la app.
          if (mensaje.citas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: Column(
                children: [
                  for (final c in mensaje.citas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CitaCard(cita: c),
                    ),
                ],
              ),
            ),
          if (mensaje.doctores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in mensaje.doctores)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radio),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DoctorAvatar(doctor: d, tamano: 30),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.nombre,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                d.especialidad,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: d.color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          if (mensaje.sugerencias.isNotEmpty && onSugerencia != null)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in mensaje.sugerencias)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onSugerencia!(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (!mensaje.escribiendo)
            Padding(
              padding: EdgeInsets.only(
                left: esPersona ? 0 : 38,
                top: 5,
              ),
              child: Text(
                Fechas.hora12(
                  '${mensaje.momento.hour.toString().padLeft(2, '0')}:'
                  '${mensaje.momento.minute.toString().padLeft(2, '0')}',
                ),
                style: const TextStyle(fontSize: 10.5, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tres puntos animados mientras el servidor responde.
class _Puntos extends StatefulWidget {
  const _Puntos();

  @override
  State<_Puntos> createState() => _PuntosState();
}

class _PuntosState extends State<_Puntos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                // Cada punto va un tercio de ciclo por detrás del anterior.
                opacity: 0.3 + 0.7 * _onda((_c.value + i / 3) % 1),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Sube y baja una vez por ciclo, sin saltos.
  static double _onda(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}
