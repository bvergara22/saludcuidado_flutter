import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Rasgos de un avatar, derivados de una semilla.
///
/// La semilla viene del modelo (`Doctor.avatarSemilla`, `Usuario.avatarSemilla`),
/// así que cada persona tiene siempre la misma cara en todas las pantallas y
/// en todos los arranques de la app, sin guardar ninguna imagen.
@immutable
class RasgosAvatar {
  final Color piel;
  final Color cabello;
  final int peinado; // 0 corto · 1 ondulado · 2 recogido · 3 rizado · 4 largo
  final bool gafas;
  final bool barba;
  final bool gorro;
  final bool estetoscopio;
  final bool sonrisaAmplia;

  const RasgosAvatar({
    required this.piel,
    required this.cabello,
    required this.peinado,
    required this.gafas,
    required this.barba,
    required this.gorro,
    required this.estetoscopio,
    required this.sonrisaAmplia,
  });

  static const List<Color> _pieles = [
    Color(0xFFF7D7BE),
    Color(0xFFEFC19B),
    Color(0xFFD9A074),
    Color(0xFFB87B4F),
    Color(0xFF8D5A34),
  ];

  static const List<Color> _cabellos = [
    Color(0xFF2B2320),
    Color(0xFF4A2F22),
    Color(0xFF6B4423),
    Color(0xFF9A6B3F),
    Color(0xFF1F2937),
    Color(0xFF7A7A7A),
  ];

  /// Deriva los rasgos de forma determinista.
  ///
  /// Usa un generador congruencial propio (no `Random`) para que el
  /// resultado sea idéntico en cualquier plataforma y versión de Dart.
  factory RasgosAvatar.desdeSemilla(int semilla) {
    var s = (semilla.abs() % 1000003) + 7;
    int siguiente(int modulo) {
      s = (s * 1103515245 + 12345) & 0x7FFFFFFF;
      return (s >> 8) % modulo;
    }

    final peinado = siguiente(5);
    return RasgosAvatar(
      piel: _pieles[siguiente(_pieles.length)],
      cabello: _cabellos[siguiente(_cabellos.length)],
      peinado: peinado,
      gafas: siguiente(10) < 4,
      barba: peinado <= 1 && siguiente(10) < 4,
      gorro: siguiente(10) < 3,
      estetoscopio: siguiente(10) < 7,
      sonrisaAmplia: siguiente(10) < 6,
    );
  }
}

/// Avatar ilustrado y animado, al estilo de las ilustraciones de Rappi.
///
/// Se dibuja con CustomPainter (sin assets ni paquetes), respira y parpadea,
/// y toma el color de la especialidad del doctor para el uniforme. Si el
/// modelo trae `fotoUrl`, muestra la foto real en su lugar.
class AvatarIlustrado extends StatefulWidget {
  const AvatarIlustrado({
    super.key,
    required this.semilla,
    this.tamano = 56,
    this.color = AppColors.primary,
    this.animado = true,
    this.fotoUrl,
    this.iniciales,
    this.conBorde = true,
  });

  /// Semilla de los rasgos (ver [RasgosAvatar]).
  final int semilla;

  /// Diámetro del avatar.
  final double tamano;

  /// Color del uniforme y del fondo (color de la especialidad).
  final Color color;

  /// Si respira y parpadea.
  final bool animado;

  /// Foto real opcional: tiene prioridad sobre la ilustración.
  final String? fotoUrl;

  /// Iniciales de reserva si la foto falla y no hay semilla útil.
  final String? iniciales;

  final bool conBorde;

  @override
  State<AvatarIlustrado> createState() => _AvatarIlustradoState();
}

