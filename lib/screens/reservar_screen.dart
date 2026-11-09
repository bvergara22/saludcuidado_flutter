import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/app_state.dart';
import '../data/horarios_service.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../widgets/doctor_card.dart';

/// CONTRATO: ReservarScreen (PDF 1.2)
///   Requiere : arguments: Doctor? (opcional, pre-selecciona doctor)
///   Garantiza: flujo de 3 pasos: seleccion de doctor, seleccion de
///              fecha/hora, confirmacion. Al confirmar muestra dialogo y
///              navega a /mis-citas
///   Falla si : si se intenta avanzar sin seleccionar doctor o sin
///              seleccionar horario -> boton deshabilitado
class ReservarScreen extends StatefulWidget {
  /// Doctor preseleccionado (llega como argumento de la ruta).
  final Doctor? doctorInicial;

  const ReservarScreen({super.key, this.doctorInicial});

  @override
  State<ReservarScreen> createState() => _ReservarScreenState();
}

class _ReservarScreenState extends State<ReservarScreen> {
  static const String _origen = 'ReservarScreen';
  static const List<String> _titulosPaso = [
    'Selecciona el doctor',
    'Elige fecha y hora',
    'Confirma tu cita',
  ];

  int _paso = 0;
  Doctor? _doctor;
  DateTime? _fecha;
  String? _hora;
  bool _confirmando = false;

  /// Horarios que devolvió el backend para el doctor y la fecha actuales.
  List<String>? _horariosServidor;
  bool _cargandoHorarios = false;

  late final List<DateTime> _dias = HorariosService.diasSeleccionables();

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctorInicial;

