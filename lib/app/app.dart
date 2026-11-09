import 'package:flutter/material.dart';

import '../core/trace/trace_observer.dart';
import '../data/app_state.dart';
import 'app_routes.dart';
import 'app_theme.dart';

/// Raiz de la aplicacion SaludCuidado.
class SaludCuidadoApp extends StatefulWidget {
  const SaludCuidadoApp({super.key});

  @override
  State<SaludCuidadoApp> createState() => _SaludCuidadoAppState();
}

class _SaludCuidadoAppState extends State<SaludCuidadoApp> {
  final AppState _estado = AppState();

  @override
  void initState() {
    super.initState();
    // Comprueba el backend y precarga el catálogo mientras corre el splash.
    _estado.inicializar();
  }

  @override
  void dispose() {
    _estado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      estado: _estado,
      child: MaterialApp(
        title: 'SaludCuidado',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.tema,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generar,
        navigatorObservers: [TraceNavigatorObserver()],
      ),
    );
  }
}