class _AvatarIlustradoState extends State<AvatarIlustrado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    // Ciclo largo: la respiración y el parpadeo no deben distraer.
    duration: const Duration(milliseconds: 4200),
  );

  late final int _desfase = widget.semilla.abs() % 100;

  /// Los rasgos se calculan una sola vez: así el pintor puede comparar por
  /// identidad y no se repinta más de lo necesario.
  late final RasgosAvatar _rasgos = RasgosAvatar.desdeSemilla(widget.semilla);

  @override
  void initState() {
    super.initState();
    if (widget.animado) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(AvatarIlustrado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.animado && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animado && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.tamano;

    final contenido = widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty
        ? ClipOval(
            child: Image.network(
              widget.fotoUrl!,
              width: lado,
              height: lado,
              fit: BoxFit.cover,
              // Si la foto no carga, se vuelve a la ilustración generada.
              errorBuilder: (_, __, ___) => _ilustracion(lado),
              loadingBuilder: (_, hijo, progreso) =>
                  progreso == null ? hijo : _ilustracion(lado),
            ),
          )
        : _ilustracion(lado);

    return RepaintBoundary(
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.conBorde
              ? Border.all(
                  color: widget.color.withValues(alpha: 0.22),
                  width: math.max(1, lado * 0.025),
                )
              : null,
        ),
        child: ClipOval(child: contenido),
      ),
    );
  }

  Widget _ilustracion(double lado) => AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Cada avatar arranca en un punto distinto del ciclo, así que una
          // lista de doctores no parpadea toda a la vez.
          final t = (_ctrl.value + _desfase / 100) % 1.0;
          return CustomPaint(
            size: Size(lado, lado),
            painter: _PintorAvatar(
              rasgos: _rasgos,
              color: widget.color,
              respiracion: math.sin(t * math.pi * 2),
              aperturaOjos: _apertura(t),
            ),
          );
        },
      );

  /// 1 = ojos abiertos, 0 = cerrados. Dos parpadeos rápidos por ciclo.
  double _apertura(double t) {
    if (!widget.animado) return 1;
    for (final momento in const [0.22, 0.72]) {
      final d = (t - momento).abs();
      if (d < 0.025) return (d / 0.025).clamp(0.0, 1.0);
    }
    return 1;
  }
}

class _PintorAvatar extends CustomPainter {
  _PintorAvatar({
    required this.rasgos,
    required this.color,
    required this.respiracion,
    required this.aperturaOjos,
  });

  final RasgosAvatar rasgos;
  final Color color;

  /// -1..1, mueve hombros y cabeza muy ligeramente.
  final double respiracion;

  /// 0..1, apertura de los párpados.
  final double aperturaOjos;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = w / 100; // unidad: todo se dibuja sobre un lienzo de 100x100

