import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/admin_state.dart';
import '../data/api/repositorio.dart';
import '../models/doctor.dart';
import '../models/servicio.dart';
import '../models/usuario_admin.dart';
import '../widgets/avatar_ilustrado.dart';
import 'admin_screen.dart';

/// Pestañas de catálogo del panel de administración: doctores, servicios y
/// usuarios, con sus formularios de creación y edición.
///
/// TRAZABILIDAD: `AdminController` (CRUD de doctores y servicios) y
/// `UsuarioController` (activar/desactivar y roles) del proyecto web.

typedef EjecutarAccion = Future<void> Function(Future<bool> Function());

// ============================================================= DOCTORES

class PestanaDoctores extends StatelessWidget {
  const PestanaDoctores({
    super.key,
    required this.admin,
    required this.onAccion,
  });

  final AdminState admin;
  final EjecutarAccion onAccion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo doctor',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: admin.doctores.isEmpty
          ? const VacioAdmin(
              icono: Icons.medical_services_outlined,
              mensaje: 'Todavía no hay doctores registrados.\n'
                  'Crea el primero con el botón de abajo.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: admin.doctores.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = admin.doctores[i];
                return _TarjetaGestion(
                  avatar: AvatarIlustrado(
                    semilla: d.avatarSemilla,
                    tamano: 46,
                    color: d.color,
                    animado: false,
                  ),
                  titulo: d.nombre,
                  subtitulo: '${d.especialidad} · ${d.experienciaTexto}',
                  detalle: d.clinica.isEmpty ? null : d.clinica,
                  etiqueta: '${d.horariosDisponibles.length} horarios',
                  colorEtiqueta: d.color,
                  onEditar: () => _abrirFormulario(context, d),
                  onEliminar: () => _confirmarEliminar(context, d),
                );
              },
            ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Doctor? doctor) async {
    final datos = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormularioDoctor(doctor: doctor),
    );
    if (datos == null) return;
    await onAccion(() => doctor == null
        ? admin.crearDoctor(datos)
        : admin.actualizarDoctor(doctor.id, datos));
  }

  Future<void> _confirmarEliminar(BuildContext context, Doctor d) async {
    final ok = await _confirmar(
      context,
      titulo: '¿Eliminar a ${d.nombre}?',
      mensaje: 'Si el doctor tiene citas registradas no se borra: se '
          'desactiva, para no dejar citas sin dueño.',
    );
    if (ok) await onAccion(() => admin.eliminarDoctor(d.id));
  }
}

/// Formulario de doctor (crear y editar).
class _FormularioDoctor extends StatefulWidget {
  const _FormularioDoctor({this.doctor});

  final Doctor? doctor;

  @override
  State<_FormularioDoctor> createState() => _FormularioDoctorState();
}

