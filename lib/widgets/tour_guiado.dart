import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';

/// Puntos de la interfaz que el recorrido guiado puede iluminar.
///
/// Son `GlobalKey` porque el recorrido necesita saber **dónde está de
/// verdad** cada elemento en pantalla, no dónde debería estar: las
/// posiciones cambian con el tamaño del teléfono, con la barra de estado y
/// con el rol (un administrador tiene una pestaña más). Preguntándoselo al
/// propio widget, el foco siempre cae donde toca.
///
/// Un ancla sin montar devuelve null y su paso se muestra centrado, sin
/// foco, en lugar de iluminar una zona equivocada.
class AnclasTour {
  AnclasTour._();

  static final GlobalKey asistente = GlobalKey(debugLabel: 'tour.asistente');
  static final GlobalKey doctores = GlobalKey(debugLabel: 'tour.doctores');
  static final GlobalKey misCitas = GlobalKey(debugLabel: 'tour.misCitas');
  static final GlobalKey perfil = GlobalKey(debugLabel: 'tour.perfil');

  /// Rectángulo que ocupa el widget de [llave] en la pantalla.
  static Rect? rect(GlobalKey? llave) {
    final contexto = llave?.currentContext;
    if (contexto == null) return null;
    final objeto = contexto.findRenderObject();
    if (objeto is! RenderBox || !objeto.hasSize) return null;
    return objeto.localToGlobal(Offset.zero) & objeto.size;
  }
}

/// Un paso del recorrido.
@immutable
class PasoTour {
  final String titulo;
  final String cuerpo;
  final IconData icono;

  /// Elemento a iluminar. Si es null, el paso se muestra centrado: sirve
  /// para la bienvenida y la despedida.
  final GlobalKey? ancla;

  /// Cuánto se agranda el foco respecto al elemento, para que no quede
  /// pegado al borde.
  final double margen;

  const PasoTour({
    required this.titulo,
    required this.cuerpo,
    required this.icono,
    this.ancla,
    this.margen = 10,
  });
}

/// CONTRATO: mostrarTour
///   Requiere : una lista de pasos no vacía y un contexto con Navigator
///   Garantiza: devuelve true si el usuario llegó al final, y false si lo
///              saltó o lo cerró; en ambos casos no vuelve a aparecer solo
///   Falla si : un ancla no está montada -> ese paso sale centrado, sin
///              foco, en lugar de iluminar una zona arbitraria
Future<bool> mostrarTour(BuildContext context, List<PasoTour> pasos) async {
  if (pasos.isEmpty) return false;
  final completado = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      // El fondo tiene que seguir visible: el recorrido explica la propia
      // interfaz, así que taparla lo dejaría sin sentido.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animacion, __) => FadeTransition(
        opacity: animacion,
        child: _Tour(pasos: pasos),
      ),
    ),
  );
  return completado ?? false;
}

class _Tour extends StatefulWidget {
  const _Tour({required this.pasos});

