import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/doctor.dart';
import '../widgets/doctor_card.dart';
import '../widgets/estados_ui.dart';

/// CONTRATO: DoctoresScreen (PDF 1.2)
///   Requiere : AppState.doctores: List<Doctor> (puede estar vacia)
///   Garantiza: lista filtrable de doctores por especialidad. Al tocar un
///              doctor navega a /reservar con el doctor como argumento
///   Falla si : sin fallo; lista vacia muestra pantalla en blanco
class DoctoresScreen extends StatefulWidget {
  /// Si es false, la pantalla se dibuja dentro del shell (sin boton atras).
  final bool mostrarAtras;

  const DoctoresScreen({super.key, this.mostrarAtras = false});

  @override
  State<DoctoresScreen> createState() => _DoctoresScreenState();
}

class _DoctoresScreenState extends State<DoctoresScreen> {
  static const String _origen = 'DoctoresScreen';

  final TextEditingController _busquedaCtrl = TextEditingController();
  String _especialidad = 'Todas';
  String _texto = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Filtro combinado: especialidad (chips) + texto (buscador).
  /// El catálogo lo trae el AppState desde GET /api/doctores.
  List<Doctor> _filtrados(AppState estado) => estado.filtrarDoctores(
        especialidad: _especialidad,
        texto: _texto,
      );

  void _seleccionarEspecialidad(String especialidad) {
    setState(() => _especialidad = especialidad);
    traza.accion(_origen, 'Filtro por especialidad: $especialidad');
  }

  /// CONTRATO: al tocar un doctor navega a /reservar con el doctor
  /// como argumento.
  void _abrirReserva(Doctor doctor) {
    traza.navegacion(
      _origen,
      'Doctor ${doctor.nombre} -> ${AppRoutes.reservar} (argumento Doctor)',
      contrato: 'DoctoresScreen.Garantiza',
    );
    Navigator.of(context).pushNamed(AppRoutes.reservar, arguments: doctor);
  }

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);
    final doctores = _filtrados(estado);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctores'),
        automaticallyImplyLeading: widget.mostrarAtras,
        leading: widget.mostrarAtras
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buscador(),
          ),
        ),
      ),
      body: Column(
        children: [
          BannerConexion(estado: estado),
          const SizedBox(height: 12),
          _chipsEspecialidad(estado),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: estado.refrescar,
              child: estado.cargando && doctores.isEmpty
                  ? const ListaEsqueleto(filas: 5)
                  : doctores.isEmpty
                      ? _sinResultados()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: doctores.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => DoctorCard(
                            doctor: doctores[i],
                            onTap: () => _abrirReserva(doctores[i]),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buscador() {
    return TextField(
      controller: _busquedaCtrl,
      onChanged: (v) => setState(() => _texto = v),
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Buscar médico o especialidad...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 14,
        ),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Colors.white, size: 21),
        suffixIcon: _texto.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 19),
                onPressed: () {
                  _busquedaCtrl.clear();
                  setState(() => _texto = '');
                },
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.18),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _chipsEspecialidad(AppState estado) {
    final lista = estado.especialidadesDisponibles;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = lista[i];
          final activo = e == _especialidad;
          return GestureDetector(
            onTap: () => _seleccionarEspecialidad(e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                e,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sinResultados() {
    // ListView (y no Center) para que el gesto de recarga siga funcionando
    // aunque no haya resultados.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 46, color: AppColors.textHint),
              const SizedBox(height: 14),
              const Text(
                'Sin resultados',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _especialidad == 'Todas'
                    ? 'No encontramos doctores que coincidan con tu búsqueda.'
                    : 'No hay doctores de $_especialidad disponibles.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