class _FormularioDoctorState extends State<_FormularioDoctor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _correo;
  late final TextEditingController _telefono;
  late final TextEditingController _clinica;
  late final TextEditingController _descripcion;
  late final TextEditingController _experiencia;
  late final TextEditingController _rating;

  String _titulo = 'Dr.';
  String _especialidad = 'Medicina General';
  late Set<String> _horarios;

  /// Mismas especialidades que la paleta del tema reconoce por color.
  static const List<String> _especialidades = [
    'Medicina General',
    'Cardiología',
    'Pediatría',
    'Dermatología',
    'Neurología',
    'Traumatología',
    'Ginecología',
    'Odontología',
  ];

  /// Rejilla de atención (07:00–19:00 cada 30 min), igual que el backend.
  static List<String> get _rejilla {
    final out = <String>[];
    for (var m = 7 * 60; m <= 19 * 60; m += 30) {
      out.add('${(m ~/ 60).toString().padLeft(2, '0')}:'
          '${(m % 60).toString().padLeft(2, '0')}');
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    // El nombre llega compuesto ("Dr. Carlos Mendoza"): se usan los campos
    // sueltos que envía la API de administración.
    _nombre = TextEditingController(text: d?.nombrePila ?? '');
    _apellido = TextEditingController(text: d?.apellido ?? '');
    _correo = TextEditingController(text: d?.correo ?? '');
    _telefono = TextEditingController(text: d?.telefono ?? '');
    _clinica = TextEditingController(text: d?.clinica ?? '');
    _descripcion = TextEditingController(text: d?.descripcion ?? '');
    _experiencia = TextEditingController(text: '${d?.experiencia ?? 5}');
    _rating = TextEditingController(text: '${d?.rating ?? 4.5}');
    _titulo = d?.titulo ?? 'Dr.';
    _especialidad = _especialidades.contains(d?.especialidad)
        ? d!.especialidad
        : 'Medicina General';
    _horarios = {...?d?.horariosDisponibles};
    if (_horarios.isEmpty) {
      _horarios = {'08:00', '08:30', '09:00', '10:00', '14:00', '15:00'};
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _apellido,
      _correo,
      _telefono,
      _clinica,
      _descripcion,
      _experiencia,
      _rating,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_horarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un horario de atención.'),
          backgroundColor: AppColors.peligro,
        ),
      );
      return;
    }
    final horas = _horarios.toList()..sort();
    Navigator.of(context).pop({
      'nombre': _nombre.text.trim(),
      'apellido': _apellido.text.trim(),
      'titulo': _titulo,
      'especialidad': _especialidad,
      'correo': _correo.text.trim(),
      'telefono': _telefono.text.trim(),
      'clinica': _clinica.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'experiencia': int.tryParse(_experiencia.text.trim()) ?? 1,
      'rating': double.tryParse(_rating.text.trim().replaceAll(',', '.')) ?? 4.5,
      'horarios': horas,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo: widget.doctor == null ? 'Nuevo doctor' : 'Editar doctor',
      onGuardar: _guardar,
      formKey: _formKey,
      campos: [
        Row(
          children: [
            SizedBox(
              width: 92,
              child: DropdownButtonFormField<String>(
                initialValue: _titulo,
                decoration: const InputDecoration(labelText: 'Título'),
                items: const [
                  DropdownMenuItem(value: 'Dr.', child: Text('Dr.')),
                  DropdownMenuItem(value: 'Dra.', child: Text('Dra.')),
                ],
                onChanged: (v) => setState(() => _titulo = v ?? 'Dr.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'El nombre es obligatorio'
                    : null,
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _apellido,
          decoration: const InputDecoration(labelText: 'Apellido'),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'El apellido es obligatorio' : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _especialidad,
          decoration: const InputDecoration(labelText: 'Especialidad'),
          items: [
            for (final e in _especialidades)
              DropdownMenuItem(value: e, child: Text(e)),
          ],
          onChanged: (v) =>
              setState(() => _especialidad = v ?? 'Medicina General'),
        ),
        TextFormField(
          controller: _correo,
          decoration: const InputDecoration(labelText: 'Correo'),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null; // es opcional
            if (!t.contains('@') || !t.contains('.')) {
              return 'Correo no válido';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _telefono,
          decoration: const InputDecoration(labelText: 'Teléfono'),
          keyboardType: TextInputType.phone,
        ),
        TextFormField(
          controller: _clinica,
          decoration: const InputDecoration(labelText: 'Sede / clínica'),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _experiencia,
                decoration: const InputDecoration(labelText: 'Años de exp.'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0 || n > 70) return 'Entre 0 y 70';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _rating,
                decoration: const InputDecoration(labelText: 'Calificación'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n =
                      double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                  if (n == null || n < 0 || n > 5) return 'Entre 0 y 5';
                  return null;
                },
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _descripcion,
          decoration: const InputDecoration(labelText: 'Descripción'),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 4),
        const Text(
          'Horarios de atención',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const Text(
          'La rejilla va de 07:00 a 19:00 cada 30 minutos, igual que en el '
          'backend. El paciente solo verá las horas que marques aquí y que '
          'no estén ya reservadas.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final h in _rejilla)
              GestureDetector(
                onTap: () => setState(() {
                  _horarios.contains(h)
                      ? _horarios.remove(h)
                      : _horarios.add(h);
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: _horarios.contains(h)
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _horarios.contains(h)
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _horarios.contains(h)
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================ SERVICIOS

class PestanaServicios extends StatelessWidget {
  const PestanaServicios({
    super.key,
    required this.admin,
    required this.onAccion,
  });

  final AdminState admin;
  final EjecutarAccion onAccion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo servicio',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: admin.servicios.isEmpty
          ? const VacioAdmin(
              icono: Icons.list_alt_rounded,
              mensaje: 'Todavía no hay servicios registrados.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: admin.servicios.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = admin.servicios[i];
                return _TarjetaGestion(
                  avatar: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(s.icono, size: 23, color: s.color),
                  ),
                  titulo: s.nombre,
                  subtitulo: '${s.duracionMinutos} minutos',
                  detalle: s.descripcion.isEmpty ? null : s.descripcion,
                  etiqueta: '${s.duracionMinutos} min',
                  colorEtiqueta: s.color,
                  onEditar: () => _abrirFormulario(context, s),
                  onEliminar: () => _confirmarEliminar(context, s),
                );
              },
            ),
    );
  }

  Future<void> _abrirFormulario(
      BuildContext context, Servicio? servicio) async {
    final datos = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormularioServicio(servicio: servicio),
    );
    if (datos == null) return;
    await onAccion(() => servicio == null
        ? admin.crearServicio(datos)
        : admin.actualizarServicio(servicio.id, datos));
  }

  Future<void> _confirmarEliminar(BuildContext context, Servicio s) async {
    final ok = await _confirmar(
      context,
      titulo: '¿Eliminar ${s.nombre}?',
      mensaje: 'Si el servicio tiene citas asociadas no se borra: se '
          'desactiva, para conservar el historial.',
    );
    if (ok) await onAccion(() => admin.eliminarServicio(s.id));
  }
}

class _FormularioServicio extends StatefulWidget {
  const _FormularioServicio({this.servicio});

  final Servicio? servicio;

  @override
  State<_FormularioServicio> createState() => _FormularioServicioState();
}

class _FormularioServicioState extends State<_FormularioServicio> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _duracion;
  String _icono = 'medical';

  /// Mismo catálogo que usa `Repositorio.servicioDesdeJson` para traducir el
  /// nombre de icono que guarda el backend: así lo que se elige aquí es
  /// exactamente lo que la app sabrá dibujar después.
  static const Map<String, IconData> _iconos = Repositorio.iconosServicio;

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    _nombre = TextEditingController(text: s?.nombre ?? '');
    _descripcion = TextEditingController(text: s?.descripcion ?? '');
    _duracion = TextEditingController(text: '${s?.duracionMinutos ?? 30}');
    // Se recupera el nombre del icono a partir del IconData ya traducido.
    if (s != null) {
      for (final e in _iconos.entries) {
        if (e.value == s.icono) {
          _icono = e.key;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _duracion.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'duracionMinutos': int.tryParse(_duracion.text.trim()) ?? 30,
      'icono': _icono,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo:
          widget.servicio == null ? 'Nuevo servicio' : 'Editar servicio',
      onGuardar: _guardar,
      formKey: _formKey,
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'El nombre es obligatorio' : null,
        ),
        TextFormField(
          controller: _duracion,
          decoration:
              const InputDecoration(labelText: 'Duración (minutos)'),
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null || n <= 0 || n > 480) {
              return 'Entre 1 y 480 minutos';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _descripcion,
          decoration: const InputDecoration(labelText: 'Descripción'),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 4),
        const Text(
          'Icono',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final e in _iconos.entries)
              GestureDetector(
                onTap: () => setState(() => _icono = e.key),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _icono == e.key
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _icono == e.key
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    e.value,
                    size: 22,
                    color: _icono == e.key
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================= USUARIOS

class PestanaUsuarios extends StatelessWidget {
  const PestanaUsuarios({
    super.key,
    required this.admin,
    required this.onAccion,
    required this.emailPropio,
  });

  final AdminState admin;
  final EjecutarAccion onAccion;

  /// Correo del administrador que está usando el panel: su propia fila no
  /// se puede desactivar (el backend también lo rechaza con un 409).
  final String emailPropio;

  @override
  Widget build(BuildContext context) {
    if (admin.usuarios.isEmpty) {
      return const VacioAdmin(
        icono: Icons.people_outline_rounded,
        mensaje: 'No hay usuarios registrados.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: admin.usuarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = admin.usuarios[i];
        final esYo = u.email == emailPropio;
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radio),
            border: Border.all(
              color: u.activo ? AppColors.border : AppColors.peligro,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AvatarIlustrado(
                    semilla: u.avatarSemilla == 0
                        ? u.email.hashCode.abs()
                        : u.avatarSemilla,
                    tamano: 44,
                    animado: false,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (u.esAdmin) ...[
                              const SizedBox(width: 6),
                              const _Insignia(
                                texto: 'ADMIN',
                                color: AppColors.primary,
                              ),
                            ],
                            if (esYo) ...[
                              const SizedBox(width: 6),
                              const _Insignia(
                                texto: 'TÚ',
                                color: AppColors.acento,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          u.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${u.citas} cita(s) · '
                          '${u.activo ? "cuenta activa" : "cuenta desactivada"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: u.activo
                                ? AppColors.textHint
                                : AppColors.peligro,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(height: 1, color: AppColors.border),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Activa',
                          style: TextStyle(fontSize: 12.5)),
                      value: u.activo,
                      activeThumbColor: AppColors.primary,
                      onChanged: esYo
                          ? null
                          : (v) => onAccion(
                              () => admin.cambiarActivoUsuario(u.id, v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Admin',
                          style: TextStyle(fontSize: 12.5)),
                      value: u.esAdmin,
                      activeThumbColor: AppColors.primary,
                      onChanged: esYo
                          ? null
                          : (v) => _confirmarRol(context, u, v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarRol(
      BuildContext context, UsuarioAdmin u, bool esAdmin) async {
    final ok = await _confirmar(
      context,
      titulo: esAdmin
          ? '¿Hacer administrador a ${u.nombre}?'
          : '¿Quitar el rol de administrador?',
      mensaje: esAdmin
          ? 'Podrá ver y modificar las citas, los doctores, los servicios y '
              'las cuentas de todos los usuarios.'
          : '${u.nombre} perderá el acceso al panel de administración.',
    );
    if (ok) await onAccion(() => admin.cambiarRolAdmin(u.id, esAdmin));
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: color,
          ),
        ),
      );
}

// ======================================================= piezas comunes

/// Tarjeta de lista con avatar, datos y acciones de editar/eliminar.
class _TarjetaGestion extends StatelessWidget {
  const _TarjetaGestion({
    required this.avatar,
    required this.titulo,
    required this.subtitulo,
    required this.etiqueta,
    required this.colorEtiqueta,
    required this.onEditar,
    required this.onEliminar,
    this.detalle,
  });

  final Widget avatar;
  final String titulo;
  final String subtitulo;
  final String? detalle;
  final String etiqueta;
  final Color colorEtiqueta;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorEtiqueta,
                    ),
                  ),
                  if (detalle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detalle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: AppColors.peligro,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      );
}

/// Hoja inferior con formulario desplazable y botones.
class _HojaFormulario extends StatelessWidget {
  const _HojaFormulario({
    required this.titulo,
    required this.campos,
    required this.onGuardar,
    required this.formKey,
  });

  final String titulo;
  final List<Widget> campos;
  final VoidCallback onGuardar;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final alturaTeclado = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(top: 40, bottom: alturaTeclado),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Asa de la hoja.
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 11, bottom: 7),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in campos) ...[c, const SizedBox(height: 13)],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onGuardar,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de confirmación reutilizado por las acciones destructivas.
Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  return r == true;
}
