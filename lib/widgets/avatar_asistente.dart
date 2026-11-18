import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Cara del asistente de SaludCuidado.
///
/// Dibujada con `CustomPainter`, como el resto de las ilustraciones del
/// proyecto: no hay imagen ni paquete externo, así que escala a cualquier
/// densidad sin assets y no engorda el binario.
///
/// Es deliberadamente simple y amable: dos ojos, una sonrisa y una antena.
/// Lo importante es que **no se parezca a un avatar de persona**, para que
/// nadie confunda al asistente con un médico de verdad, y que tampoco sea
/// el círculo gris de "usuario sin foto".
class AvatarAsistente extends StatefulWidget {
  const AvatarAsistente({
    super.key,
    this.tamano = 40,
    this.animado = true,
    this.fondo,
  });

  final double tamano;

  /// Parpadea y mueve la antena. Se apaga en listas largas, donde varias
  /// animaciones a la vez no aportan nada y gastan batería.
  final bool animado;

  /// Color del disco. Por defecto el primario de la app.
  final Color? fondo;

  @override
  State<AvatarAsistente> createState() => _AvatarAsistenteState();
}

class _AvatarAsistenteState extends State<AvatarAsistente>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animado) _c.repeat();
  }

  @override
  void didUpdateWidget(AvatarAsistente anterior) {
    super.didUpdateWidget(anterior);
    if (widget.animado && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animado && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.tamano,
      height: widget.tamano,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _CaraAsistente(
            t: widget.animado ? _c.value : 0.35,
            fondo: widget.fondo ?? AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _CaraAsistente extends CustomPainter {
  _CaraAsistente({required this.t, required this.fondo});

  /// 0..1 ciclico.
  final double t;
  final Color fondo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centro = Offset(w / 2, h / 2);

    // Disco con un degradado suave, para que no quede plano.
    final disco = Rect.fromCircle(center: centro, radius: w / 2);
    canvas.drawCircle(
      centro,
      w / 2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(fondo, Colors.white, 0.18)!,
            Color.lerp(fondo, Colors.black, 0.12)!,
          ],
        ).createShader(disco),
    );

    final blanco = Paint()..color = Colors.white;

    // Antena: se inclina muy levemente, como si estuviera atenta.
    final vaiven = math.sin(t * 2 * math.pi) * 0.06;
    final baseAntena = Offset(centro.dx, centro.dy - h * 0.26);
    final puntaAntena = Offset(
      centro.dx + math.sin(vaiven) * w * 0.10,
      centro.dy - h * 0.40,
    );
    canvas.drawLine(
      baseAntena,
      puntaAntena,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(puntaAntena, w * 0.065, blanco);

    // Ojos. Parpadean en un instante corto del ciclo: si el parpadeo
    // durara mucho, parecería que está dormido.
    final fase = t % 1;
    final parpadeo = fase > 0.92 ? (fase - 0.92) / 0.08 : 0.0;
    final cierre = parpadeo <= 0
        ? 0.0
        : (parpadeo < 0.5 ? parpadeo * 2 : (1 - parpadeo) * 2);

    final rOjo = w * 0.075;
    final alturaOjo = rOjo * 2 * (1 - cierre * 0.92);
    for (final signo in [-1, 1]) {
      final o = Offset(centro.dx + signo * w * 0.155, centro.dy - h * 0.045);
      if (alturaOjo <= 1.2) {
        // Ojo cerrado: una rayita, no un óvalo aplastado.
        canvas.drawLine(
          Offset(o.dx - rOjo, o.dy),
          Offset(o.dx + rOjo, o.dy),
          Paint()
            ..color = Colors.white
            ..strokeWidth = w * 0.035
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: rOjo * 2, height: alturaOjo),
            Radius.circular(rOjo),
          ),
          blanco,
        );
      }
    }

    // Sonrisa.
    final bocaAncho = w * 0.30;
    final boca = Rect.fromCenter(
      center: Offset(centro.dx, centro.dy + h * 0.115),
      width: bocaAncho,
      height: h * 0.17,
    );
    canvas.drawArc(
      boca,
      0.15 * math.pi,
      0.70 * math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.048
        ..strokeCap = StrokeCap.round,
    );

    // Brillo superior, el mismo recurso que usan los avatares ilustrados.
    canvas.drawCircle(
      Offset(centro.dx - w * 0.19, centro.dy - h * 0.22),
      w * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_CaraAsistente old) => old.t != t || old.fondo != fondo;
}
