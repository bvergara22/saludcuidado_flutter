import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../widgets/arte_animado.dart';
import '../widgets/marca.dart';

/// CONTRATO: SplashScreen (PDF 1.2)
///   Requiere : ningun parametro externo
///   Garantiza: muestra logo animado y navega automaticamente despues de
///              ~2.3 segundos
///   Falla si : el widget es desmontado antes de completar la animacion
///              (mounted == false) -> cancela la navegacion
///
/// EXTENSION respecto al PDF: el destino ya no es siempre /login. Si la
/// introduccion no se ha visto en esta sesion navega a /onboarding, que
/// termina en /login. Ver TRAZABILIDAD.md, seccion "Extensiones".
///
/// La animacion es una secuencia encadenada sobre una sola linea de tiempo:
///   0.00-0.42  el logo entra con rebote elastico
///   0.10-0.70  tres anillos de pulso se expanden escalonados
///   0.26-0.68  se traza la linea de latido bajo el lema
///   0.44-0.76  el titulo aparece letra por letra
///   0.62-0.84  el lema se desliza hacia arriba
///   0.88-1.00  todo se desvanece hacia la siguiente pantalla
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _origen = 'SplashScreen';
  static const Duration _espera = Duration(milliseconds: 2300);
  static const String _titulo = 'SaludCuidado';

  /// Secuencia de entrada (una sola linea de tiempo).
  late final AnimationController _secuencia = AnimationController(
    vsync: this,
    duration: _espera,
  );

  /// Movimiento continuo: halos del fondo, respiracion del logo y puntos.
  late final AnimationController _ambiente = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Splash iniciado (secuencia de 2.3 s)',
        contrato: 'SplashScreen.Garantiza');
    _secuencia.forward();
    _temporizador = Timer(_espera, _continuar);
  }

  void _continuar() {
    // CONTRATO "Falla si": si el widget ya fue desmontado, no se navega.
    if (!mounted) {
      traza.error(_origen, 'Widget desmontado: navegación cancelada',
          contrato: 'SplashScreen.Falla si (mounted == false)');
      return;
    }

    final estado = AppStateScope.leer(context);
    final destino =
        estado.onboardingVisto ? AppRoutes.login : AppRoutes.onboarding;

    traza.navegacion(_origen, 'Navegación automática -> $destino',
        contrato: 'SplashScreen.Garantiza');
    Navigator.of(context).pushReplacementNamed(destino);
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _secuencia.dispose();
    _ambiente.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_secuencia, _ambiente]),
        builder: (context, _) {
          final t = _secuencia.value;
          final amb = _ambiente.value;
          // Salida global: se desvanece y se acerca levemente.
          final salida = tramo(t, 0.88, 1.0);
          return Opacity(
            opacity: 1 - salida,
            child: Transform.scale(
              scale: 1 + salida * 0.08,
              child: _fondo(amb, child: _contenido(t, amb)),
            ),
          );
        },
      ),
    );
  }

  /// Degradado azul con dos halos que respiran lentamente.
  Widget _fondo(double amb, {required Widget child}) {
    final desplace = math.sin(amb * math.pi * 2);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.gradienteSplash),
      child: Stack(
        children: [
          Positioned(top: -90 + desplace * 14, left: -70, child: _halo(240, 0.16)),
          Positioned(
            bottom: -110 - desplace * 18,
            right: -60,
            child: _halo(300, 0.12),
          ),
          child,
        ],
      ),
    );
  }

  Widget _halo(double tam, double opacidad) => Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacidad),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      );

  Widget _contenido(double t, double amb) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 3),
          _logo(t, amb),
          const SizedBox(height: 24),
          _tituloAnimado(t),
          const SizedBox(height: 10),
          _lema(t),
          const SizedBox(height: 18),
          _latido(t),
          const Spacer(flex: 4),
          _indicador(t),
          const SizedBox(height: 46),
        ],
      ),
    );
  }

  /// Logo con entrada elastica y anillos de pulso expandiendose.
  Widget _logo(double t, double amb) {
    final entrada = tramo(t, 0.0, 0.42, curva: Curves.elasticOut);
    final respira = 1 + 0.025 * math.sin(amb * math.pi * 2);

    return SizedBox(
      width: 212,
      height: 212,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tres anillos de pulso escalonados.
          for (var i = 0; i < 3; i++)
            _anilloPulso(tramo(t, 0.10 + i * 0.13, 0.70 + i * 0.13)),

          // Disco del logo.
          Transform.scale(
            scale: entrada.clamp(0.0, 1.25) * respira,
            child: Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              // Isotipo de la marca: escudo + cruz + electrocardiograma.
              child: const MarcaSaludCuidado(
                tamano: 78,
                conFondo: false,
                colorTrazo: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anilloPulso(double p) {
    if (p <= 0 || p >= 1) return const SizedBox.shrink();
    return Container(
      width: 104 + p * 104,
      height: 104 + p * 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.42 * (1 - p)),
          width: 2,
        ),
      ),
    );
  }

  /// Titulo revelado letra por letra, cada una con su propio retardo.
  Widget _tituloAnimado(double t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_titulo.length, (i) {
        final inicio = 0.44 + i * 0.016;
        final p = tramo(t, inicio, inicio + 0.18, curva: Curves.easeOutCubic);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, (1 - p) * 18),
            child: Text(
              _titulo[i],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _lema(double t) {
    final p = tramo(t, 0.62, 0.84);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, (1 - p) * 12),
        child: Text(
          'Tu salud, nuestra prioridad',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14.5,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  /// Electrocardiograma que se traza bajo el lema.
  Widget _latido(double t) {
    final p = tramo(t, 0.26, 0.68);
    if (p <= 0) return const SizedBox(height: 46);
    return SizedBox(
      height: 46,
      width: 220,
      child: CustomPaint(painter: _LatidoPainter(avance: p)),
    );
  }

  /// Tres puntos de carga que laten en secuencia.
  Widget _indicador(double t) {
    final visible = tramo(t, 0.70, 0.88);
    return Opacity(
      opacity: visible,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final fase = (_ambiente.value * 3 - i * 0.5) % 1.0;
          final escala = 0.7 + 0.5 * math.sin(fase * math.pi).abs();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Transform.scale(
              scale: escala,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: (0.55 + 0.45 * escala).clamp(0.0, 1.0)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LatidoPainter extends CustomPainter {
  final double avance;

  _LatidoPainter({required this.avance});

  @override
  void paint(Canvas canvas, Size size) {
    final camino = caminoLatido(size.width, size.height);

    // Rastro tenue completo, para insinuar el recorrido.
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final punta = dibujarCaminoProgresivo(
      canvas,
      camino,
      avance,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    // Punto guia luminoso en la cabeza del trazo.
    if (punta != null && avance < 1) {
      canvas.drawCircle(
        punta,
        8,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
      canvas.drawCircle(punta, 3.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_LatidoPainter old) => old.avance != avance;
}
