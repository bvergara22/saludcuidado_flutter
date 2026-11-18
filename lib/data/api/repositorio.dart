import 'package:flutter/material.dart';

import '../../core/trace/trace_logger.dart';
import '../../models/cita.dart';
import '../../models/doctor.dart';
import '../../models/estado_cita.dart';
import '../../models/mensaje_chat.dart';
import '../../models/servicio.dart';
import '../../models/usuario.dart';
import '../sample_data.dart';
import 'api_cliente.dart';

/// Resultado de una autenticación.
class SesionIniciada {
  final String token;
  final Usuario usuario;

  const SesionIniciada(this.token, this.usuario);
}

/// Puerta de entrada a los datos.
///
/// Hace de intermediario entre la aplicación y la API REST, y aplica la
/// política de respaldo: si el servidor no responde, la app sigue
/// funcionando con los datos de ejemplo en memoria en lugar de quedarse
/// en blanco. Cada caída a respaldo queda registrada en la traza.
class Repositorio {
  static const String _origen = 'Repositorio';

  final ApiCliente api;

  Repositorio({ApiCliente? cliente}) : api = cliente ?? ApiCliente();

  /// true cuando la última operación se resolvió contra el servidor.
  bool _enLinea = false;

  bool get enLinea => _enLinea;

  /// Comprueba la disponibilidad del backend y recuerda el resultado.
  Future<bool> comprobarConexion() async {
    if (ApiConfig.sinServidor) {
      _enLinea = false;
      traza.datos(
        _origen,
        'Sin servidor configurado: modo demostración '
        '(compilar con --dart-define=API_BASE=... para conectarlo)',
      );
      return false;
    }
    _enLinea = await api.disponible();
    traza.datos(
      _origen,
      _enLinea
          ? 'Backend disponible en ${ApiConfig.base}'
          : 'Backend no disponible: se usarán datos locales de respaldo',
    );
    return _enLinea;
  }

  // ------------------------------------------------------------ sesión

  Future<SesionIniciada> iniciarSesion(String email, String password) async {
    final j = await api.publicar('/api/auth/login', {
      'email': email,
      'password': password,
    });
    final token = j['token'] as String;
    api.token = token;
    _enLinea = true;
    return SesionIniciada(
      token,
      Usuario.desdeJson(j['usuario'] as Map<String, dynamic>),
    );
  }

  Future<SesionIniciada> registrar(
    String nombre,
    String email,
    String password,
  ) async {
    final j = await api.publicar('/api/auth/registro', {
      'nombre': nombre,
      'email': email,
      'password': password,
    });
    final token = j['token'] as String;
    api.token = token;
    _enLinea = true;
    return SesionIniciada(
      token,
      Usuario.desdeJson(j['usuario'] as Map<String, dynamic>),
    );
  }

  /// CONTRATO: restaurarSesion
  ///   Requiere : un token guardado en el dispositivo
  ///   Garantiza: si el servidor lo reconoce, devuelve el usuario dueño de
  ///              la sesión y el cliente queda autenticado
  ///   Falla si : el token caducó o no existe -> ApiExcepcion 401, y quien
  ///              llama debe borrarlo del almacenamiento local
  ///
  /// Trazabilidad backend: `GET /api/auth/yo` resuelve el token contra la
  /// tabla `sesiones`, igual que haría `CustomUserDetailsService` con la
  /// cookie de sesión en la plataforma web.
  Future<Usuario> restaurarSesion(String token) async {
    api.token = token;
    try {
      final j = await api.obtener('/api/auth/yo');
      _enLinea = true;
      final usuario =
          Usuario.desdeJson(j['usuario'] as Map<String, dynamic>? ?? j);
      traza.datos(_origen, 'Sesión restaurada para ${usuario.email}');
      return usuario;
    } catch (e) {
      // Un token que el servidor no acepta no sirve para nada más.
      if (e is ApiExcepcion && e.esNoAutorizado) api.token = null;
      rethrow;
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await api.publicar('/api/auth/logout', const {});
    } catch (_) {
      // Cerrar sesión nunca debe fallar de cara al usuario.
    }
    api.token = null;
  }

