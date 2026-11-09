import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/trace/trace_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  traza.accion('main', 'Aplicación SaludCuidado iniciada');
  runApp(const SaludCuidadoApp());
}
