import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/api/api_cliente.dart';
import '../data/app_state.dart';
import '../models/mensaje_chat.dart';
import '../widgets/avatar_asistente.dart';
import '../widgets/cita_card.dart';
import '../widgets/doctor_card.dart';

/// Identidad del asistente.
///
/// El nombre está en un solo sitio a propósito: aparece en el botón
/// flotante, en la cabecera del chat, en el saludo y en los mensajes de
/// error, y cambiarlo debe ser cambiar una línea.
///
/// Se eligió un nombre de persona corto en vez de algo como
/// "AsistenteBot": es más fácil dirigirse a él. La pantalla explica con
/// claridad que no es una inteligencia artificial, así que ponerle nombre
/// no engaña a nadie.
class Asistente {
  Asistente._();

  static const String nombre = 'Lía';
}

/// Conversación con el asistente.
///
/// CONTRATO: ChatScreen
///   Requiere : sesión iniciada y servidor disponible
///   Garantiza: cada respuesta sale de una consulta a la base de datos, y
///              las citas y médicos que menciona se muestran como tarjetas
///              reales, no como texto
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

  static const List<String> _sugerenciasIniciales = [
    '¿Cuándo es mi próxima cita?',
    '¿Qué citas tengo?',
    'Muéstrame los pediatras',
    '¿Qué servicios ofrecen?',
  ];

  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<MensajeChat> _mensajes = [];

  bool _esperando = false;

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Asistente abierto', contrato: 'ChatScreen');
  }

  @override
  void dispose() {
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Sugerencias que se ofrecen ahora mismo: las de la última respuesta,
  /// o las iniciales mientras la conversación está vacía.
  List<String> get _sugerencias {
    if (_mensajes.isEmpty) return _sugerenciasIniciales;
    final ultima = _mensajes.last;
    if (ultima.autor == Autor.asistente && ultima.sugerencias.isNotEmpty) {
      return ultima.sugerencias;
    }
    return const [];
  }

  void _alFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
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
        '${Asistente.nombre} necesita conexión con el servidor: sus '
        'respuestas salen de consultar la base de datos en ese momento, '
        'así que no tiene una versión guardada que ofrecerte.',
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
    final enLinea = AppStateScope.of(context).enLinea;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _cabecera(enLinea),
      body: Column(
        children: [
          Expanded(
            child: _mensajes.isEmpty
                ? _bienvenida()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, i) => _Burbuja(
                      mensaje: _mensajes[i],
                      // El avatar solo acompaña al primer mensaje de una
                      // tanda seguida del asistente: repetirlo en cada
                      // burbuja ensucia la columna.
                      conAvatar: _abreTanda(i),
                    ),
                  ),
          ),
          if (_sugerencias.isNotEmpty) _tiraSugerencias(),
          _barraEscritura(),
        ],
      ),
    );
  }

  bool _abreTanda(int i) {
    if (_mensajes[i].autor != Autor.asistente) return false;
    return i == 0 || _mensajes[i - 1].autor != Autor.asistente;
  }

  PreferredSizeWidget _cabecera(bool enLinea) {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          const AvatarAsistente(tamano: 38, fondo: AppColors.primaryDeep),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  Asistente.nombre,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: enLinea
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      enLinea ? 'Conectada' : 'Sin conexión',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Cómo funciona',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: _explicar,
        ),
      ],
    );
  }

  /// Estado inicial: la cara grande, el saludo y para qué sirve.
  Widget _bienvenida() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 10),
      children: const [
        Center(child: AvatarAsistente(tamano: 86)),
        SizedBox(height: 18),
        Text(
          'Hola, soy ${Asistente.nombre}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Consulto tus citas, los médicos de la clínica y sus horarios '
          'libres directamente en la base de datos. Lo que te digo es lo '
          'que hay registrado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Prueba con',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
      ],
    );
  }

  /// Sugerencias en una tira horizontal, justo encima de donde se escribe:
  /// así están a mano en vez de perdidas arriba en la conversación.
  Widget _tiraSugerencias() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final s in _sugerencias)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _esperando ? null : () => _enviar(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            _esperando ? AppColors.textHint : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _explicar() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cómo funciona ${Asistente.nombre}'),
        content: const Text(
          'No es una inteligencia artificial. Reconoce un conjunto concreto '
          'de preguntas y responde consultando la base de datos de la '
          'clínica.\n\n'
          'Está hecha así a propósito: cada respuesta sale de una consulta '
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSuave,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _campo,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _enviar,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Escríbele a ${Asistente.nombre}…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: _esperando
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                color: _esperando ? AppColors.border : null,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _esperando ? null : () => _enviar(_campo.text),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 21,
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
  const _Burbuja({required this.mensaje, required this.conAvatar});

  final MensajeChat mensaje;
  final bool conAvatar;

  /// Sangría de todo lo que acompaña a una burbuja del asistente, para que
  /// quede alineado con su texto y no con el avatar.
  static const double _sangria = 42;

  @override
  Widget build(BuildContext context) {
    final esPersona = mensaje.autor == Autor.persona;

    return Padding(
      padding: EdgeInsets.only(bottom: conAvatar ? 13 : 7),
      child: Column(
        crossAxisAlignment:
            esPersona ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                esPersona ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!esPersona)
                SizedBox(
                  width: _sangria,
                  child: conAvatar
                      ? Padding(
                          padding: const EdgeInsets.only(right: 9, bottom: 2),
                          child: mensaje.error
                              ? Container(
                                  width: 33,
                                  height: 33,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.peligro
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_off_rounded,
                                    size: 17,
                                    color: AppColors.peligro,
                                  ),
                                )
                              : const AvatarAsistente(
                                  tamano: 33,
                                  animado: false,
                                ),
                        )
                      : null,
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    gradient: esPersona
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight,
                            ],
                          )
                        : null,
                    color: esPersona
                        ? null
                        : mensaje.error
                            ? AppColors.peligro.withValues(alpha: 0.07)
                            : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(17),
                      topRight: const Radius.circular(17),
                      bottomLeft: Radius.circular(esPersona ? 17 : 5),
                      bottomRight: Radius.circular(esPersona ? 5 : 17),
                    ),
                    border: esPersona
                        ? null
                        : Border.all(
                            color: mensaje.error
                                ? AppColors.peligro.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                    boxShadow: esPersona
                        ? null
                        : [
                            BoxShadow(
                              color:
                                  AppColors.primaryDeep.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: mensaje.escribiendo
                      ? const _Puntos()
                      : Text(
                          mensaje.texto,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.47,
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

          // Las citas y los médicos que consultó se pintan con las mismas
          // tarjetas que el resto de la app, no como texto dentro del
          // párrafo.
          if (mensaje.citas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: _sangria, top: 9),
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
              padding: const EdgeInsets.only(left: _sangria, top: 9),
              child: Column(
                children: [
                  for (final d in mensaje.doctores)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DoctorCard(
                        doctor: d,
                        // Un médico que acaba de mencionar debe poder
                        // abrirse, como en cualquier otra lista de la app.
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.ficha,
                          arguments: d,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (!mensaje.escribiendo)
            Padding(
              padding: EdgeInsets.only(
                left: esPersona ? 0 : _sangria,
                right: esPersona ? 3 : 0,
                top: 4,
              ),
              child: Text(
                Fechas.hora12(
                  '${mensaje.momento.hour.toString().padLeft(2, '0')}:'
                  '${mensaje.momento.minute.toString().padLeft(2, '0')}',
                ),
                style:
                    const TextStyle(fontSize: 10.5, color: AppColors.textHint),
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

class _PuntosState extends State<_Puntos> with SingleTickerProviderStateMixin {
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
              padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
              child: Transform.translate(
                // Suben y bajan en ola, uno detras de otro.
                offset: Offset(0, -2.5 * _onda((_c.value + i / 3) % 1)),
                child: Opacity(
                  opacity: 0.35 + 0.65 * _onda((_c.value + i / 3) % 1),
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
            ),
        ],
      ),
    );
  }

  /// Sube y baja una vez por ciclo, sin saltos.
  static double _onda(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}
