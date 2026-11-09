import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/app_state.dart';

/// Aviso fino que aparece cuando la app trabaja sin el servidor.
///
/// Sirve de trazabilidad visible: el usuario (y el profesor en la demo)
/// ve de inmediato si los datos vienen de la base de datos o del respaldo.
class BannerConexion extends StatelessWidget {
  const BannerConexion({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final aviso = estado.avisoSinConexion;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: aviso == null
          ? const SizedBox(width: double.infinity, height: 12)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.avisoFondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.aviso.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 17, color: AppColors.avisoTexto),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      aviso,
                      style: const TextStyle(
                        fontSize: 12.3,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.avisoTexto,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: estado.refrescar,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      foregroundColor: AppColors.avisoTexto,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Rectangulo gris que late, usado para construir esqueletos de carga.
class Esqueleto extends StatefulWidget {
  const Esqueleto({
    super.key,
    this.ancho = double.infinity,
    this.alto = 14,
    this.radio = 8,
  });

  final double ancho;
  final double alto;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE7EAEF),
            const Color(0xFFF3F5F8),
            _ctrl.value,
          ),
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

/// Lista de tarjetas fantasma con la silueta de una DoctorCard.
class ListaEsqueleto extends StatelessWidget {
  const ListaEsqueleto({super.key, this.filas = 4});

  final int filas;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filas,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Esqueleto(ancho: 54, alto: 54, radio: 27),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Esqueleto(ancho: 150, alto: 13),
                  SizedBox(height: 9),
                  Esqueleto(ancho: 96, alto: 11),
                  SizedBox(height: 9),
                  Esqueleto(ancho: 190, alto: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de error con boton de reintento.
class PanelError extends StatelessWidget {
  const PanelError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
    this.titulo = 'No pudimos cargar la información',
  });

  final String mensaje;
  final String titulo;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.peligro.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 29, color: AppColors.peligro),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
