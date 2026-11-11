import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../data/admin_state.dart';
import '../data/app_state.dart';
import '../models/cita.dart';
import '../models/estado_cita.dart';
import '../widgets/avatar_ilustrado.dart';
import '../widgets/estados_ui.dart';
import '../widgets/graficas.dart';
import 'admin_catalogo.dart';

/// Panel de administración.
///
/// TRAZABILIDAD: equivale a `admin.html` + `AdminController.java` del
/// proyecto web, con sus cuatro secciones (tablero, citas, doctores,
/// servicios) más la gestión de usuarios de `UsuarioController.java`.
///
/// CONTRATO:
///   Requiere : sesión iniciada con un usuario que tenga ROLE_ADMIN
///   Garantiza: tablero con estadísticas globales y gráficas; gestión de
///              todas las citas, doctores, servicios y usuarios
///   Falla si : el usuario no es administrador -> pantalla de acceso
///              denegado (el backend además responde 403)
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.mostrarAtras = true});

  /// `false` cuando el panel se muestra como pestaña dentro de `MainShell`:
  /// ahí no hay nada a lo que volver, se sale cambiando de pestaña.
  final bool mostrarAtras;

  static const String ruta = '/admin';

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  static const String _origen = 'AdminScreen';

  late final TabController _tabs = TabController(length: 5, vsync: this);
  AdminState? _admin;

  /// El usuario sí es administrador, pero la app no tiene servidor detrás
  /// (modo demostración): el panel administra datos reales, así que no se
  /// puede abrir con datos de ejemplo.
  bool _sinServidor = false;

  @override
  void initState() {
    super.initState();
    // El AppState aún no está disponible en initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  void _preparar() {
    final estado = AppStateScope.leer(context);
    final repo = estado.repositorio;

    // Dos motivos distintos para no entrar, y conviene no confundirlos: uno
    // es de permisos y el otro de conexión.
    if (!estado.usuarioActual.esAdmin) {
      traza.error(
        _origen,
        'Acceso denegado: ${estado.usuarioActual.email} no es administrador',
        contrato: 'SecurityConfig: /admin/** hasAuthority(ROLE_ADMIN)',
      );
      setState(() {});
      return;
    }

    if (repo == null) {
      traza.error(
        _origen,
        'Panel no disponible: la app corre en modo demostración, sin servidor',
      );
      setState(() => _sinServidor = true);
      return;
    }

    traza.navegacion(_origen, 'Panel abierto por ${estado.usuarioActual.email}',
        contrato: 'AdminController.adminPanel');
    final admin = AdminState(repo);
    setState(() => _admin = admin);
    admin.cargarTodo();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _admin?.dispose();
    super.dispose();
  }

  Future<void> _conAviso(Future<bool> Function() accion) async {
    final admin = _admin!;
    final ok = await accion();
    if (!mounted) return;
    final mensaje = ok ? admin.ultimoAviso : admin.error;
    if (mensaje == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: ok ? AppColors.primaryDark : AppColors.peligro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = AppStateScope.of(context);

    if (!estado.usuarioActual.esAdmin) {
      return _AvisoPanel(
        icono: Icons.lock_outline_rounded,
        color: AppColors.peligro,
        titulo: 'Acceso restringido',
        cuerpo: 'Esta sección es solo para cuentas con rol de administrador. '
            'Inicia sesión con una cuenta autorizada.',
        mostrarAtras: widget.mostrarAtras,
      );
    }

    if (_sinServidor) {
      return _AvisoPanel(
        icono: Icons.cloud_off_rounded,
        color: AppColors.aviso,
        titulo: 'Panel no disponible',
        cuerpo: 'La app está en modo demostración, sin servidor. El panel '
            'administra datos reales, así que necesita la API en marcha.',
        mostrarAtras: widget.mostrarAtras,
      );
    }

    final admin = _admin;
    if (admin == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.mostrarAtras,
          title: const Text('Administración'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: admin,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.mostrarAtras,
          title: const Text('Administración'),
          actions: [
            IconButton(
              tooltip: 'Recargar',
              onPressed: admin.cargando ? null : admin.cargarTodo,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              const Tab(text: 'Tablero'),
              Tab(text: 'Citas (${admin.citas.length})'),
              Tab(text: 'Doctores (${admin.doctores.length})'),
              Tab(text: 'Servicios (${admin.servicios.length})'),
              Tab(text: 'Usuarios (${admin.usuarios.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (admin.cargando) const LinearProgressIndicator(minHeight: 2),
            if (admin.error != null)
              _BarraError(
                mensaje: admin.error!,
                onReintentar: admin.cargarTodo,
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PestanaTablero(admin: admin),
                  _PestanaCitas(admin: admin, onAccion: _conAviso),
                  PestanaDoctores(admin: admin, onAccion: _conAviso),
                  PestanaServicios(admin: admin, onAccion: _conAviso),
                  PestanaUsuarios(
                    admin: admin,
                    onAccion: _conAviso,
                    emailPropio: estado.usuarioActual.email,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CONTRATO "Falla si": sin rol de administrador no se muestra el panel.
/// Equivale al `redirect:/acceso-denegado` del controlador web.
/// Pantalla de aviso del panel: o no tienes el rol, o no hay servidor.
class _AvisoPanel extends StatelessWidget {
  const _AvisoPanel({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.cuerpo,
    required this.mostrarAtras,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String cuerpo;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: mostrarAtras,
          title: const Text('Administración'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, size: 34, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  cuerpo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (mostrarAtras) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _BarraError extends StatelessWidget {
  const _BarraError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.peligro.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: AppColors.peligro),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.avisoRojoTexto,
                ),
              ),
            ),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      );
}

// ============================================================== TABLERO

class _PestanaTablero extends StatelessWidget {
  const _PestanaTablero({required this.admin});

  final AdminState admin;

  @override
  Widget build(BuildContext context) {
    final r = admin.resumen;
    if (r == null) {
      return admin.cargando
          ? const ListaEsqueleto(filas: 3)
          : const Center(child: Text('Sin datos todavía.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // --------------------------------------------- tarjetas de cifras
        Row(
          children: [
            Expanded(
              child: _Cifra(
                valor: r.total,
                etiqueta: 'Citas totales',
                icono: Icons.event_note_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _Cifra(
                valor: r.programadas,
                etiqueta: 'Programadas',
                icono: Icons.schedule_rounded,
                color: AppColors.medicinaGeneral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _Cifra(
                valor: r.completadas,
                etiqueta: 'Completadas',
                icono: Icons.check_circle_outline_rounded,
                color: AppColors.primaryDeep,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _Cifra(
                valor: r.canceladas,
                etiqueta: 'Canceladas',
                icono: Icons.cancel_outlined,
                color: AppColors.peligro,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _Panel(
          titulo: 'Citas por mes',
          subtitulo: 'Últimos 6 meses',
          hijo: GraficaBarras(meses: r.porMes),
        ),

        const SizedBox(height: 14),
        _Panel(
          titulo: 'Doctores con más citas',
          subtitulo: 'Reparto de la carga de trabajo',
          hijo: GraficaDona(datos: r.populares),
        ),

        const SizedBox(height: 14),
        _Panel(
          titulo: 'Estado de las citas',
          subtitulo: 'Proporción sobre el total',
          hijo: Column(
            children: [
              BarraProporcion(
                etiqueta: 'Programadas',
                valor: r.programadas,
                total: r.total,
                color: AppColors.primary,
              ),
              BarraProporcion(
                etiqueta: 'Completadas',
                valor: r.completadas,
                total: r.total,
                color: AppColors.primaryDeep,
              ),
              BarraProporcion(
                etiqueta: 'Canceladas',
                valor: r.canceladas,
                total: r.total,
                color: AppColors.peligro,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _Panel(
          titulo: 'Sistema',
          subtitulo: 'Registros guardados en la base de datos',
          hijo: Column(
            children: [
              _Fila(
                icono: Icons.people_outline_rounded,
                etiqueta: 'Usuarios registrados',
                valor: '${r.usuarios}  (${r.usuariosActivos} activos)',
              ),
              _Fila(
                icono: Icons.medical_services_outlined,
                etiqueta: 'Doctores',
                valor: '${r.doctores}',
              ),
              _Fila(
                icono: Icons.list_alt_rounded,
                etiqueta: 'Servicios',
                valor: '${r.servicios}',
              ),
              _Fila(
                icono: Icons.verified_outlined,
                etiqueta: 'Tasa de cumplimiento',
                valor: '${(r.tasaCumplimiento * 100).round()}%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  final int valor;
  final String etiqueta;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.sombraTarjeta,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 19, color: color),
            ),
            const SizedBox(height: 11),
            // La cifra sube desde 0: deja claro que el dato es real y recién
            // traído del servidor.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: valor.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${v.round()}',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.titulo,
    required this.hijo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radioGrande),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.sombraTarjeta,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            hijo,
          ],
        ),
      );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icono, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                etiqueta,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

// ================================================================ CITAS

class _PestanaCitas extends StatefulWidget {
  const _PestanaCitas({required this.admin, required this.onAccion});

  final AdminState admin;
  final Future<void> Function(Future<bool> Function()) onAccion;

  @override
  State<_PestanaCitas> createState() => _PestanaCitasState();
}

class _PestanaCitasState extends State<_PestanaCitas> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  AdminState get admin => widget.admin;

  static const _rangos = {
    'todas': 'Todas',
    'hoy': 'Hoy',
    'semana': 'Esta semana',
    'mes': 'Este mes',
  };

  static const _estados = {
    'TODAS': 'Todos',
    'PROGRAMADA': 'Programadas',
    'COMPLETADA': 'Completadas',
    'CANCELADA': 'Canceladas',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ------------------------------------------------------ filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _buscar,
            onSubmitted: (v) {
              admin.busqueda = v;
              admin.refiltrarCitas();
            },
            decoration: InputDecoration(
              hintText: 'Buscar por paciente, correo o doctor...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _buscar.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _buscar.clear();
                        admin.busqueda = '';
                        admin.refiltrarCitas();
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final e in _rangos.entries)
                _Chip(
                  texto: e.value,
                  activo: admin.filtroRango == e.key,
                  onTap: () {
                    admin.filtroRango = e.key;
                    admin.refiltrarCitas();
                  },
                ),
              const SizedBox(width: 10),
              Container(width: 1, color: AppColors.border),
              const SizedBox(width: 10),
              for (final e in _estados.entries)
                _Chip(
                  texto: e.value,
                  activo: admin.filtroEstado == e.key,
                  color: e.key == 'TODAS'
                      ? AppColors.primary
                      : EstadoCita.desdeBackend(e.key).color,
                  onTap: () {
                    admin.filtroEstado = e.key;
                    admin.refiltrarCitas();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // -------------------------------------------------------- lista
        Expanded(
          child: admin.citas.isEmpty
              ? _Vacio(
                  icono: Icons.event_busy_outlined,
                  mensaje: admin.cargando
                      ? 'Cargando citas...'
                      : 'Ninguna cita coincide con los filtros.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: admin.citas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TarjetaCitaAdmin(
                    cita: admin.citas[i],
                    onCambiarEstado: (estado) => widget.onAccion(
                      () => admin.cambiarEstadoCita(admin.citas[i].id, estado),
                    ),
                    onEliminar: () => _confirmarEliminar(admin.citas[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmarEliminar(Cita cita) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar la cita?'),
        content: Text(
          'Se borrará definitivamente la cita de ${cita.doctor.nombre} '
          'del ${Fechas.iso(cita.fecha)} a las ${cita.hora}. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.onAccion(() => admin.eliminarCita(cita.id));
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.activo,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: activo ? color : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activo ? color : AppColors.border),
            ),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
}

class _TarjetaCitaAdmin extends StatelessWidget {
  const _TarjetaCitaAdmin({
    required this.cita,
    required this.onCambiarEstado,
    required this.onEliminar,
  });

  final Cita cita;
  final void Function(String estado) onCambiarEstado;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final estado = cita.estado;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarIlustrado(
                semilla: cita.doctor.avatarSemilla,
                tamano: 42,
                color: cita.doctor.color,
                animado: false,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita.doctor.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${Fechas.corto(cita.fecha)} · ${cita.hora} · '
                      '${cita.servicio}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado.etiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: estado.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 9),
          Row(
            children: [
              // De quién es la cita: solo la API de administración lo envía.
              AvatarIlustrado(
                semilla: cita.pacienteSemilla,
                tamano: 24,
                animado: false,
                conBorde: false,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  cita.pacienteNombre ?? 'Paciente desconocido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (estado == EstadoCita.proxima) ...[
                _AccionMini(
                  icono: Icons.check_rounded,
                  etiqueta: 'Completar',
                  color: AppColors.primaryDeep,
                  onTap: () => onCambiarEstado('COMPLETADA'),
                ),
                const SizedBox(width: 6),
                _AccionMini(
                  icono: Icons.block_rounded,
                  etiqueta: 'Cancelar',
                  color: AppColors.aviso,
                  onTap: () => onCambiarEstado('CANCELADA'),
                ),
                const SizedBox(width: 6),
              ],
              _AccionMini(
                icono: Icons.delete_outline_rounded,
                etiqueta: 'Eliminar',
                color: AppColors.peligro,
                onTap: onEliminar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccionMini extends StatelessWidget {
  const _AccionMini({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: etiqueta,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, size: 17, color: color),
          ),
        ),
      );
}

/// Estado vacío reutilizado por las pestañas del panel.
class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 42, color: AppColors.textHint),
              const SizedBox(height: 13),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Expuesto para que `admin_catalogo.dart` reutilice el mismo estado vacío.
class VacioAdmin extends StatelessWidget {
  const VacioAdmin({super.key, required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) =>
      _Vacio(icono: icono, mensaje: mensaje);
}
