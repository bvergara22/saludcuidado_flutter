import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../models/cita.dart';

/// Hoja para mover una cita a otra fecha y hora.
///
/// CONTRATO: mostrarHojaReprogramar
///   Requiere : una cita del usuario que no esté completada
///   Garantiza: devuelve true solo si el servidor confirmó el cambio
///   Falla si : el hueco se ocupó mientras se elegía -> se muestra el
///              mensaje del servidor y la hoja sigue abierta para elegir
///              otro, en lugar de cerrarse y perder el trabajo
///
/// Reutiliza la misma fuente de horarios que la reserva
/// ([AppState.horariosDisponibles]), así que lo que se ofrece aquí es lo
/// que el backend considera libre, no una copia de la regla.
Future<bool> mostrarHojaReprogramar(BuildContext context, Cita cita) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HojaReprogramar(cita: cita),
  );
  return resultado ?? false;
}

class _HojaReprogramar extends StatefulWidget {
  const _HojaReprogramar({required this.cita});

  final Cita cita;

  @override
  State<_HojaReprogramar> createState() => _HojaReprogramarState();
}

class _HojaReprogramarState extends State<_HojaReprogramar> {
  static const String _origen = 'ReprogramarHoja';

  /// Mismos 14 días que ofrece la pantalla de reserva.
  static const int _dias = 14;

  late DateTime _fecha;
  String? _hora;
  List<String> _horarios = const [];
  bool _cargandoHorarios = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Se arranca en mañana, no en el día de la cita: si la cita ya venció,
    // su propia fecha no es una opción válida.
    final hoy = DateTime.now();
    _fecha = DateTime(hoy.year, hoy.month, hoy.day + 1);
    traza.navegacion(_origen, 'Hoja de reprogramación de ${widget.cita.id}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarHorarios());
  }

  Future<void> _cargarHorarios() async {
    setState(() {
      _cargandoHorarios = true;
      _hora = null;
    });
    final estado = AppStateScope.leer(context);
    final libres =
        await estado.horariosDisponibles(widget.cita.doctor, _fecha);
    if (!mounted) return;
    setState(() {
      _horarios = libres;
      _cargandoHorarios = false;
    });
  }

  Future<void> _confirmar() async {
    final hora = _hora;
    if (hora == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final estado = AppStateScope.leer(context);
    final ok = await estado.reprogramarCita(
      widget.cita.id,
      fecha: _fecha,
      hora: hora,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    // El hueco pudo ocuparse mientras se elegía: se recarga la rejilla
    // para que lo que se ve vuelva a ser cierto.
    setState(() {
      _guardando = false;
      _error = estado.mensajeError ?? 'No se pudo mover la cita.';
    });
    await _cargarHorarios();
  }

  @override
  Widget build(BuildContext context) {
    final cita = widget.cita;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reprogramar cita',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${cita.doctor.nombre} · ${cita.doctor.especialidad}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ahora: ${Fechas.conDia(cita.fecha)} a las '
                    '${Fechas.hora12(cita.hora)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const _Rotulo('Nueva fecha'),
                  const SizedBox(height: 8),
                  SizedBox(height: 78, child: _tiraFechas()),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const _Rotulo('Horarios disponibles'),
                      const Spacer(),
                      if (!_cargandoHorarios)
                        Text(
                          '${_horarios.length} libres',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_cargandoHorarios)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_horarios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        'No queda ningún horario libre ese día.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in _horarios) _chipHora(h),
                      ],
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.peligro.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radio),
                        border: Border.all(
                          color: AppColors.peligro.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 18, color: AppColors.peligro),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.peligro,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _guardando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            _hora == null || _guardando ? null : _confirmar,
                        child: _guardando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Mover la cita'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiraFechas() {
    final hoy = DateTime.now();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _dias,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        // Desde mañana: hoy ya no cabe entero y evita medias tintas.
        final f = DateTime(hoy.year, hoy.month, hoy.day + 1 + i);
        final elegida = f.year == _fecha.year &&
            f.month == _fecha.month &&
            f.day == _fecha.day;
        return InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radio),
          onTap: () {
            setState(() => _fecha = f);
            _cargarHorarios();
          },
          child: Container(
            width: 62,
            decoration: BoxDecoration(
              color: elegida ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radio),
              border: Border.all(
                color: elegida ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fechas.diaCorto(f),
                  style: TextStyle(
                    fontSize: 11,
                    color: elegida ? Colors.white70 : AppColors.textHint,
                  ),
                ),
                Text(
                  '${f.day}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: elegida ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  Fechas.mesCorto(f),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: elegida ? Colors.white70 : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipHora(String h) {
    final elegida = _hora == h;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radio),
      onTap: () => setState(() => _hora = h),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: elegida ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(
            color: elegida ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          Fechas.hora12(h),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: elegida ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      );
}
