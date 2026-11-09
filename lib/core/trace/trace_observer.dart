import 'package:flutter/material.dart';

import 'trace_logger.dart';

/// Observer del Navigator que registra automaticamente cada transicion de
/// ruta en el TraceLogger. Se engancha en MaterialApp.navigatorObservers,
/// de modo que el flujo completo de pantallas queda trazado sin que cada
/// pantalla tenga que reportarlo.
class TraceNavigatorObserver extends NavigatorObserver {
  String _nombre(Route<dynamic>? ruta) {
    final nombre = ruta?.settings.name;
    if (nombre != null && nombre.isNotEmpty) return nombre;
    if (ruta is DialogRoute) return '(dialogo)';
    return '(ruta sin nombre)';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    traza.navegacion(
      'Navigator',
      'push ${_nombre(previousRoute)} -> ${_nombre(route)}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    traza.navegacion(
      'Navigator',
      'pop ${_nombre(route)} -> ${_nombre(previousRoute)}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    traza.navegacion(
      'Navigator',
      'replace ${_nombre(oldRoute)} -> ${_nombre(newRoute)}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    traza.navegacion('Navigator', 'remove ${_nombre(route)}');
  }
}