  final List<PasoTour> pasos;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> with SingleTickerProviderStateMixin {
  static const String _origen = 'TourGuiado';

  int _paso = 0;

  /// Anima el desplazamiento del foco de un elemento al siguiente.
  late final AnimationController _mover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..value = 1;

  Rect? _focoPrevio;

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Recorrido guiado iniciado',
        contrato: 'mostrarTour');
  }

  @override
  void dispose() {
    _mover.dispose();
    super.dispose();
  }

  void _avanzar() {
    if (_paso >= widget.pasos.length - 1) {
      traza.accion(_origen, 'Recorrido completado');
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _focoPrevio = AnclasTour.rect(widget.pasos[_paso].ancla);
      _paso++;
    });
    _mover.forward(from: 0);
    traza.accion(_origen, 'Paso ${_paso + 1}/${widget.pasos.length}');
  }

  void _retroceder() {
    if (_paso == 0) return;
    setState(() {
      _focoPrevio = AnclasTour.rect(widget.pasos[_paso].ancla);
      _paso--;
    });
    _mover.forward(from: 0);
  }

  void _saltar() {
    traza.accion(_origen, 'Recorrido saltado en el paso ${_paso + 1}');
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final paso = widget.pasos[_paso];
    final pantalla = MediaQuery.sizeOf(context);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _mover,
        builder: (context, _) {
          final destino = _ampliar(
            AnclasTour.rect(paso.ancla),
            paso.margen,
            pantalla,
          );
          // Durante la transición el agujero viaja desde el anterior.
          final foco = destino == null || _focoPrevio == null
              ? destino
              : Rect.lerp(
                  _ampliar(_focoPrevio, paso.margen, pantalla),
                  destino,
                  Curves.easeInOutCubic.transform(_mover.value),
                );

          return Stack(
            children: [
              // Capa oscura con el agujero. Absorbe los toques para que
              // nadie pulse algo por debajo sin querer.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _avanzar,
                  child: CustomPaint(
                    painter: _PintorFoco(foco: foco),
                  ),
                ),
              ),
              if (foco != null) _anillo(foco),
              _tarjeta(paso, foco, pantalla),
            ],
          );
        },
      ),
    );
  }

  static Rect? _ampliar(Rect? r, double margen, Size pantalla) {
    if (r == null) return null;
    final crecido = r.inflate(margen);
    // Un ancla puede quedar parcialmente fuera si la pantalla es pequeña.
    return crecido.intersect(Offset.zero & pantalla);
  }

  Widget _anillo(Rect foco) {
    return Positioned(
      left: foco.left,
      top: foco.top,
      width: foco.width,
      height: foco.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(PasoTour paso, Rect? foco, Size pantalla) {
    const alturaAprox = 214.0;
    const margen = 20.0;

    // La tarjeta se coloca donde quepa sin tapar lo que está explicando.
    double arriba;
    if (foco == null) {
      arriba = (pantalla.height - alturaAprox) / 2;
    } else if (foco.bottom + alturaAprox + margen < pantalla.height) {
      arriba = foco.bottom + margen;
    } else {
      arriba = foco.top - alturaAprox - margen;
    }
    arriba = arriba.clamp(margen + 24, pantalla.height - alturaAprox - margen);

    final ultimo = _paso == widget.pasos.length - 1;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: margen,
      right: margen,
      top: arriba,
      child: TweenAnimationBuilder<double>(
        // Clave distinta por paso: reinicia la animación de entrada.
        key: ValueKey(_paso),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, hijo) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: hijo),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(paso.icono,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      paso.titulo,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${_paso + 1}/${widget.pasos.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                paso.cuerpo,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  // Barra de avance: dice cuánto falta de un vistazo.
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.pasos.length; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              margin: const EdgeInsets.only(right: 4),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _paso
                                    ? AppColors.primary
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_paso > 0)
                    TextButton(
                      onPressed: _retroceder,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Atrás',
                          style: TextStyle(fontSize: 13)),
                    ),
                  if (!ultimo)
                    TextButton(
                      onPressed: _saltar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Saltar',
                          style: TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _avanzar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      ultimo ? 'Entendido' : 'Siguiente',
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oscurece la pantalla dejando un hueco redondeado sobre el elemento.
class _PintorFoco extends CustomPainter {
  _PintorFoco({required this.foco});

  final Rect? foco;

  @override
  void paint(Canvas canvas, Size size) {
    final sombra = Paint()..color = const Color(0xFF0B1220).withValues(alpha: 0.74);
    final todo = Offset.zero & size;

    if (foco == null) {
      canvas.drawRect(todo, sombra);
      return;
    }

    // El hueco se obtiene restando el rectángulo redondeado a la pantalla.
    final hueco = Path()
      ..addRRect(RRect.fromRectAndRadius(foco!, const Radius.circular(16)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(todo), hueco),
      sombra,
    );
  }

  @override
  bool shouldRepaint(_PintorFoco old) => old.foco != foco;
}
