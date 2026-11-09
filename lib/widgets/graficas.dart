import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../models/resumen_admin.dart';

/// Gráficas del panel de administración.
///
/// Están dibujadas con `CustomPainter`, sin `fl_chart` ni ningún paquete de
/// gráficas: el proyecto se mantiene con una sola dependencia externa y las
/// animaciones de entrada quedan bajo nuestro control.
///
/// TRAZABILIDAD: reemplazan las dos gráficas de Chart.js de `admin.html`
/// (citas por mes y doctores más populares).

/// Barras verticales de citas por mes, con entrada animada.
class GraficaBarras extends StatefulWidget {
  const GraficaBarras({super.key, required this.meses, this.alto = 190});

  final List<MesCitas> meses;
  final double alto;

  @override
  State<GraficaBarras> createState() => _GraficaBarrasState();
}

class _GraficaBarrasState extends State<GraficaBarras>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.meses.isEmpty) {
      return _SinDatos(alto: widget.alto, mensaje: 'Sin citas registradas.');
    }
    return SizedBox(
      height: widget.alto,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _PintorBarras(
            meses: widget.meses,
            avance: Curves.easeOutCubic.transform(_ctrl.value),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PintorBarras extends CustomPainter {
  _PintorBarras({required this.meses, required this.avance});

  final List<MesCitas> meses;
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    const margenIzq = 30.0;
    const margenAbajo = 26.0;
    const margenArriba = 14.0;

    final maximo = meses.fold<int>(0, (a, m) => math.max(a, m.total));
    // Escala "bonita": el techo sube al siguiente múltiplo de 2, 5 o 10.
    final techo = maximo <= 4 ? 4 : (maximo / 4).ceil() * 4;

    final areaAlto = size.height - margenAbajo - margenArriba;
    final areaAncho = size.width - margenIzq;

    // --------------------------------------------------- rejilla y ejes
    final lapizRejilla = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const textoEje = TextStyle(
      fontFamily: AppTheme.fuente,
      fontSize: 10,
      color: AppColors.textHint,
      fontWeight: FontWeight.w600,
    );

    for (var i = 0; i <= 4; i++) {
      final y = margenArriba + areaAlto * (i / 4);
      canvas.drawLine(
        Offset(margenIzq, y),
        Offset(size.width, y),
        lapizRejilla,
      );
      _texto(
        canvas,
        '${(techo * (4 - i) / 4).round()}',
        Offset(0, y - 6),
        textoEje,
        ancho: margenIzq - 6,
        alinear: TextAlign.right,
      );
    }

    // ------------------------------------------------------------ barras
    final paso = areaAncho / meses.length;
    final anchoBarra = math.min(34.0, paso * 0.52);

    for (var i = 0; i < meses.length; i++) {
      final m = meses[i];
      final centro = margenIzq + paso * (i + 0.5);
      final proporcion = techo == 0 ? 0.0 : m.total / techo;
      final altoBarra = areaAlto * proporcion * avance;
      final esUltimo = i == meses.length - 1;

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centro - anchoBarra / 2,
          margenArriba + areaAlto - altoBarra,
          anchoBarra,
          altoBarra,
        ),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );

      // El mes actual se destaca; los anteriores van en menta.
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: esUltimo
                ? [AppColors.primaryLight, AppColors.primary]
                : [
                    AppColors.primary.withValues(alpha: 0.45),
                    AppColors.primary.withValues(alpha: 0.22),
                  ],
          ).createShader(rect.outerRect),
      );

      // Cifra encima de la barra.
      if (m.total > 0 && avance > 0.6) {
        _texto(
          canvas,
          '${m.total}',
          Offset(centro - 14, margenArriba + areaAlto - altoBarra - 15),
          TextStyle(
            fontFamily: AppTheme.fuente,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: esUltimo ? AppColors.primaryDark : AppColors.textSecondary,
          ),
          ancho: 28,
          alinear: TextAlign.center,
        );
      }

      // Etiqueta del mes.
      _texto(
        canvas,
        m.etiqueta,
        Offset(centro - paso / 2, size.height - margenAbajo + 7),
        TextStyle(
          fontFamily: AppTheme.fuente,
          fontSize: 10.5,
          fontWeight: esUltimo ? FontWeight.w800 : FontWeight.w600,
          color: esUltimo ? AppColors.primaryDark : AppColors.textHint,
        ),
        ancho: paso,
        alinear: TextAlign.center,
      );
    }
  }

  void _texto(
    Canvas canvas,
    String texto,
    Offset posicion,
    TextStyle estilo, {
    required double ancho,
    TextAlign alinear = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textDirection: TextDirection.ltr,
      textAlign: alinear,
    )..layout(maxWidth: ancho);
    tp.paint(canvas, posicion);
  }

  @override
  bool shouldRepaint(_PintorBarras anterior) =>
      anterior.avance != avance || anterior.meses != meses;
}

/// Dona de doctores con más citas, con su leyenda al lado.
class GraficaDona extends StatefulWidget {
  const GraficaDona({super.key, required this.datos, this.diametro = 150});

  final List<DoctorPopular> datos;
  final double diametro;

  @override
  State<GraficaDona> createState() => _GraficaDonaState();
}

class _GraficaDonaState extends State<GraficaDona>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datos.isEmpty) {
      return const _SinDatos(
        alto: 150,
        mensaje: 'Todavía ningún doctor tiene citas.',
      );
    }

    final total = widget.datos.fold<int>(0, (a, d) => a + d.total);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.diametro,
          height: widget.diametro,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              painter: _PintorDona(
                datos: widget.datos,
                total: total,
                avance: Curves.easeOutCubic.transform(_ctrl.value),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in widget.datos.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: d.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${d.total}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PintorDona extends CustomPainter {
  _PintorDona({
    required this.datos,
    required this.total,
    required this.avance,
  });

  final List<DoctorPopular> datos;
  final int total;
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2 - 6;
    final grosor = radio * 0.42;

    var inicio = -math.pi / 2; // arranca arriba
    for (final d in datos) {
      if (total == 0) break;
      final barrido = (d.total / total) * math.pi * 2 * avance;
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio - grosor / 2),
        inicio,
        barrido - 0.02, // separación entre porciones
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.butt
          ..color = d.color,
      );
      inicio += barrido;
    }

    // Total en el centro.
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$total\n',
            style: const TextStyle(
              fontFamily: AppTheme.fuente,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.05,
            ),
          ),
          const TextSpan(
            text: 'citas',
            style: TextStyle(
              fontFamily: AppTheme.fuente,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PintorDona anterior) =>
      anterior.avance != avance || anterior.datos != datos;
}

/// Barra de progreso horizontal con etiqueta, para proporciones simples.
class BarraProporcion extends StatelessWidget {
  const BarraProporcion({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.total,
    required this.color,
  });

  final String etiqueta;
  final int valor;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraccion = total == 0 ? 0.0 : valor / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$valor  ·  ${(fraccion * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // El relleno crece desde 0 al aparecer y se reanima si el valor
          // cambia (por ejemplo al cancelar una cita desde el panel).
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraccion.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, fraccionAnimada, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraccionAnimada,
                minHeight: 8,
                backgroundColor: AppColors.border.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.alto, required this.mensaje});

  final double alto;
  final String mensaje;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: alto,
        child: Center(
          child: Text(
            mensaje,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