  // ----------------------------------------------------------- doctores

  /// Lista de doctores. Si el servidor no responde, devuelve los de ejemplo.
  Future<List<Doctor>> doctores({String? especialidad, String? buscar}) async {
    try {
      final j = await api.obtener('/api/doctores', query: {
        if (especialidad != null && especialidad != 'Todas')
          'especialidad': especialidad,
        if (buscar != null && buscar.trim().isNotEmpty) 'q': buscar.trim(),
      });
      _enLinea = true;
      return (j['doctores'] as List)
          .map((e) => Doctor.desdeJson(e as Map<String, dynamic>))
          .toList();
    } on SinConexion {
      return _respaldoDoctores(especialidad, buscar);
    }
  }

  List<Doctor> _respaldoDoctores(String? especialidad, String? buscar) {
    _enLinea = false;
    traza.error(_origen, 'Doctores servidos desde el respaldo local');
    final texto = (buscar ?? '').trim().toLowerCase();
    return sampleDoctors.where((d) {
      final porEspecialidad =
          especialidad == null || especialidad == 'Todas' ||
              d.especialidad == especialidad;
      final porTexto = texto.isEmpty ||
          d.nombre.toLowerCase().contains(texto) ||
          d.especialidad.toLowerCase().contains(texto);
      return porEspecialidad && porTexto;
    }).toList();
  }

  /// Horarios libres de un doctor en una fecha (los calcula el servidor).
  Future<List<String>> horarios(String doctorId, DateTime fecha) async {
    final iso = _iso(fecha);
    try {
      final j = await api.obtener('/api/doctores/$doctorId/horarios',
          query: {'fecha': iso});
      _enLinea = true;
      return (j['horarios'] as List).cast<String>();
    } on SinConexion {
      _enLinea = false;
      traza.error(_origen, 'Horarios calculados localmente (sin servidor)');
      final d = sampleDoctors.where((x) => x.id == doctorId);
      return d.isEmpty ? const [] : d.first.horariosDisponibles;
    }
  }

  // ---------------------------------------------------------- servicios

  Future<List<Servicio>> servicios() async {
    try {
      final j = await api.obtener('/api/servicios');
      _enLinea = true;
      return (j['servicios'] as List)
          .map((e) => servicioDesdeJson(e as Map<String, dynamic>))
          .toList();
    } on SinConexion {
      _enLinea = false;
      traza.error(_origen, 'Servicios servidos desde el respaldo local');
      return sampleServicios;
    }
  }

  // --------------------------------------------------------------- citas

  Future<List<Cita>> citas() async {
    final j = await api.obtener('/api/citas');
    _enLinea = true;
    final lista = <Cita>[];
    for (final e in j['citas'] as List) {
      try {
        lista.add(Cita.desdeJson(e as Map<String, dynamic>));
      } on FormatException catch (err) {
        // Una cita corrupta no debe tumbar toda la pantalla.
        traza.error(_origen, 'Cita descartada: ${err.message}');
      }
    }
    return lista;
  }

  Future<Cita> reservar({
    required String doctorId,
    required DateTime fecha,
    required String hora,
    String? servicioId,
  }) async {
    final j = await api.publicar('/api/citas', {
      'doctorId': doctorId,
      'fecha': _iso(fecha),
      'hora': hora,
      if (servicioId != null) 'servicioId': servicioId,
    });
    _enLinea = true;
    return Cita.desdeJson(j['cita'] as Map<String, dynamic>);
  }

  /// CONTRATO: reprogramar
  ///   Requiere : una cita existente del usuario y un hueco libre
  ///   Garantiza: la cita queda movida, con el mismo id, y vuelve a
  ///              estado PROGRAMADA
  ///   Falla si : el hueco está ocupado o la cita ya se completó -> 409;
  ///              el momento ya pasó -> 400
  ///
  /// Trazabilidad backend: `PATCH /api/citas/<id>` con fecha y hora. En la
  /// plataforma web esto no existe: allí hay que cancelar y volver a
  /// reservar, con lo que se pierde el hilo de la cita original.
  Future<Cita> reprogramar(
    String citaId, {
    required DateTime fecha,
    required String hora,
  }) async {
    final j = await api.parchear('/api/citas/$citaId', {
      'fecha': _iso(fecha),
      'hora': hora,
    });
    _enLinea = true;
    return Cita.desdeJson(j['cita'] as Map<String, dynamic>);
  }

