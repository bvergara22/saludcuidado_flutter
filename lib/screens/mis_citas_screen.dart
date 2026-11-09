import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/cita.dart';
import '../models/estado_cita.dart';
import '../widgets/cita_card.dart';
import '../widgets/estados_ui.dart';

/// CONTRATO: MisCitasScreen (PDF 1.2)
///   Requiere : sampleCitas: List<Cita> (puede estar vacia)
///   Garantiza: TabBar con 3 pestanas (Proximas, Completadas, Canceladas)
///              filtrando citas por EstadoCita. El FAB navega a /reservar
///   Falla si : sin fallo; pestana vacia muestra mensaje informativo
class MisCitasScreen extends StatefulWidget {
  final bool mostrarAtras;

  const MisCitasScreen({super.key, this.mostrarAtras = false});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen>
    with SingleTickerProviderStateMixin {
  static const String _origen = 'MisCitasScreen';

  /// Las 3 pestanas corresponden exactamente a los valores de EstadoCita.
  static const List<EstadoCita> pestanas = [
    EstadoCita.proxima,
    EstadoCita.completada,
    EstadoCita.cancelada,
  ];

  late final TabController _tabs =
      TabController(length: pestanas.length, vsync: this)
        ..addListener(_alCambiarPestana);

  void _alCambiarPestana() {
    if (_tabs.indexIsChanging) return;
    traza.accion(
      _origen,
      'Pestaña activa: ${pestanas[_tabs.index].etiquetaPlural}',
      contrato: 'MisCitasScreen.Garantiza (filtrado por EstadoCita)',
    );
  }

  @override
  void dispose() {
    _tabs.removeListener(_alCambiarPestana);
    _tabs.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- acciones

  void _irAReservar() {
    traza.navegacion(_origen, 'FAB -> ${AppRoutes.reservar}',
        contrato: 'MisCitasScreen.Garantiza (FAB navega a /reservar)');
    Navigator.of(context).pushNamed(AppRoutes.reservar);
  }

  Future<void> _confirmarCancelacion(Cita cita) async {
    traza.accion(_origen, 'Solicitud de cancelacion de ${cita.id}');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radio),
        ),
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Seguro que deseas cancelar tu cita con ${cita.doctor.nombre}?\n\n'
          'Esta acción no se puede deshacer.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) {
      traza.accion(_origen, 'Cancelación descartada por el usuario');
      return;
    }

    final estado = AppStateScope.leer(context);
    final ok = await estado.cancelarCita(cita.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Cita cancelada correctamente'
            : estado.mensajeError ?? 'No fue posible cancelar la cita'),
        backgroundColor: ok ? AppColors.textPrimary : AppColors.peligro,
      ),
    );

    if (ok) _tabs.animateTo(2);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
        automaticallyImplyLeading: widget.mostrarAtras,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13.5),
          tabs: [
            for (final p in pestanas)
              Tab(text: '${p.etiquetaPlural} (${estado.porEstado(p).length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          BannerConexion(estado: estado),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final p in pestanas)
                  RefreshIndicator(
                    // Vuelve a pedir las citas a la base de datos.
                    onRefresh: estado.cargarCitas,
                    child: estado.cargando && estado.citas.isEmpty
                        ? const ListaEsqueleto(filas: 4)
                        : _ListaCitas(
                            citas: estado.porEstado(p),
                            estado: p,
                            onCancelar: p == EstadoCita.proxima
                                ? _confirmarCancelacion
                                : null,
                            onReservar: _irAReservar,
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAReservar,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva cita',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ListaCitas extends StatelessWidget {
  final List<Cita> citas;
  final EstadoCita estado;
  final void Function(Cita)? onCancelar;
  final VoidCallback onReservar;

  const _ListaCitas({
    required this.citas,
    required this.estado,
    required this.onCancelar,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    // CONTRATO "Falla si": pestana vacia muestra mensaje informativo.
    if (citas.isEmpty) {
      // ListView para que el gesto de recarga funcione con la lista vacía.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(estado.icono, size: 32, color: estado.color),
              ),
              const SizedBox(height: 16),
              Text(
                estado.mensajeVacio,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
                if (estado == EstadoCita.proxima) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: onReservar,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Reservar cita'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: citas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, i) => CitaCard(
        cita: citas[i],
        onCancelar:
            onCancelar == null ? null : () => onCancelar!(citas[i]),
      ),
    );
  }
}
