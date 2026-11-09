import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Isotipo de SaludCuidado.
///
/// Sustituye al monograma "SC" por una marca con significado: un escudo
/// (cuidado) que contiene una cruz médica (salud) atravesada por un trazo
/// de electrocardiograma (vida), con un punto que recorre el latido y un
/// anillo de pulso que respira. Está dibujado con CustomPainter, así que
/// escala sin perder nitidez y no necesita ningún asset ni paquete externo.
///
/// `animado: false` lo deja estático (útil en listas o en pruebas).
class MarcaSaludCuidado extends StatefulWidget {
  const MarcaSaludCuidado({
    super.key,
    this.tamano = 72,
    this.animado = true,
    this.conFondo = true,
    this.colorTrazo = Colors.white,
  });

  /// Lado del cuadrado que ocupa la marca.
  final double tamano;

  /// Si late y el punto recorre el electrocardiograma.
  final bool animado;

  /// Dibuja la cápsula con degradado detrás del símbolo.
  final bool conFondo;

  /// Color del símbolo (blanco sobre el degradado, primario sobre blanco).
  final Color colorTrazo;

  @override
  State<MarcaSaludCuidado> createState() => _MarcaSaludCuidadoState();
}

class _MarcaSaludCuidadoState extends State<MarcaSaludCuidado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animado) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(MarcaSaludCuidado anterior) {
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
    return RepaintBoundary(
      child: SizedBox(
        width: lado,
        height: lado,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: _PintorMarca(
              avance: widget.animado ? _ctrl.value : 0.34,
              conFondo: widget.conFondo,
              colorTrazo: widget.colorTrazo,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorMarca extends CustomPainter {
  _PintorMarca({
    required this.avance,
    required this.conFondo,
    required this.colorTrazo,
  });

  final double avance;
  final bool conFondo;
  final Color colorTrazo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final lado = math.min(w, h);

    // Latido de dos tiempos: sístole marcada y una réplica más suave.
    final pulso = _latido(avance);

    if (conFondo) {
      // Anillos de pulso que se expanden hacia fuera.
      for (var i = 0; i < 2; i++) {
        final fase = (avance + i * 0.5) % 1.0;
        final radio = lado * (0.36 + fase * 0.2);
        final alfa = (1 - fase) * 0.22;
        if (alfa <= 0.01) continue;
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          radio,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = lado * 0.022
            ..color = AppColors.primary.withValues(alpha: alfa),
        );
      }

      // Cápsula con el degradado de marca, latiendo levemente.
      final escala = 1 + pulso * 0.035;
      final cuerpo = Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: lado * 0.78 * escala,
        height: lado * 0.78 * escala,
      );
      final forma = RRect.fromRectAndRadius(
        cuerpo,
        Radius.circular(lado * 0.26),
      );
      canvas.drawRRect(
        forma.shift(Offset(0, lado * 0.02)),
        Paint()
          ..color = AppColors.primaryDark.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, lado * 0.05),
      );
      canvas.drawRRect(
        forma,
        Paint()
          ..shader = AppColors.gradienteTarjeta.createShader(cuerpo),
      );
      // Brillo diagonal superior.
      canvas.save();
      canvas.clipRRect(forma);
      canvas.drawPath(
        Path()
          ..moveTo(cuerpo.left, cuerpo.top)
          ..lineTo(cuerpo.right, cuerpo.top)
          ..lineTo(cuerpo.left, cuerpo.bottom)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      canvas.restore();
    }

    // --------------------------------------------------- escudo + cruz
    final centro = Offset(w / 2, h / 2);
    final r = lado * (conFondo ? 0.26 : 0.36);

    final escudo = _caminoEscudo(centro, r);
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lado * (conFondo ? 0.035 : 0.045)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colorTrazo.withValues(alpha: 0.95);
    canvas.drawPath(escudo, trazo);

    // Cruz médica: brazo vertical completo y brazo horizontal partido,
    // porque el electrocardiograma lo atraviesa por el centro.
    final grosor = lado * (conFondo ? 0.052 : 0.07);
    final brazo = r * 0.62;
    final relleno = Paint()..color = colorTrazo;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centro.translate(0, -r * 0.06),
          width: grosor,
          height: brazo * 1.5,
        ),
        Radius.circular(grosor / 2),
      ),
      relleno,
    );

    // --------------------------------------- electrocardiograma central
    final anchoEcg = r * 1.46;
    final ecg = _caminoLatidoCompacto(
      Offset(centro.dx - anchoEcg / 2, centro.dy - r * 0.06),
      anchoEcg,
      r * 0.56,
    );

    // El trazo se dibuja completo y el punto lo recorre; así la marca se
    // lee igual aunque la animación esté detenida.
    canvas.drawPath(
      ecg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor * 0.86
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colorTrazo,
    );

    final metricas = ecg.computeMetrics().toList();
    if (metricas.isNotEmpty) {
      final m = metricas.first;
      final posicion = m.getTangentForOffset(m.length * avance)?.position;
      if (posicion != null) {
        canvas.drawCircle(
          posicion,
          grosor * (0.52 + pulso * 0.3),
          Paint()..color = AppColors.estrella,
        );
        canvas.drawCircle(
          posicion,
          grosor * (1.1 + pulso * 0.7),
          Paint()
            ..color = AppColors.estrella.withValues(alpha: 0.28 * (1 - pulso * 0.4)),
        );
      }
    }
  }

  /// Dos pulsos por ciclo con caída suave, como un monitor cardiaco.
  double _latido(double t) {
    final a = math.exp(-math.pow((t - 0.14) * 11, 2).toDouble());
    final b = 0.55 * math.exp(-math.pow((t - 0.30) * 13, 2).toDouble());
    return (a + b).clamp(0.0, 1.0);
  }

  /// Escudo redondeado con punta inferior.
  Path _caminoEscudo(Offset c, double r) {
    final arriba = c.dy - r;
    final abajo = c.dy + r * 1.06;
    return Path()
      ..moveTo(c.dx, arriba)
      ..cubicTo(
        c.dx + r * 0.95, arriba + r * 0.06,
        c.dx + r * 0.95, c.dy + r * 0.2,
        c.dx, abajo,
      )
      ..cubicTo(
        c.dx - r * 0.95, c.dy + r * 0.2,
        c.dx - r * 0.95, arriba + r * 0.06,
        c.dx, arriba,
      );
  }

  /// Trazo de electrocardiograma que cabe dentro del escudo.
  Path _caminoLatidoCompacto(Offset inicio, double ancho, double alto) {
    final x = inicio.dx;
    final y = inicio.dy;
    return Path()
      ..moveTo(x, y)
      ..lineTo(x + ancho * 0.26, y)
      ..lineTo(x + ancho * 0.36, y - alto * 0.52)
      ..lineTo(x + ancho * 0.48, y + alto * 0.48)
      ..lineTo(x + ancho * 0.60, y)
      ..lineTo(x + ancho, y);
  }

  @override
  bool shouldRepaint(_PintorMarca anterior) =>
      anterior.avance != avance ||
      anterior.conFondo != conFondo ||
      anterior.colorTrazo != colorTrazo;
}

/// Marca horizontal: isotipo + nombre, para barras superiores.
class MarcaHorizontal extends StatelessWidget {
  const MarcaHorizontal({
    super.key,
    this.tamano = 34,
    this.colorTexto = AppColors.textPrimary,
    this.animado = true,
  });

  final double tamano;
  final Color colorTexto;
  final bool animado;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarcaSaludCuidado(tamano: tamano, animado: animado),
        SizedBox(width: tamano * 0.22),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Salud',
                style: TextStyle(
                  fontSize: tamano * 0.46,
                  fontWeight: FontWeight.w800,
                  color: colorTexto,
                  letterSpacing: -0.2,
                ),
              ),
              TextSpan(
                text: 'Cuidado',
                style: TextStyle(
                  fontSize: tamano * 0.46,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
