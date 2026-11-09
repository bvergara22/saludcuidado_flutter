import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Ilustraciones vectoriales animadas, dibujadas con CustomPainter.
///
/// No se usan imagenes ni paquetes externos (Lottie/Rive): todo el arte es
/// geometria calculada, de modo que escala a cualquier densidad sin assets
/// y el peso del binario no crece.

// ---------------------------------------------------------------- utilidades

/// Camino de un electrocardiograma (latido) normalizado a [w] x [h].
Path caminoLatido(double w, double h) {
  final p = Path();
  final m = h / 2;
  p.moveTo(0, m);
  p.lineTo(w * 0.16, m);
  p.lineTo(w * 0.23, m - h * 0.13);
  p.lineTo(w * 0.30, m);
  p.lineTo(w * 0.40, m);
  p.lineTo(w * 0.45, m + h * 0.14);
  p.lineTo(w * 0.52, m - h * 0.46);
  p.lineTo(w * 0.59, m + h * 0.40);
  p.lineTo(w * 0.65, m);
  p.lineTo(w * 0.74, m);
  p.lineTo(w * 0.80, m - h * 0.10);
  p.lineTo(w * 0.86, m);
  p.lineTo(w, m);
  return p;
}

/// Silueta de corazon normalizada a [w] x [h].
Path caminoCorazon(double w, double h) {
  final p = Path();
  p.moveTo(w * 0.50, h * 0.92);
  p.cubicTo(w * 0.06, h * 0.60, w * 0.00, h * 0.24, w * 0.26, h * 0.11);
  p.cubicTo(w * 0.40, h * 0.02, w * 0.50, h * 0.17, w * 0.50, h * 0.27);
  p.cubicTo(w * 0.50, h * 0.17, w * 0.60, h * 0.02, w * 0.74, h * 0.11);
  p.cubicTo(w * 1.00, h * 0.24, w * 0.94, h * 0.60, w * 0.50, h * 0.92);
  p.close();
  return p;
}

/// Dibuja [camino] revelandolo progresivamente segun [avance] (0..1)
/// y devuelve la posicion de la punta, para colocar un punto guia.
Offset? dibujarCaminoProgresivo(
  Canvas canvas,
  Path camino,
  double avance,
  Paint pincel,
) {
  if (avance <= 0) return null;
  Offset? punta;
  for (final metrica in camino.computeMetrics()) {
    final largo = metrica.length * avance.clamp(0.0, 1.0);
    canvas.drawPath(metrica.extractPath(0, largo), pincel);
    final tan = metrica.getTangentForOffset(largo);
    if (tan != null) punta = tan.position;
  }
  return punta;
}

/// Interpola con un retardo: devuelve 0 antes de [inicio] y 1 tras [fin].
double tramo(double t, double inicio, double fin, {Curve curva = Curves.easeOut}) {
  if (fin <= inicio) return t >= fin ? 1 : 0;
  final bruto = ((t - inicio) / (fin - inicio)).clamp(0.0, 1.0);
  return curva.transform(bruto);
}

// ------------------------------------------------------ 1. Buscar especialista

/// Avatares de especialistas orbitando alrededor de un nucleo, con un anillo
/// de busqueda que barre el circulo.
class ArteBuscar extends CustomPainter {
  final double avance; // 0..1 entrada
  final double giro; // radianes, rotacion continua

  ArteBuscar({required this.avance, required this.giro});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2;