    // ------------------------------------------------------------- fondo
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w / 2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.07),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Burbujas decorativas del fondo (profundidad, como en las apps de reparto).
    canvas.drawCircle(
      Offset(w * 0.80, h * 0.20),
      u * 9,
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      Offset(w * 0.17, h * 0.27),
      u * 5,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final sube = respiracion * u * 0.9;

    // ----------------------------------------------------- bata y hombros
    final bata = Path()
      ..moveTo(w * 0.05, h + u * 2)
      ..cubicTo(
        w * 0.10, h * 0.70 + sube,
        w * 0.30, h * 0.62 + sube,
        w * 0.50, h * 0.62 + sube,
      )
      ..cubicTo(
        w * 0.70, h * 0.62 + sube,
        w * 0.90, h * 0.70 + sube,
        w * 0.95, h + u * 2,
      )
      ..close();
    canvas.drawPath(bata, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(
      bata,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 1.1
        ..color = const Color(0xFFE2E5EA),
    );

    // Uniforme (scrub) en el color de la especialidad, en forma de V.
    final cuelloV = Path()
      ..moveTo(w * 0.50 - u * 11, h * 0.64 + sube)
      ..lineTo(w * 0.50, h * 0.86 + sube)
      ..lineTo(w * 0.50 + u * 11, h * 0.64 + sube)
      ..cubicTo(
        w * 0.50 + u * 6, h * 0.62 + sube,
        w * 0.50 - u * 6, h * 0.62 + sube,
        w * 0.50 - u * 11, h * 0.64 + sube,
      )
      ..close();
    canvas.drawPath(cuelloV, Paint()..color = color);

    // ------------------------------------------------------- estetoscopio
    if (rasgos.estetoscopio) {
      final tubo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF374151);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.34, h * 0.655 + sube)
          ..cubicTo(
            w * 0.30, h * 0.86 + sube,
            w * 0.46, h * 0.95 + sube,
            w * 0.52, h * 0.88 + sube,
          ),
        tubo,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.66, h * 0.655 + sube)
          ..cubicTo(
            w * 0.70, h * 0.80 + sube,
            w * 0.68, h * 0.88 + sube,
            w * 0.64, h * 0.93 + sube,
          ),
        tubo,
      );
      canvas.drawCircle(
        Offset(w * 0.635, h * 0.955 + sube),
        u * 4.2,
        Paint()..color = const Color(0xFF9CA3AF),
      );
      canvas.drawCircle(
        Offset(w * 0.635, h * 0.955 + sube),
        u * 2.2,
        Paint()..color = const Color(0xFF4B5563),
      );
    }

    // ---------------------------------------------------- cuello y cabeza
    final cx = w * 0.50;
    final cy = h * 0.42 + sube;
    final rCabeza = u * 21;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + rCabeza * 0.92),
          width: u * 15,
          height: u * 12,
        ),
        Radius.circular(u * 5),
      ),
      Paint()..color = _oscurecer(rasgos.piel, 0.08),
    );

    // Orejas.
    for (final lado in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + lado * rCabeza * 0.97, cy + u * 1.5),
        u * 3.4,
        Paint()..color = _oscurecer(rasgos.piel, 0.05),
      );
    }

    // Cara.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rCabeza * 1.86,
        height: rCabeza * 2.08,
      ),
      Paint()..color = rasgos.piel,
    );

    // ------------------------------------------------------------ cabello
    _pintarCabello(canvas, cx, cy, rCabeza, u);

    // ----------------------------------------------------- ojos y sonrisa
    final sepOjos = rCabeza * 0.42;
    final yOjos = cy + u * 0.5;
    final rOjo = u * 2.9;
    final apertura = aperturaOjos.clamp(0.08, 1.0);

    for (final lado in const [-1.0, 1.0]) {
      final centroOjo = Offset(cx + lado * sepOjos, yOjos);
      // Párpado cerrado -> línea; abierto -> óvalo.
      canvas.drawOval(
        Rect.fromCenter(
          center: centroOjo,
          width: rOjo * 2,
          height: rOjo * 2 * apertura,
        ),
        Paint()..color = const Color(0xFF2B2320),
      );
      if (apertura > 0.6) {
        canvas.drawCircle(
          centroOjo.translate(rOjo * 0.32, -rOjo * 0.34),
          rOjo * 0.36,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      // Ceja.
      canvas.drawArc(
        Rect.fromCenter(
          center: centroOjo.translate(0, -rOjo * 2.5),
          width: rOjo * 3.4,
          height: rOjo * 2.6,
        ),
        math.pi * 1.08,
        math.pi * 0.84,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 1.5
          ..strokeCap = StrokeCap.round
          ..color = _oscurecer(rasgos.cabello, 0.05),
      );
    }

    // Rubor en las mejillas.
    for (final lado in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + lado * rCabeza * 0.62, cy + u * 6.5),
          width: u * 8,
          height: u * 5,
        ),
        Paint()..color = const Color(0xFFEF7E7E).withValues(alpha: 0.28),
      );
    }

    // Nariz.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + u * 4.6), width: u * 4, height: u * 4),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 1.2
        ..strokeCap = StrokeCap.round
        ..color = _oscurecer(rasgos.piel, 0.22),
    );

    // Barba (se dibuja antes de la boca para que la boca quede encima).
    if (rasgos.barba) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - rCabeza * 0.82, cy + u * 2)
          ..cubicTo(
            cx - rCabeza * 0.80, cy + rCabeza * 1.05,
            cx + rCabeza * 0.80, cy + rCabeza * 1.05,
            cx + rCabeza * 0.82, cy + u * 2,
          )
          ..cubicTo(
            cx + rCabeza * 0.5, cy + u * 9,
            cx - rCabeza * 0.5, cy + u * 9,
            cx - rCabeza * 0.82, cy + u * 2,
          )
          ..close(),
        Paint()..color = rasgos.cabello.withValues(alpha: 0.92),
      );
    }

    // Sonrisa.
    final anchoBoca = rasgos.sonrisaAmplia ? u * 13 : u * 9;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, cy + u * 8.2),
        width: anchoBoca,
        height: u * (rasgos.sonrisaAmplia ? 9 : 6),
      ),
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 1.7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A4A4A),
    );

    // ------------------------------------------------------------- gafas
    if (rasgos.gafas) {
      final marco = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 1.5
        ..color = const Color(0xFF374151);
      for (final lado in const [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + lado * sepOjos, yOjos),
              width: u * 11,
              height: u * 9,
            ),
            Radius.circular(u * 3.5),
          ),
          marco,
        );
      }
      canvas.drawLine(
        Offset(cx - u * 1.6, yOjos),
        Offset(cx + u * 1.6, yOjos),
        marco,
      );
    }

    // ------------------------------------------------------------- gorro
    if (rasgos.gorro) {
      final gorro = Path()
        ..moveTo(cx - rCabeza * 1.02, cy - rCabeza * 0.34)
        ..cubicTo(
          cx - rCabeza * 1.02, cy - rCabeza * 1.5,
          cx + rCabeza * 1.02, cy - rCabeza * 1.5,
          cx + rCabeza * 1.02, cy - rCabeza * 0.34,
        )
        ..close();
      canvas.drawPath(gorro, Paint()..color = _aclarar(color, 0.32));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy - rCabeza * 0.36),
            width: rCabeza * 2.12,
            height: u * 5,
          ),
          Radius.circular(u * 2.5),
        ),
        Paint()..color = color,
      );
    }

  }

  void _pintarCabello(
    Canvas canvas, double cx, double cy, double rCabeza, double u) {
    final pintura = Paint()..color = rasgos.cabello;

    switch (rasgos.peinado) {
      case 0: // corto, con entradas suaves
        canvas.drawPath(
          Path()
            ..moveTo(cx - rCabeza * 0.98, cy - rCabeza * 0.18)
            ..cubicTo(
              cx - rCabeza * 1.02, cy - rCabeza * 1.28,
              cx + rCabeza * 1.02, cy - rCabeza * 1.28,
              cx + rCabeza * 0.98, cy - rCabeza * 0.18,
            )
            ..cubicTo(
              cx + rCabeza * 0.72, cy - rCabeza * 0.62,
              cx - rCabeza * 0.72, cy - rCabeza * 0.62,
              cx - rCabeza * 0.98, cy - rCabeza * 0.18,
            )
            ..close(),
          pintura,
        );
      case 1: // flequillo ondulado
        canvas.drawPath(
          Path()
            ..moveTo(cx - rCabeza * 1.0, cy - rCabeza * 0.10)
            ..cubicTo(
              cx - rCabeza * 1.10, cy - rCabeza * 1.30,
              cx + rCabeza * 1.10, cy - rCabeza * 1.30,
              cx + rCabeza * 1.0, cy - rCabeza * 0.10,
            )
            ..cubicTo(
              cx + rCabeza * 0.55, cy - rCabeza * 0.30,
              cx + rCabeza * 0.20, cy - rCabeza * 0.78,
              cx - rCabeza * 0.30, cy - rCabeza * 0.40,
            )
            ..cubicTo(
              cx - rCabeza * 0.60, cy - rCabeza * 0.20,
              cx - rCabeza * 0.85, cy - rCabeza * 0.12,
              cx - rCabeza * 1.0, cy - rCabeza * 0.10,
            )
            ..close(),
          pintura,
        );
      case 2: // recogido con moño
        canvas.drawCircle(
          Offset(cx, cy - rCabeza * 1.18),
          u * 7.5,
          pintura,
        );
        canvas.drawPath(
          Path()
            ..moveTo(cx - rCabeza * 1.0, cy - rCabeza * 0.14)
            ..cubicTo(
              cx - rCabeza * 1.04, cy - rCabeza * 1.26,
              cx + rCabeza * 1.04, cy - rCabeza * 1.26,
              cx + rCabeza * 1.0, cy - rCabeza * 0.14,
            )
            ..cubicTo(
              cx + rCabeza * 0.70, cy - rCabeza * 0.70,
              cx - rCabeza * 0.70, cy - rCabeza * 0.70,
              cx - rCabeza * 1.0, cy - rCabeza * 0.14,
            )
            ..close(),
          pintura,
        );
      case 3: // rizado voluminoso
        for (var i = 0; i < 7; i++) {
          final ang = math.pi * (0.08 + i * 0.14);
          canvas.drawCircle(
            Offset(
              cx - math.cos(ang) * rCabeza * 1.02,
              cy - math.sin(ang) * rCabeza * 1.02,
            ),
            u * 7.2,
            pintura,
          );
        }
      default: // largo, cae por los lados
        canvas.drawPath(
          Path()
            ..moveTo(cx - rCabeza * 1.05, cy + rCabeza * 0.95)
            ..cubicTo(
              cx - rCabeza * 1.35, cy - rCabeza * 0.60,
              cx - rCabeza * 0.90, cy - rCabeza * 1.40,
              cx, cy - rCabeza * 1.30,
            )
            ..cubicTo(
              cx + rCabeza * 0.90, cy - rCabeza * 1.40,
              cx + rCabeza * 1.35, cy - rCabeza * 0.60,
              cx + rCabeza * 1.05, cy + rCabeza * 0.95,
            )
            ..cubicTo(
              cx + rCabeza * 0.80, cy + rCabeza * 0.10,
              cx + rCabeza * 0.95, cy - rCabeza * 0.50,
              cx, cy - rCabeza * 0.62,
            )
            ..cubicTo(
              cx - rCabeza * 0.95, cy - rCabeza * 0.50,
              cx - rCabeza * 0.80, cy + rCabeza * 0.10,
              cx - rCabeza * 1.05, cy + rCabeza * 0.95,
            )
            ..close(),
          pintura,
        );
    }
  }

  static Color _oscurecer(Color c, double cantidad) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - cantidad).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _aclarar(Color c, double cantidad) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + cantidad).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(_PintorAvatar anterior) =>
      anterior.respiracion != respiracion ||
      anterior.aperturaOjos != aperturaOjos ||
      anterior.color != color ||
      anterior.rasgos != rasgos;
}

/// Avatar del paciente (Home y Perfil): el mismo estilo ilustrado, con la
/// semilla del usuario autenticado.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({
    super.key,
    required this.semilla,
    this.tamano = 48,
    this.color = AppColors.primary,
  });

  final int semilla;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) => AvatarIlustrado(
        semilla: semilla,
        tamano: tamano,
        color: color,
      );
}
