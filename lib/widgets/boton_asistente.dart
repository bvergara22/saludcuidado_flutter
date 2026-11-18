import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../screens/chat_screen.dart';
import 'avatar_asistente.dart';

/// Botón flotante que abre el asistente.
///
/// Lleva la cara de [Asistente] en lugar de un icono genérico: así se
/// reconoce de un vistazo y es coherente con la cabecera del chat y con
/// cada respuesta suya dentro de la conversación.
///
/// La primera vez muestra el nombre al lado durante unos segundos y luego
/// se encoge a un círculo. Un botón sin etiqueta no dice qué hace; uno
/// permanentemente extendido ocupa sitio en todas las pantallas.
class BotonAsistente extends StatefulWidget {
  const BotonAsistente({super.key});

  @override
  State<BotonAsistente> createState() => _BotonAsistenteState();
}

class _BotonAsistenteState extends State<BotonAsistente> {
  /// Se encoge pasado este tiempo desde que aparece.
  static const Duration _espera = Duration(seconds: 4);

  bool _extendido = true;

  /// Se guarda para poder cancelarlo: un `Future.delayed` suelto sigue
  /// vivo aunque el widget desaparezca, y deja el temporizador pendiente.
  Timer? _encoger;

  @override
  void initState() {
    super.initState();
    _encoger = Timer(_espera, () {
      if (mounted) setState(() => _extendido = false);
    });
  }

  @override
  void dispose() {
    _encoger?.cancel();
    super.dispose();
  }

  void _abrir() {
    traza.navegacion(
      'BotonAsistente',
      'Abrir ${AppRoutes.asistente}',
      contrato: 'ChatScreen',
    );
    Navigator.of(context).pushNamed(AppRoutes.asistente);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      height: 58,
      width: _extendido ? 150 : 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(29),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrir,
          borderRadius: BorderRadius.circular(29),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 7),
              const AvatarAsistente(tamano: 44, fondo: Color(0xFF0D3573)),
              // El nombre se desvanece antes de que el botón se encoja,
              // para que no se vea el texto recortándose.
              Flexible(
                child: AnimatedOpacity(
                  opacity: _extendido ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 9, right: 14),
                    child: Text(
                      Asistente.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
