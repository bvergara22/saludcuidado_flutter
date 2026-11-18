import 'cita.dart';
import 'doctor.dart';

/// Quién escribió un mensaje de la conversación.
enum Autor { persona, asistente }

/// Un turno de la conversación con el asistente.
///
/// Trazabilidad backend: `POST /api/chat` -> `ChatController.java`.
/// El asistente puede devolver, además del texto, los datos en crudo
/// (citas o doctores) para que la app los pinte como tarjetas en lugar de
/// obligar a leerlos dentro de un párrafo.
class MensajeChat {
  final Autor autor;
  final String texto;
  final DateTime momento;

  /// Qué entendió el asistente. Se muestra en la traza, no en la burbuja:
  /// sirve para demostrar por qué respondió lo que respondió.
  final String? intencion;

  /// Preguntas que el asistente propone a continuación.
  final List<String> sugerencias;

  final List<Cita> citas;
  final List<Doctor> doctores;

  /// true mientras se espera la respuesta del servidor.
  final bool escribiendo;

  /// true si el turno terminó en error (sin red, 401...).
  final bool error;

  MensajeChat({
    required this.autor,
    required this.texto,
    DateTime? momento,
    this.intencion,
    this.sugerencias = const [],
    this.citas = const [],
    this.doctores = const [],
    this.escribiendo = false,
    this.error = false,
  }) : momento = momento ?? DateTime.now();

  factory MensajeChat.dePersona(String texto) =>
      MensajeChat(autor: Autor.persona, texto: texto);

  factory MensajeChat.pensando() => MensajeChat(
        autor: Autor.asistente,
        texto: '',
        escribiendo: true,
      );

  factory MensajeChat.deError(String texto) => MensajeChat(
        autor: Autor.asistente,
        texto: texto,
        error: true,
      );

  /// Construye la respuesta a partir del JSON de `POST /api/chat`.
  factory MensajeChat.desdeJson(
    Map<String, dynamic> j, {
    required Cita Function(Map<String, dynamic>) leerCita,
    required Doctor Function(Map<String, dynamic>) leerDoctor,
  }) {
    final citas = <Cita>[];
    for (final e in (j['citas'] as List? ?? const [])) {
      try {
        citas.add(leerCita(e as Map<String, dynamic>));
      } catch (_) {
        // Una cita mal formada no debe tumbar toda la respuesta.
      }
    }
    final doctores = <Doctor>[];
    for (final e in (j['doctores'] as List? ?? const [])) {
      try {
        doctores.add(leerDoctor(e as Map<String, dynamic>));
      } catch (_) {}
    }

    return MensajeChat(
      autor: Autor.asistente,
      texto: j['respuesta'] as String? ?? '',
      intencion: j['intencion'] as String?,
      sugerencias:
          (j['sugerencias'] as List?)?.cast<String>() ?? const <String>[],
      citas: citas,
      doctores: doctores,
    );
  }
}
