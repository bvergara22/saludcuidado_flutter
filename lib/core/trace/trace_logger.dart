import 'package:flutter/foundation.dart';

/// Tipo de evento registrado en la traza de la aplicacion.
enum TipoEvento {
  navegacion,
  accion,
  validacion,
  datos,
  error,
}

extension TipoEventoX on TipoEvento {
  String get etiqueta {
    switch (this) {
      case TipoEvento.navegacion:
        return 'NAV';
      case TipoEvento.accion:
        return 'ACCION';
      case TipoEvento.validacion:
        return 'VALIDACION';
      case TipoEvento.datos:
        return 'DATOS';
      case TipoEvento.error:
        return 'ERROR';
    }
  }
}

/// Un evento unico de la traza.
@immutable
class EventoTraza {
  final DateTime momento;
  final TipoEvento tipo;

  /// Pantalla o componente origen (ej. "LoginScreen").
  final String origen;

  /// Descripcion legible del evento.
  final String mensaje;

  /// Contrato del PDF que cubre este evento (ej. "LoginScreen.Falla si").
  final String? contrato;

  const EventoTraza({
    required this.momento,
    required this.tipo,
    required this.origen,
    required this.mensaje,
    this.contrato,
  });

  String get horaTexto =>
      '${momento.hour.toString().padLeft(2, '0')}:'
      '${momento.minute.toString().padLeft(2, '0')}:'
      '${momento.second.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      '[$horaTexto] ${tipo.etiqueta} $origen :: $mensaje'
      '${contrato != null ? ' <- $contrato' : ''}';
}

/// Registro central de trazabilidad.
///
/// Cada pantalla y cada regla de negocio reporta aqui lo que hace, de modo que
/// el flujo de la aplicacion queda documentado en tiempo de ejecucion y puede
/// inspeccionarse desde Perfil > Trazabilidad del flujo.
class TraceLogger extends ChangeNotifier {
  TraceLogger._();

  static final TraceLogger instancia = TraceLogger._();

  static const int _maxEventos = 300;
  final List<EventoTraza> _eventos = [];

  List<EventoTraza> get eventos => List.unmodifiable(_eventos);

  /// Eventos del mas reciente al mas antiguo (orden de lectura en pantalla).
  List<EventoTraza> get eventosRecientes => _eventos.reversed.toList();

  void registrar(
    TipoEvento tipo,
    String origen,
    String mensaje, {
    String? contrato,
  }) {
    final evento = EventoTraza(
      momento: DateTime.now(),
      tipo: tipo,
      origen: origen,
      mensaje: mensaje,
      contrato: contrato,
    );
    _eventos.add(evento);
    if (_eventos.length > _maxEventos) {
      _eventos.removeAt(0);
    }
    if (kDebugMode) {
      debugPrint(evento.toString());
    }
    notifyListeners();
  }

  void navegacion(String origen, String mensaje, {String? contrato}) =>
      registrar(TipoEvento.navegacion, origen, mensaje, contrato: contrato);

  void accion(String origen, String mensaje, {String? contrato}) =>
      registrar(TipoEvento.accion, origen, mensaje, contrato: contrato);

  void validacion(String origen, String mensaje, {String? contrato}) =>
      registrar(TipoEvento.validacion, origen, mensaje, contrato: contrato);

  void datos(String origen, String mensaje, {String? contrato}) =>
      registrar(TipoEvento.datos, origen, mensaje, contrato: contrato);

  void error(String origen, String mensaje, {String? contrato}) =>
      registrar(TipoEvento.error, origen, mensaje, contrato: contrato);

  void limpiar() {
    _eventos.clear();
    notifyListeners();
  }

  /// Exporta la traza completa como texto plano (para soporte o evidencia).
  String exportarTexto() => _eventos.map((e) => e.toString()).join('\n');
}

/// Atajo global usado por pantallas y servicios.
final TraceLogger traza = TraceLogger.instancia;
