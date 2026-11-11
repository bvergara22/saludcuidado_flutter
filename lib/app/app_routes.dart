import 'package:flutter/material.dart';

import '../core/trace/trace_logger.dart';
import '../models/doctor.dart';
import '../screens/admin_screen.dart';
import '../screens/doctores_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/mis_citas_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/perfil_screen.dart';
import '../screens/registro_screen.dart';
import '../screens/reservar_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/trazabilidad_screen.dart';

/// Mapa de rutas con nombre. Los nombres corresponden exactamente a los
/// indicados en los contratos del documento de entregables.
///
///   /            -> SplashScreen   (navega a /login tras ~2.3 s)
///   /login       -> LoginScreen    (al enviar -> /home)
///   /registro    -> RegistroScreen (al registrar -> /home)
///   /home        -> MainShell(0)   (Inicio)
///   /doctores    -> MainShell(1)   (al tocar doctor -> /reservar con Doctor)
///   /mis-citas   -> MainShell(2)   (FAB -> /reservar)
///   /perfil      -> MainShell(3)   (cerrar sesion -> /login)
///   /reservar    -> ReservarScreen (3 pasos; al confirmar -> /mis-citas)
///   /admin       -> AdminScreen    (solo ROLE_ADMIN; el guardia esta en la
///                                   pantalla y, de verdad, en el backend)
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String registro = '/registro';
  static const String home = '/home';
  static const String doctores = '/doctores';
  static const String misCitas = '/mis-citas';
  static const String reservar = '/reservar';
  static const String perfil = '/perfil';
  static const String onboarding = '/onboarding';
  static const String trazabilidad = '/trazabilidad';
  static const String admin = AdminScreen.ruta;

  /// Generador central de rutas. Centralizarlo permite registrar la traza
  /// y resolver los argumentos de forma tipada.
  static Route<dynamic>? generar(RouteSettings settings) {
    final nombre = settings.name;
    traza.navegacion('Router', 'Resolviendo ruta $nombre');

    switch (nombre) {
      case splash:
        return _ruta(const SplashScreen(), settings);

      case login:
        return _ruta(const LoginScreen(), settings);

      case registro:
        return _ruta(const RegistroScreen(), settings);

      case home:
        // Argumento opcional: índice de pestaña inicial. LoginScreen lo usa
        // para llevar al administrador directo al panel, igual que
        // RoleBasedAuthenticationSuccessHandler redirige a /admin en la web.
        final pestana = settings.arguments;
        return _ruta(
          MainShell(indiceInicial: pestana is int ? pestana : 0),
          settings,
        );

      case doctores:
        // Si se llega por push (no por la pestaña), se muestra con botón atrás.
        return _ruta(const DoctoresScreen(mostrarAtras: true), settings);

      case misCitas:
        return _ruta(const MisCitasScreen(mostrarAtras: true), settings);

      case perfil:
        return _ruta(const PerfilScreen(mostrarAtras: true), settings);

      case onboarding:
        return _ruta(const OnboardingScreen(), settings);

      case trazabilidad:
        return _ruta(const TrazabilidadScreen(), settings);

      case admin:
        // La ruta no decide permisos: AdminScreen comprueba el rol y el
        // backend vuelve a exigirlo en cada endpoint (401/403).
        return _ruta(const AdminScreen(), settings);

      case reservar:
        // CONTRATO ReservarScreen.Requiere: arguments: Doctor? (opcional).
        final argumento = settings.arguments;
        final doctor = argumento is Doctor ? argumento : null;
        if (argumento != null && doctor == null) {
          traza.error(
            'Router',
            'Argumento invalido para $reservar: '
            '${argumento.runtimeType} (se esperaba Doctor)',
          );
        }
        return _ruta(ReservarScreen(doctorInicial: doctor), settings);

      default:
        traza.error('Router', 'Ruta desconocida: $nombre');
        return _ruta(_RutaNoEncontrada(nombre: nombre), settings);
    }
  }

  static MaterialPageRoute<dynamic> _ruta(
    Widget pantalla,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => pantalla,
      settings: settings,
    );
  }
}

class _RutaNoEncontrada extends StatelessWidget {
  final String? nombre;

  const _RutaNoEncontrada({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 14),
              Text(
                'No existe la ruta "$nombre".',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
