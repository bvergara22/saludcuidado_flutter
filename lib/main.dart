import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/trace/trace_logger.dart';
import 'data/preferencias.dart';
import 'servicios/notificaciones.dart';

/// Punto de entrada.
///
/// Antes de pintar nada se abren los servicios del dispositivo, porque de
/// ellos dependen decisiones que se toman en el primer fotograma: si hay
/// sesión guardada, qué tema aplicar y si la introducción ya se vio.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preferencias.abrir();
  await Notificaciones.yo.iniciar();
  traza.accion('main', 'Aplicación SaludCuidado iniciada');
  runApp(const SaludCuidadoApp());
}