  Future<Cita> cambiarEstado(String citaId, EstadoCita estado) async {
    final j = await api.parchear('/api/citas/$citaId', {
      'estado': estado.estadoBackend,
    });
    _enLinea = true;
    return Cita.desdeJson(j['cita'] as Map<String, dynamic>);
  }

  /// CONTRATO: actualizarCuenta
  ///   Requiere : sesión iniciada; para cambiar la contraseña, la actual
  ///   Garantiza: devuelve el usuario ya actualizado
  ///   Falla si : la contraseña actual no coincide -> ApiExcepcion 401
  ///              la nueva es demasiado corta -> ApiExcepcion 400
  ///
  /// Trazabilidad backend: `PATCH /api/auth/yo`.
  Future<Usuario> actualizarCuenta({
    String? nombre,
    String? passwordActual,
    String? passwordNueva,
  }) async {
    final j = await api.parchear('/api/auth/yo', {
      if (nombre != null) 'nombre': nombre,
      if (passwordNueva != null && passwordNueva.isNotEmpty) ...{
        'passwordActual': passwordActual ?? '',
        'passwordNueva': passwordNueva,
      },
    });
    _enLinea = true;
    return Usuario.desdeJson(j['usuario'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------- asistente

  /// CONTRATO: chat
  ///   Requiere : sesión iniciada y un mensaje no vacío
  ///   Garantiza: devuelve la respuesta del asistente, con las citas o los
  ///              doctores que haya consultado
  ///   Falla si : sin sesión -> ApiExcepcion 401
  ///              sin servidor -> SinConexion (el asistente consulta la
  ///              base de datos, así que no tiene respaldo local posible)
  ///
  /// Trazabilidad backend: `POST /api/chat` -> `ChatController.java`.
  Future<MensajeChat> chat(String mensaje) async {
    final j = await api.publicar('/api/chat', {'mensaje': mensaje});
    _enLinea = true;
    return MensajeChat.desdeJson(
      j,
      leerCita: Cita.desdeJson,
      leerDoctor: Doctor.desdeJson,
    );
  }

  // --------------------------------------------------------- utilidades

  static String _iso(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  /// Iconos que el backend puede nombrar (columna `servicios.icono`).
  ///
  /// El JSON no puede transportar un `IconData`, así que viaja un nombre
  /// corto y aquí se traduce. Un nombre desconocido cae en 'medical' en vez
  /// de romper la pantalla: así un servicio creado desde el panel de
  /// administración con un icono que esta versión de la app no conoce sigue
  /// siendo usable.
  static const Map<String, IconData> iconosServicio = {
    'stethoscope': Icons.medical_services_outlined,
    'tooth': Icons.masks_outlined,
    'child': Icons.child_care_outlined,
    'heart': Icons.favorite_outline,
    'skin': Icons.spa_outlined,
    'lab': Icons.science_outlined,
    'medical': Icons.local_hospital_outlined,
    'eye': Icons.remove_red_eye_outlined,
  };

  static Servicio servicioDesdeJson(Map<String, dynamic> j) {
    final nombre = j['nombre'] as String? ?? 'Servicio';
    final iconoNombre = j['icono'] as String? ?? '';
    return Servicio(
      id: j['id'] as String,
      nombre: nombre,
      descripcion: j['descripcion'] as String? ?? '',
      duracionMinutos: (j['duracionMinutos'] as num?)?.toInt() ?? 30,
      icono: iconosServicio[iconoNombre] ?? Icons.local_hospital_outlined,
      iconoNombre: iconoNombre,
      color: Color((j['color'] as num?)?.toInt() ?? 0xFF1A5FBF),
    );
  }
}