    // Anillos concentricos de fondo.
    for (var i = 0; i < 3; i++) {
      final t = tramo(avance, 0.00 + i * 0.07, 0.45 + i * 0.07);
      if (t <= 0) continue;
      canvas.drawCircle(
        centro,
        radio * (0.42 + i * 0.22) * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.16 * t),
      );
    }

    // Barrido de busqueda: arco luminoso girando.
    final tBarrido = tramo(avance, 0.25, 0.70);
    if (tBarrido > 0) {
      final r = radio * 0.86;
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: r),
        giro,
        math.pi * 0.42,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: giro,
            endAngle: giro + math.pi * 0.42,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.85 * tBarrido),
            ],
          ).createShader(Rect.fromCircle(center: centro, radius: r)),
      );
    }

    // Nucleo: tarjeta de perfil estilizada.
    final tNucleo = tramo(avance, 0.05, 0.50, curva: Curves.elasticOut);
    if (tNucleo > 0) {
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.scale(tNucleo.clamp(0.0, 1.3));
      final rNucleo = radio * 0.34;
      canvas.drawCircle(
        Offset.zero,
        rNucleo,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      // Silueta de persona dentro del nucleo.
      const colorMarca = AppColors.primary;
      canvas.drawCircle(
        Offset(0, -rNucleo * 0.22),
        rNucleo * 0.30,
        Paint()..color = colorMarca,
      );
      final cuerpo = Rect.fromCenter(
        center: Offset(0, rNucleo * 0.46),
        width: rNucleo * 1.02,
        height: rNucleo * 0.62,
      );
      canvas.drawPath(
        Path()
          ..addRRect(RRect.fromRectAndCorners(
            cuerpo,
            topLeft: Radius.circular(rNucleo * 0.52),
            topRight: Radius.circular(rNucleo * 0.52),
          )),
        Paint()..color = colorMarca,
      );
      canvas.restore();
    }

    // Avatares orbitando con iniciales.
    const etiquetas = ['CM', 'AG', 'LL', 'MT'];
    for (var i = 0; i < etiquetas.length; i++) {
      final t = tramo(avance, 0.30 + i * 0.08, 0.72 + i * 0.08,
          curva: Curves.easeOutBack);
      if (t <= 0) continue;
      final angulo = giro * 0.55 + i * (math.pi * 2 / etiquetas.length);
      final r = radio * 0.72;
      final pos = Offset(
        centro.dx + math.cos(angulo) * r,
        centro.dy + math.sin(angulo) * r,
      );
      final rp = radio * 0.17 * t;
      canvas.drawCircle(
        pos,
        rp,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * t),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: etiquetas[i],
          style: TextStyle(
            color: AppColors.primary.withValues(alpha: t),
            fontSize: rp * 0.78,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(ArteBuscar old) =>
      old.avance != avance || old.giro != giro;
}

// ------------------------------------------------------------- 2. Reservar

/// Tarjeta de calendario cuyos dias aparecen escalonados; uno se selecciona
/// y un anillo de reloj completa el giro.
class ArteReservar extends CustomPainter {
  final double avance;
  final double pulso; // 0..1 ciclico

  ArteReservar({required this.avance, required this.pulso});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tarjeta = Rect.fromCenter(
      center: Offset(w / 2, h * 0.46),
      width: w * 0.72,
      height: h * 0.66,
    );

    // Entrada de la tarjeta.
    final tTarjeta = tramo(avance, 0.00, 0.42, curva: Curves.easeOutBack);
    if (tTarjeta <= 0) return;

    canvas.save();
    canvas.translate(tarjeta.center.dx, tarjeta.center.dy);
    canvas.scale(tTarjeta.clamp(0.0, 1.08));
    canvas.translate(-tarjeta.center.dx, -tarjeta.center.dy);

    final rrect = RRect.fromRectAndRadius(tarjeta, Radius.circular(w * 0.055));
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );

    // Cabecera de la tarjeta.
    final cabecera = Rect.fromLTWH(
      tarjeta.left,
      tarjeta.top,
      tarjeta.width,
      tarjeta.height * 0.20,
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      cabecera,
      Paint()..color = AppColors.primary,
    );
    canvas.restore();

    // Argollas superiores.
    for (var i = 0; i < 2; i++) {
      final x = tarjeta.left + tarjeta.width * (i == 0 ? 0.28 : 0.72);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, tarjeta.top),
            width: w * 0.022,
            height: h * 0.055,
          ),
          Radius.circular(w * 0.012),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Rejilla de dias.
    const cols = 5, filas = 3;
    final zona = Rect.fromLTRB(
      tarjeta.left + tarjeta.width * 0.11,
      cabecera.bottom + tarjeta.height * 0.12,
      tarjeta.right - tarjeta.width * 0.11,
      tarjeta.bottom - tarjeta.height * 0.12,
    );
    final dx = zona.width / (cols - 1);
    final dy = zona.height / (filas - 1);
    final rPunto = math.min(dx, dy) * 0.26;
    const seleccionado = 7; // indice del dia elegido

    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < cols; c++) {
        final i = f * cols + c;
        final t = tramo(avance, 0.30 + i * 0.018, 0.62 + i * 0.018);
        if (t <= 0) continue;
        final pos = Offset(zona.left + c * dx, zona.top + f * dy);

        if (i == seleccionado) {
          final tSel = tramo(avance, 0.66, 0.90, curva: Curves.elasticOut);
          if (tSel > 0) {
            final escala = 1 + 0.06 * math.sin(pulso * math.pi * 2);
            canvas.drawCircle(
              pos,
              rPunto * 2.0 * tSel.clamp(0.0, 1.2) * escala,
              Paint()..color = AppColors.primary,
            );
            // Check dentro del dia elegido.
            final tCheck = tramo(avance, 0.80, 0.97);
            if (tCheck > 0) {
              final r = rPunto * 2.0;
              final check = Path()
                ..moveTo(pos.dx - r * 0.42, pos.dy + r * 0.02)
                ..lineTo(pos.dx - r * 0.10, pos.dy + r * 0.34)
                ..lineTo(pos.dx + r * 0.46, pos.dy - r * 0.34);
              dibujarCaminoProgresivo(
                canvas,
                check,
                tCheck,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = r * 0.22
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.white,
              );
            }
          }
        } else {
          canvas.drawCircle(
            pos,
            rPunto * t,
            Paint()
              ..color =
                  AppColors.primary.withValues(alpha: 0.22 * t),
          );
        }
      }
    }
    canvas.restore();

    // Anillo de reloj girando en la esquina.
    final tReloj = tramo(avance, 0.55, 1.0);
    if (tReloj > 0) {
      final cr = Offset(w * 0.78, h * 0.80);
      final rr = w * 0.11;
      canvas.drawCircle(
        cr,
        rr,
        Paint()..color = Colors.white.withValues(alpha: 0.96),
      );
      canvas.drawArc(
        Rect.fromCircle(center: cr, radius: rr * 0.78),
        -math.pi / 2,
        math.pi * 2 * tReloj,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rr * 0.16
          ..strokeCap = StrokeCap.round
          ..color = AppColors.exito,
      );
      // Manecillas.
      final ang = pulso * math.pi * 2;
      canvas.drawLine(
        cr,
        cr + Offset(math.cos(ang - math.pi / 2), math.sin(ang - math.pi / 2)) *
            (rr * 0.46),
        Paint()
          ..strokeWidth = rr * 0.11
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
      canvas.drawLine(
        cr,
        cr + const Offset(0, -1) * (rr * 0.30),
        Paint()
          ..strokeWidth = rr * 0.11
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(ArteReservar old) =>
      old.avance != avance || old.pulso != pulso;
}

// ------------------------------------------------------- 3. Control de salud

/// Latido que se dibuja, corazon que late y barras de estadisticas.
class ArteSalud extends CustomPainter {
  final double avance;
  final double pulso;

  ArteSalud({required this.avance, required this.pulso});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Aro exterior de progreso.
    final centro = Offset(w / 2, h * 0.44);
    final radio = math.min(w, h) * 0.34;
    final tAro = tramo(avance, 0.00, 0.60);
    if (tAro > 0) {
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white.withValues(alpha: 0.18),
      );
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        -math.pi / 2,
        math.pi * 2 * 0.78 * tAro,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }

    // Corazon latiendo en el centro.
    final tCorazon = tramo(avance, 0.18, 0.58, curva: Curves.easeOutBack);
    if (tCorazon > 0) {
      final late = 1 + 0.10 * math.sin(pulso * math.pi * 2) +
          0.05 * math.sin(pulso * math.pi * 4);
      final lado = radio * 0.86 * tCorazon.clamp(0.0, 1.15) * late;
      canvas.save();
      canvas.translate(centro.dx - lado / 2, centro.dy - lado / 2);
      canvas.drawPath(
        caminoCorazon(lado, lado),
        Paint()..color = Colors.white.withValues(alpha: 0.97),
      );
      canvas.restore();
    }

    // Linea de latido que se dibuja sobre el aro.
    final tLinea = tramo(avance, 0.42, 0.95);
    if (tLinea > 0) {
      final lw = w * 0.86, lh = h * 0.22;
      final origen = Offset((w - lw) / 2, h * 0.80 - lh / 2);
      canvas.save();
      canvas.translate(origen.dx, origen.dy);
      final camino = caminoLatido(lw, lh);
      final punta = dibujarCaminoProgresivo(
        canvas,
        camino,
        tLinea,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.95),
      );
      if (punta != null && tLinea < 1) {
        canvas.drawCircle(
          punta,
          7,
          Paint()..color = Colors.white.withValues(alpha: 0.30),
        );
        canvas.drawCircle(punta, 3.4, Paint()..color = Colors.white);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ArteSalud old) =>
      old.avance != avance || old.pulso != pulso;
}