    if (_doctor != null) {
      // Con doctor preseleccionado se abre directamente en el paso 2.
      _paso = 1;
      _fecha = _dias.first;
      traza.navegacion(
        _origen,
        'Abierto con doctor preseleccionado: ${_doctor!.nombre} '
        '-> inicia en paso 2',
        contrato: 'ReservarScreen.Requiere (arguments: Doctor?)',
      );
      // El contexto aún no está listo en initState: se pide tras el primer
      // fotograma para poder leer el AppState.
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargarHorarios());
    } else {
      traza.navegacion(_origen, 'Abierto sin doctor -> inicia en paso 1');
    }
  }

  // ------------------------------------------------- reglas de habilitacion

  /// CONTRATO "Falla si": sin doctor o sin horario, el boton se deshabilita.
  bool get _puedeAvanzar {
    switch (_paso) {
      case 0:
        return _doctor != null;
      case 1:
        return _fecha != null && _hora != null;
      case 2:
        return !_confirmando;
      default:
        return false;
    }
  }

  /// Horarios mostrados en el paso 2.
  ///
  /// Si el servidor ya respondio se usan sus horarios (misma regla que
  /// CitaService.java, pero contra la base de datos real); mientras llegan,
  /// o si no hay servidor, se calculan en el dispositivo.
  List<String> get _horariosDisponibles {
    if (_doctor == null || _fecha == null) return const [];
    final servidor = _horariosServidor;
    if (servidor != null) return servidor;
    return HorariosService.disponibles(
      doctor: _doctor!,
      fecha: _fecha!,
      citasExistentes: AppStateScope.of(context).citas,
    );
  }

  /// Pide al backend los horarios libres del doctor y la fecha actuales.
  Future<void> _cargarHorarios() async {
    final doctor = _doctor;
    final fecha = _fecha;
    if (doctor == null || fecha == null) return;

    setState(() {
      _cargandoHorarios = true;
      _horariosServidor = null;
    });

    final estado = AppStateScope.leer(context);
    final lista = await estado.horariosDisponibles(doctor, fecha);
    if (!mounted) return;

    // Una respuesta vieja no debe sobreescribir la selección actual.
    if (_doctor?.id != doctor.id || _fecha != fecha) return;
    setState(() {
      _horariosServidor = lista;
      _cargandoHorarios = false;
      if (_hora != null && !lista.contains(_hora)) _hora = null;
    });
  }

  // ------------------------------------------------------------- acciones

  void _seleccionarDoctor(Doctor d) {
    setState(() {
      _doctor = d;
      _hora = null;
      _fecha ??= _dias.first;
    });
    traza.accion(_origen, 'Paso 1: doctor seleccionado ${d.nombre}');
    _cargarHorarios();
  }

  void _seleccionarFecha(DateTime f) {
    setState(() {
      _fecha = f;
      // Al cambiar de dia la hora previa deja de ser valida.
      _hora = null;
    });
    traza.accion(_origen, 'Paso 2: fecha seleccionada ${Fechas.iso(f)}');
    _cargarHorarios();
  }

  void _seleccionarHora(String h) {
    setState(() => _hora = h);
    traza.accion(_origen, 'Paso 2: hora seleccionada $h');
  }

  void _siguiente() {
    if (!_puedeAvanzar) {
      traza.validacion(
        _origen,
        'Intento de avanzar bloqueado en paso ${_paso + 1}',
        contrato: 'ReservarScreen.Falla si (botón deshabilitado)',
      );
      return;
    }
    if (_paso < 2) {
      setState(() => _paso++);
      traza.navegacion(_origen, 'Avanza a paso ${_paso + 1}: '
          '${_titulosPaso[_paso]}');
    } else {
      _confirmar();
    }
  }

  void _atras() {
    if (_paso == 0) {
      traza.navegacion(_origen, 'Salir de la reserva');
      Navigator.of(context).pop();
      return;
    }
    setState(() => _paso--);
    traza.navegacion(_origen, 'Vuelve a paso ${_paso + 1}');
  }

  Future<void> _confirmar() async {
    setState(() => _confirmando = true);
    traza.accion(_origen, 'Paso 3: confirmando reserva...');

    final estado = AppStateScope.leer(context);
    // Guarda la cita en la base de datos (POST /api/citas). El índice único
    // parcial del backend es el que impide definitivamente la doble reserva.
    final cita = await estado.reservarCita(
      doctor: _doctor!,
      fecha: _fecha!,
      hora: _hora!,
      servicio: _doctor!.especialidad,
    );

    if (!mounted) return;

    if (cita == null) {
      // El horario fue tomado entre la seleccion y la confirmacion.
      final motivo = estado.mensajeError ??
          'La hora seleccionada ya no está disponible. Elige otra.';
      setState(() {
        _confirmando = false;
        _hora = null;
        _paso = 1;
      });
      _cargarHorarios();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(motivo),
          backgroundColor: AppColors.peligro,
        ),
      );
      return;
    }

    await _mostrarDialogoExito(cita);
    if (!mounted) return;

    // CONTRATO: al confirmar muestra dialogo y navega a /mis-citas.
    traza.navegacion(_origen, 'Reserva confirmada -> ${AppRoutes.misCitas}',
        contrato: 'ReservarScreen.Garantiza');
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.misCitas,
      (ruta) => ruta.isFirst,
    );
  }

  Future<void> _mostrarDialogoExito(Cita cita) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radioGrande),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.exito.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.exito, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cita confirmada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu cita con ${cita.doctor.nombre} quedó agendada para el '
              '${Fechas.conDia(cita.fecha)} a las ${Fechas.hora12(cita.hora)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ver mis citas'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar cita'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _atras,
        ),
      ),
      body: Column(
        children: [
          _indicadorPasos(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey<int>(_paso),
                child: _contenidoPaso(),
              ),
            ),
          ),
          _barraInferior(),
        ],
      ),
    );
  }

  Widget _indicadorPasos() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Row(
            children: List.generate(5, (i) {
              // Indices pares = circulos de paso; impares = conectores.
              if (i.isOdd) {
                final completado = _paso > i ~/ 2;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: completado
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final indice = i ~/ 2;
              final activo = indice <= _paso;
              final completado = indice < _paso;
              return Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppColors.primary : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activo ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: completado
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Text(
                        '${indice + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: activo
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Paso ${_paso + 1} de 3 - ${_titulosPaso[_paso]}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenidoPaso() {
    switch (_paso) {
      case 0:
        return _pasoDoctor();
      case 1:
        return _pasoFechaHora();
      default:
        return _pasoConfirmacion();
    }
  }

  // ------------------------------------------------------------- paso 1

  Widget _pasoDoctor() {
    // Catálogo cargado del backend (con respaldo local si no hay servidor).
    final doctores = AppStateScope.of(context).doctores;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: doctores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = doctores[i];
        final seleccionado = _doctor?.id == d.id;
        return Stack(
          children: [
            DoctorCard(doctor: d, onTap: () => _seleccionarDoctor(d)),
            if (seleccionado)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radio),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------- paso 2

  Widget _pasoFechaHora() {
    final horarios = _horariosDisponibles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        if (_doctor != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radio),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                DoctorAvatar(doctor: _doctor!, tamano: 40),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctor!.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _doctor!.especialidad,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _doctor!.color,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _paso = 0),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Fecha',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              final d = _dias[i];
              final activo =
                  _fecha != null && Fechas.mismoDia(d, _fecha!);
              return GestureDetector(
                onTap: () => _seleccionarFecha(d),
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: activo ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activo ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Fechas.diaCorto(d),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: activo
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: activo
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        Fechas.mesCorto(d),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: activo
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'Horarios disponibles',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_cargandoHorarios)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Consultando...',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            else
              Text(
                '${horarios.length} libres',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (horarios.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radio),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_outlined,
                    size: 34, color: AppColors.textHint),
                SizedBox(height: 10),
                Text(
                  'No hay horarios disponibles para este día.\n'
                  'Selecciona otra fecha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final h in horarios)
                GestureDetector(
                  onTap: () => _seleccionarHora(h),
                  child: Container(
                    width: 86,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hora == h
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hora == h
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      Fechas.hora12(h),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _hora == h
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ------------------------------------------------------------- paso 3

  Widget _pasoConfirmacion() {
    final d = _doctor!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radioGrande),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.sombraTarjeta,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  DoctorAvatar(doctor: d, tamano: 52),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.especialidad,
                          style: TextStyle(fontSize: 13, color: d.color),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: AppColors.estrella),
                            const SizedBox(width: 3),
                            Text(
                              '${d.rating.toStringAsFixed(1)} - '
                              '${d.experienciaTexto}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _filaResumen(Icons.calendar_today_outlined, 'Fecha',
                  Fechas.conDia(_fecha!)),
              const SizedBox(height: 12),
              _filaResumen(Icons.access_time_rounded, 'Hora',
                  Fechas.hora12(_hora!)),
              const SizedBox(height: 12),
              _filaResumen(
                  Icons.location_on_outlined, 'Lugar', d.clinica),
              const SizedBox(height: 12),
              _filaResumen(Icons.medical_services_outlined, 'Servicio',
                  d.especialidad),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppTheme.radio),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 19, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Llega 15 minutos antes de tu cita y trae tu documento de '
                  'identidad. Puedes cancelar desde Mis Citas.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radio),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sobre el especialista',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                d.descripcion,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaResumen(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 17, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 68,
          child: Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- barra inferior

  Widget _barraInferior() {
    final etiqueta = _paso == 2 ? 'Confirmar cita' : 'Continuar';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_paso > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirmando ? null : _atras,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radio),
                    ),
                  ),
                  child: const Text(
                    'Atrás',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
            ],
            Expanded(
              flex: _paso > 0 ? 2 : 1,
              // CONTRATO: boton deshabilitado si falta doctor u horario.
              child: ElevatedButton(
                onPressed: _puedeAvanzar ? _siguiente : null,
                child: _confirmando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(etiqueta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
