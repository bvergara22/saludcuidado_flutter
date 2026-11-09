import 'package:flutter/foundation.dart';

import '../core/trace/trace_logger.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../models/resumen_admin.dart';
import '../models/servicio.dart';
import '../models/usuario_admin.dart';
import 'api/api_cliente.dart';
import 'api/repositorio.dart';

/// Estado del panel de administración.
///
/// Vive aparte de [AppState] porque solo existe mientras la pantalla de
/// administración está abierta: así los datos de todos los usuarios no se
/// quedan en memoria durante el uso normal de la app.
///
/// TRAZABILIDAD: equivale al modelo que `AdminController.adminPanel()`
/// enviaba a `admin.html` (citas, doctores, servicios, estadísticas).
class AdminState extends ChangeNotifier {
  AdminState(this._repo);

  static const String _origen = 'AdminState';

  final Repositorio _repo;

  // ------------------------------------------------------------ estado UI

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _error;
  String? get error => _error;

  /// Mensaje de éxito de la última operación (para el SnackBar).
  String? ultimoAviso;

  // --------------------------------------------------------------- datos

  ResumenAdmin? _resumen;
  ResumenAdmin? get resumen => _resumen;

  List<Cita> _citas = const [];
  List<Cita> get citas => _citas;

  List<Doctor> _doctores = const [];
  List<Doctor> get doctores => _doctores;

  List<Servicio> _servicios = const [];
  List<Servicio> get servicios => _servicios;

  List<UsuarioAdmin> _usuarios = const [];
  List<UsuarioAdmin> get usuarios => _usuarios;

  // -------------------------------------------------------------- filtros

  /// 'TODAS' | 'PROGRAMADA' | 'COMPLETADA' | 'CANCELADA'
  String filtroEstado = 'TODAS';

  /// 'todas' | 'hoy' | 'semana' | 'mes'
  String filtroRango = 'todas';

  String busqueda = '';

  // ---------------------------------------------------------------- carga

