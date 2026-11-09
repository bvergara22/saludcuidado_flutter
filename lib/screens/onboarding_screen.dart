import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../widgets/arte_animado.dart';
import '../widgets/marca.dart';

/// Introduccion animada de bienvenida (3 pantallas).
///
/// Extension sobre el documento de entregables: el PDF no define esta
/// pantalla. Se agrega para presentar la app antes del login, siguiendo el
/// patron de onboarding de las aplicaciones moviles de referencia.
///
/// Tecnicas de animacion usadas, todas sin paquetes externos:
///   - degradado de fondo interpolado de forma continua entre paginas
///   - parallax: la ilustracion se desplaza a distinta velocidad que el texto
///   - entrada escalonada del titulo y del cuerpo al activarse cada pagina
///   - ilustraciones vectoriales animadas (ver widgets/arte_animado.dart)
///   - indicador de pagina con la pastilla activa alargandose
///   - el boton final cambia de forma y de etiqueta en la ultima pagina
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const String _origen = 'OnboardingScreen';

  static const List<_Pagina> _paginas = [
    _Pagina(
      titulo: 'Encuentra a tu\nespecialista',
      cuerpo:
          'Explora médicos por especialidad, revisa su calificación y su '
          'experiencia antes de decidir.',
      desde: Color(0xFF14499A),
      hasta: Color(0xFF4F8EE8),
      arte: _TipoArte.buscar,
    ),
    _Pagina(
      titulo: 'Reserva tu cita\nen segundos',
      cuerpo:
          'Elige el día y la hora que te sirven. Solo verás los horarios '
          'realmente disponibles.',
      desde: Color(0xFF1E3A8A),
      hasta: Color(0xFF6366F1),
      arte: _TipoArte.reservar,
    ),
    _Pagina(
      titulo: 'Lleva el control\nde tu salud',
      cuerpo:
          'Consulta tus citas próximas, tu historial y tus estadísticas '
          'desde un solo lugar.',
      desde: Color(0xFF0D3573),
      hasta: Color(0xFF2E6FD0),
      arte: _TipoArte.salud,
    ),
  ];

  final PageController _pages = PageController();

  /// Posicion continua (p. ej. 1.37) usada para interpolar fondo y parallax.
  double _posicion = 0;

  /// Indice entero de la pagina activa.
  int _indice = 0;

  /// Controlador de la animacion de entrada de la pagina activa.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// Movimiento continuo para las ilustraciones (orbitas, latido, reloj).
  late final AnimationController _ambiente = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Introducción abierta (3 pantallas)');
    _pages.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    final p = _pages.page ?? 0;
    setState(() => _posicion = p);
    final nuevo = p.round();
    if (nuevo != _indice) {
      _indice = nuevo;
      _entrada
        ..reset()
        ..forward();
      traza.accion(_origen, 'Pantalla ${_indice + 1} de ${_paginas.length}');
    }
  }

  @override
  void dispose() {
    _pages.removeListener(_alDesplazar);
    _pages.dispose();
    _entrada.dispose();
    _ambiente.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- acciones

  void _siguiente() {
    if (_indice < _paginas.length - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
      );
    } else {
      _terminar(omitida: false);
    }
  }

  void _terminar({required bool omitida}) {
    AppStateScope.leer(context).marcarOnboardingVisto();
    final cierre = omitida ? 'omitida' : 'completada';

    // Si la introducción se abrió desde Perfil hay una pantalla debajo:
    // se vuelve a ella. Si viene del splash es la única ruta, así que
    // continúa hacia el login.
    final navegador = Navigator.of(context);
    if (navegador.canPop()) {
      traza.navegacion(_origen, 'Introducción $cierre -> regresa a Perfil');
      navegador.pop();
      return;
    }

    traza.navegacion(
        _origen, 'Introducción $cierre -> ${AppRoutes.login}');
    navegador.pushReplacementNamed(AppRoutes.login);
  }

  // ---------------------------------------------------------------- build

  /// Interpola los dos colores del degradado segun la posicion continua.
  List<Color> get _coloresFondo {
    final i = _posicion.floor().clamp(0, _paginas.length - 1);
    final j = (i + 1).clamp(0, _paginas.length - 1);
    final f = (_posicion - i).clamp(0.0, 1.0);
    return [
      Color.lerp(_paginas[i].desde, _paginas[j].desde, f)!,
      Color.lerp(_paginas[i].hasta, _paginas[j].hasta, f)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colores = _coloresFondo;
    final ultima = _indice == _paginas.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colores,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _barraSuperior(ultima),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _paginas.length,
                  itemBuilder: (context, i) => _contenidoPagina(i),
                ),
              ),
              _controles(ultima),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior(bool ultima) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const MarcaSaludCuidado(
              tamano: 26,
              conFondo: false,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'SaludCuidado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: ultima ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            child: TextButton(
              onPressed: ultima ? null : () => _terminar(omitida: true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.9),
              ),
              child: const Text(
                'Omitir',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenidoPagina(int i) {
    final pagina = _paginas[i];
    // Desplazamiento relativo de esta pagina respecto al centro de la vista.
    final delta = i - _posicion;

    return AnimatedBuilder(
      animation: Listenable.merge([_entrada, _ambiente]),
      builder: (context, _) {
        final activa = i == _indice;
        final t = activa ? _entrada.value : 1.0;

        return Column(
          children: [
            const Spacer(flex: 2),

            // Ilustracion: parallax mas rapido que el texto.
            Transform.translate(
              offset: Offset(delta * -70, 0),
              child: Opacity(
                opacity: (1 - delta.abs() * 0.7).clamp(0.0, 1.0),
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _pintor(pagina.arte, t, _ambiente.value),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Texto: parallax mas lento, con entrada escalonada.
            Transform.translate(
              offset: Offset(delta * -26, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _escalonado(
                      t, 0.10, 0.55,
                      child: Text(
                        pagina.titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _escalonado(
                      t, 0.28, 0.80,
                      child: Text(
                        pagina.cuerpo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 2),
          ],
        );
      },
    );
  }

  /// Aplica desvanecido + desplazamiento vertical dentro de un tramo de [t].
  Widget _escalonado(double t, double inicio, double fin,
      {required Widget child}) {
    final p = tramo(t, inicio, fin, curva: Curves.easeOutCubic);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, (1 - p) * 24), child: child),
    );
  }

  CustomPainter _pintor(_TipoArte tipo, double t, double amb) {
    switch (tipo) {
      case _TipoArte.buscar:
        return ArteBuscar(avance: t, giro: amb * 6.2831853);
      case _TipoArte.reservar:
        return ArteReservar(avance: t, pulso: amb);
      case _TipoArte.salud:
        return ArteSalud(avance: t, pulso: amb);
    }
  }

  Widget _controles(bool ultima) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
      child: Row(
        children: [
          // Indicador: la pastilla activa se alarga.
          Row(
            children: List.generate(_paginas.length, (i) {
              final activo = i == _indice;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 7),
                width: activo ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: activo ? 0.98 : 0.38),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const Spacer(),

          // Boton que se transforma en la ultima pagina.
          AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            width: ultima ? 176 : 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ultima ? 16 : 29),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _siguiente,
                borderRadius: BorderRadius.circular(ultima ? 16 : 29),
                child: Center(
                  child: ultima
                      ? Text(
                          'Comenzar',
                          style: TextStyle(
                            color: _paginas.last.desde,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          color: _paginas[_indice].desde,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TipoArte { buscar, reservar, salud }

class _Pagina {
  final String titulo;
  final String cuerpo;
  final Color desde;
  final Color hasta;
  final _TipoArte arte;

  const _Pagina({
    required this.titulo,
    required this.cuerpo,
    required this.desde,
    required this.hasta,
    required this.arte,
  });
}