  /// Carga todo el panel de una vez.
  Future<void> cargarTodo() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _cargarResumen(),
        _cargarCitas(),
        _cargarDoctores(),
        _cargarServicios(),
        _cargarUsuarios(),
      ]);
      traza.datos(
        _origen,
        'Panel cargado: ${_citas.length} citas, ${_doctores.length} doctores, '
        '${_servicios.length} servicios, ${_usuarios.length} usuarios',
        contrato: 'AdminController.adminPanel (ROLE_ADMIN)',
      );
    } catch (e) {
      _error = _texto(e);
      traza.error(_origen, 'No se pudo cargar el panel: $_error');
    }

    _cargando = false;
    notifyListeners();
  }

  Future<void> _cargarResumen() async {
    final j = await _repo.api.obtener('/api/admin/resumen');
    _resumen = ResumenAdmin.desdeJson(j);
  }

  Future<void> _cargarCitas() async {
    final j = await _repo.api.obtener('/api/admin/citas', query: {
      if (filtroEstado != 'TODAS') 'estado': filtroEstado,
      if (filtroRango != 'todas') 'rango': filtroRango,
      if (busqueda.trim().isNotEmpty) 'q': busqueda.trim(),
    });
    final lista = <Cita>[];
    for (final e in j['citas'] as List) {
      try {
        lista.add(Cita.desdeJson(e as Map<String, dynamic>));
      } on FormatException catch (err) {
        traza.error(_origen, 'Cita descartada: ${err.message}');
      }
    }
    _citas = lista;
  }

  Future<void> _cargarDoctores() async {
    final j = await _repo.api.obtener('/api/admin/doctores');
    _doctores = (j['doctores'] as List)
        .map((e) => Doctor.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _cargarServicios() async {
    final j = await _repo.api.obtener('/api/admin/servicios');
    _servicios = (j['servicios'] as List)
        .map((e) => Repositorio.servicioDesdeJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _cargarUsuarios() async {
    final j = await _repo.api.obtener('/api/admin/usuarios');
    _usuarios = (j['usuarios'] as List)
        .map((e) => UsuarioAdmin.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Vuelve a pedir solo las citas (al cambiar un filtro).
  Future<void> refiltrarCitas() async {
    _cargando = true;
    notifyListeners();
    try {
      await _cargarCitas();
      _error = null;
    } catch (e) {
      _error = _texto(e);
    }
    _cargando = false;
    notifyListeners();
  }

  // ----------------------------------------------------------- mutaciones

  /// Cambia el estado de cualquier cita.
  /// TRAZABILIDAD: AdminController.cambiarEstadoCita().
  Future<bool> cambiarEstadoCita(String id, String estado) =>
      _operar('Cita $id -> $estado', () async {
        await _repo.api.parchear('/api/admin/citas/$id', {'estado': estado});
        await Future.wait([_cargarCitas(), _cargarResumen()]);
        return 'Cita actualizada a $estado.';
      });

  /// TRAZABILIDAD: AdminController.deleteCita().
  Future<bool> eliminarCita(String id) =>
      _operar('Eliminar cita $id', () async {
        await _repo.api.eliminar('/api/admin/citas/$id');
        await Future.wait([_cargarCitas(), _cargarResumen()]);
        return 'Cita eliminada.';
      });

  /// TRAZABILIDAD: AdminController.createDoctor().
  Future<bool> crearDoctor(Map<String, dynamic> datos) =>
      _operar('Crear doctor', () async {
        final j = await _repo.api.publicar('/api/admin/doctores', datos);
        await Future.wait([_cargarDoctores(), _cargarResumen()]);
        final d = j['doctor'] as Map<String, dynamic>;
        return 'Doctor ${d['nombre']} creado.';
      });

  /// TRAZABILIDAD: AdminController.updateDoctor().
  Future<bool> actualizarDoctor(String id, Map<String, dynamic> datos) =>
      _operar('Actualizar doctor $id', () async {
        await _repo.api.actualizar('/api/admin/doctores/$id', datos);
        await _cargarDoctores();
        return 'Doctor actualizado.';
      });

  /// TRAZABILIDAD: AdminController.deleteDoctor().
  Future<bool> eliminarDoctor(String id) =>
      _operar('Eliminar doctor $id', () async {
        final j = await _repo.api.eliminar('/api/admin/doctores/$id');
        await Future.wait([_cargarDoctores(), _cargarResumen()]);
        return j['mensaje'] as String? ?? 'Doctor eliminado.';
      });

  Future<bool> crearServicio(Map<String, dynamic> datos) =>
      _operar('Crear servicio', () async {
        await _repo.api.publicar('/api/admin/servicios', datos);
        await Future.wait([_cargarServicios(), _cargarResumen()]);
        return 'Servicio creado.';
      });

  Future<bool> actualizarServicio(String id, Map<String, dynamic> datos) =>
      _operar('Actualizar servicio $id', () async {
        await _repo.api.actualizar('/api/admin/servicios/$id', datos);
        await _cargarServicios();
        return 'Servicio actualizado.';
      });

  Future<bool> eliminarServicio(String id) =>
      _operar('Eliminar servicio $id', () async {
        final j = await _repo.api.eliminar('/api/admin/servicios/$id');
        await Future.wait([_cargarServicios(), _cargarResumen()]);
        return j['mensaje'] as String? ?? 'Servicio eliminado.';
      });

  /// Activa o desactiva una cuenta.
  /// TRAZABILIDAD: UsuarioController.cambiarEstadoUsuario().
  Future<bool> cambiarActivoUsuario(int id, bool activo) =>
      _operar('Usuario $id activo=$activo', () async {
        await _repo.api.parchear('/api/admin/usuarios/$id', {'activo': activo});
        await Future.wait([_cargarUsuarios(), _cargarResumen()]);
        return activo ? 'Cuenta activada.' : 'Cuenta desactivada.';
      });

  /// Concede o retira el rol de administrador.
  Future<bool> cambiarRolAdmin(int id, bool esAdmin) =>
      _operar('Usuario $id admin=$esAdmin', () async {
        await _repo.api
            .parchear('/api/admin/usuarios/$id', {'esAdmin': esAdmin});
        await _cargarUsuarios();
        return esAdmin
            ? 'Ahora es administrador.'
            : 'Ya no es administrador.';
      });

  /// Ejecuta una operación mostrando carga, y traduce el error a mensaje.
  Future<bool> _operar(String etiqueta, Future<String> Function() accion) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    var exito = false;
    try {
      ultimoAviso = await accion();
      traza.accion(_origen, '$etiqueta: ok');
      exito = true;
    } catch (e) {
      _error = _texto(e);
      ultimoAviso = null;
      traza.error(_origen, '$etiqueta falló: $_error');
    }
    _cargando = false;
    notifyListeners();
    return exito;
  }

  static String _texto(Object e) {
    if (e is ApiExcepcion) return e.mensaje;
    if (e is SinConexion) return e.detalle;
    return 'Error inesperado: $e';
  }
}
