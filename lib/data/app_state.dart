import 'package:flutter/material.dart';

import '../core/fechas.dart';
import '../core/trace/trace_logger.dart';
import '../models/cita.dart';
import '../models/doctor.dart';
import '../models/estado_cita.dart';
import '../models/servicio.dart';
import '../models/usuario.dart';
import '../servicios/notificaciones.dart';
import 'api/api_cliente.dart';
import 'api/repositorio.dart';
import 'horarios_service.dart';
import 'preferencias.dart';
import 'sample_data.dart';

/// Fase de carga de los datos remotos, usada por la UI para decidir si
/// muestra esqueletos, el contenido o un panel de error con reintento.
enum FaseCarga { inicial, cargando, listo, error }

/// Estado compartido de la aplicacion: sesion, catalogo y citas.
///
/// Se implementa con ChangeNotifier + InheritedNotifier para no depender de
/// paquetes de gestion de estado. Cada mutacion queda registrada en el
/// TraceLogger, de modo que el flujo de datos es trazable de extremo a extremo.
///
/// Tiene dos modos:
///   - en linea  : los datos vienen de la API REST (SaludCuidado-backend) y
///                 las citas se guardan en SQLite.
///   - respaldo  : si el servidor no responde, se trabaja con los datos de
///                 ejemplo en memoria para que la app siga siendo usable.
/// `AppState.local()` fuerza el modo respaldo y nunca toca la red; es el que
/// usan las pruebas de contrato.
class AppState extends ChangeNotifier {
  AppState({Repositorio? repositorio})
      : _repo = repositorio ?? Repositorio(),
        _soloLocal = false,
        _doctores = [...sampleDoctors],
        _servicios = [...sampleServicios],
        _citas = construirSampleCitas() {
    traza.datos(
      _origen,
      'Estado creado en modo API (${ApiConfig.base}) con respaldo local de '
      '${_citas.length} citas y ${_doctores.length} doctores',
      contrato: 'HomeScreen.Requiere (catálogo disponible en memoria)',
    );
  }

  /// Estado sin red: catalogo y citas de ejemplo en memoria.
  AppState.local()
      : _repo = null,
        _soloLocal = true,
        _doctores = [...sampleDoctors],
        _servicios = [...sampleServicios],
        _citas = construirSampleCitas() {
    traza.datos(
      _origen,
      'Estado inicializado en modo local con ${_citas.length} citas y '
      '${_doctores.length} doctores de ejemplo',
      contrato: 'HomeScreen.Requiere (sampleCitas/sampleDoctors en memoria)',
    );
  }

  static const String _origen = 'AppState';

  final Repositorio? _repo;
  final bool _soloLocal;

  /// true cuando la app trabaja contra los datos de ejemplo en memoria.
  bool get soloLocal => _soloLocal;

  /// Repositorio con la sesión ya autenticada.
  ///
  /// Lo usa el panel de administración, que mantiene su propio estado
  /// ([AdminState]) pero reutiliza esta conexión y su token.
  /// Es null en modo local (pruebas): allí no hay panel.
  Repositorio? get repositorio => _repo;

  // ------------------------------------------------------------- conexión

  bool _enLinea = false;

  /// true cuando el backend respondio a la ultima operacion.
  bool get enLinea => _enLinea;

  FaseCarga _fase = FaseCarga.inicial;

  FaseCarga get fase => _fase;

  bool get cargando => _fase == FaseCarga.cargando;

  String? _mensajeError;

  /// Ultimo error de carga, pensado para mostrarse con un boton "Reintentar".
  String? get mensajeError => _mensajeError;

  /// Mensaje del banner que avisa de que se esta trabajando sin servidor.
  String? get avisoSinConexion {
    if (_soloLocal || _enLinea) return null;
    if (ApiConfig.sinServidor) {
      // Compilada sin API (p. ej. la versión publicada de muestra).
      return 'Versión de demostración: los cambios no se guardan.';
    }
    return 'Sin conexión con el servidor: datos de demostración.';
  }

  // ---------------------------------------------------------------- sesion

  Usuario? _usuario;

  Usuario? get usuario => _usuario;

  bool get autenticado => _usuario != null;

  /// Usuario mostrado en Home/Perfil. Si no hay sesion (p. ej. al abrir la
  /// app directamente en una ruta interna) se usa un invitado.
  Usuario get usuarioActual =>
      _usuario ??
      const Usuario(
        nombre: 'Invitado',
        email: 'invitado@saludcuidado.com',
        iniciales: 'IN',
      );

  /// Registra la sesion en memoria (usado por el modo local y por las
  /// pruebas; el flujo en linea pasa por [autenticar]).
  void iniciarSesion(Usuario u) {
    _usuario = u;
    traza.accion(_origen, 'Sesión iniciada: ${u.email}',
        contrato: 'LoginScreen.Garantiza');
    notifyListeners();
  }

  /// CONTRATO: autenticar
  ///   Requiere : email y password no vacios
  ///   Garantiza: sesion iniciada contra el backend; si el servidor no
  ///              responde, sesion de demostracion en memoria
  ///   Falla si : credenciales invalidas -> lanza ApiExcepcion (401)
  ///
  /// Trazabilidad backend: POST /api/auth/login (sesiones + PBKDF2).
  Future<void> autenticar(String email, String password) async {
    if (_soloLocal) {
      iniciarSesion(Usuario.desdeNombre(_nombreDesdeEmail(email), email));
      return;
    }
    try {
      final sesion = await _repo!.iniciarSesion(email, password);
      _enLinea = true;
      _usuario = sesion.usuario;
      await Preferencias.yo
          .guardarSesion(sesion.token, sesion.usuario.aJson());
      traza.accion(_origen, 'Sesión iniciada en el servidor: $email',
          contrato: 'LoginScreen.Garantiza (POST /api/auth/login)');
      notifyListeners();
      await cargarCitas();
    } on SinConexion catch (e) {
      // Sin servidor la app no se bloquea: entra en modo demostracion.
      _enLinea = false;
      traza.error(_origen, 'Login sin servidor (${e.detalle}): modo demo');
      iniciarSesion(Usuario.desdeNombre(_nombreDesdeEmail(email), email));
    }
  }

  /// CONTRATO: registrarUsuario
  ///   Requiere : nombre, email y password validos (ver RegistroScreen)
  ///   Garantiza: usuario creado en la base de datos y sesion iniciada
  ///   Falla si : el email ya existe -> ApiExcepcion (409)
  ///
  /// Trazabilidad backend: POST /api/auth/registro -> tabla usuarios.
  Future<void> registrarUsuario(
    String nombre,
    String email,
    String password,
  ) async {
    if (_soloLocal) {
      iniciarSesion(Usuario.desdeNombre(nombre, email));
      return;
    }
    try {
      final sesion = await _repo!.registrar(nombre, email, password);
      _enLinea = true;
      _usuario = sesion.usuario;
      await Preferencias.yo
          .guardarSesion(sesion.token, sesion.usuario.aJson());
      traza.accion(_origen, 'Usuario registrado en el servidor: $email',
          contrato: 'RegistroScreen.Garantiza (POST /api/auth/registro)');
      notifyListeners();
      await cargarCitas();
    } on SinConexion catch (e) {
      _enLinea = false;
      traza.error(_origen, 'Registro sin servidor (${e.detalle}): modo demo');
      iniciarSesion(Usuario.desdeNombre(nombre, email));
    }
  }

  Future<void> cerrarSesion() async {
    final email = _usuario?.email ?? '(sin sesión)';
    _usuario = null;
    await Preferencias.yo.borrarSesion();
    if (!_soloLocal) {
      await _repo!.cerrarSesion();
      // Las citas son del usuario: se vuelve al respaldo de ejemplo.
      _citas
        ..clear()
        ..addAll(construirSampleCitas());
    }
    traza.accion(_origen, 'Sesión cerrada: $email',
        contrato: 'PerfilScreen.Garantiza (cerrar sesión -> /login)');
    notifyListeners();
  }

  static String _nombreDesdeEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    final partes = local
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .toList();
    return partes.isEmpty ? 'Usuario' : partes.join(' ');
  }

  // -------------------------------------------------------- introducción

  bool _onboardingVisto = Preferencias.yo.onboardingVisto;

  /// Indica si la introducción animada ya se mostró.
  ///
  /// Se guarda en el almacenamiento del dispositivo ([Preferencias]), así
  /// que aparece una sola vez por instalación y no en cada arranque.
  bool get onboardingVisto => _onboardingVisto;

  void marcarOnboardingVisto() {
    if (_onboardingVisto) return;
    _onboardingVisto = true;
    Preferencias.yo.marcarOnboardingVisto(true);
    traza.accion(_origen, 'Introducción marcada como vista (guardado)');
    notifyListeners();
  }

  /// Permite volver a ver la introducción desde Perfil.
  void reiniciarOnboarding() {
    _onboardingVisto = false;
    Preferencias.yo.marcarOnboardingVisto(false);
    traza.accion(_origen, 'Introducción reiniciada');
    notifyListeners();
  }

  // ----------------------------------------------------------------- tema

  ModoTema _tema = Preferencias.yo.tema;

  ModoTema get tema => _tema;

  /// Modo que debe usar `MaterialApp`.
  ThemeMode get modoTema => switch (_tema) {
        ModoTema.claro => ThemeMode.light,
        ModoTema.oscuro => ThemeMode.dark,
        ModoTema.sistema => ThemeMode.system,
      };

  Future<void> cambiarTema(ModoTema modo) async {
    if (_tema == modo) return;
    _tema = modo;
    await Preferencias.yo.guardarTema(modo);
    notifyListeners();
  }

  // -------------------------------------------------------------- catalogo

  final List<Doctor> _doctores;
  final List<Servicio> _servicios;

  /// CONTRATO: doctores: List<Doctor> (puede estar vacia).
  List<Doctor> get doctores => List.unmodifiable(_doctores);

  List<Servicio> get servicios => List.unmodifiable(_servicios);

  /// Especialidades para los chips de filtro de DoctoresScreen.
  List<String> get especialidadesDisponibles {
    final set = <String>{for (final d in _doctores) d.especialidad};
    final lista = set.toList()..sort();
    return ['Todas', ...lista];
  }

  Doctor? doctorPorId(String id) {
    for (final d in _doctores) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Top 3 doctores por rating (HomeScreen).
  List<Doctor> get topDoctores {
    final lista = [..._doctores];
    lista.sort((a, b) => b.rating.compareTo(a.rating));
    return lista.take(3).toList();
  }

  /// Filtro local de la lista ya cargada (busqueda instantanea sin red).
  List<Doctor> filtrarDoctores({String especialidad = 'Todas', String texto = ''}) {
    final q = texto.trim().toLowerCase();
    return _doctores.where((d) {
      final okEspecialidad =
          especialidad == 'Todas' || d.especialidad == especialidad;
      final okTexto = q.isEmpty ||
          d.nombre.toLowerCase().contains(q) ||
          d.especialidad.toLowerCase().contains(q);
      return okEspecialidad && okTexto;
    }).toList();
  }

  // ------------------------------------------------------------------ citas

  final List<Cita> _citas;

  /// CONTRATO: citas: List<Cita> (puede estar vacia).
  List<Cita> get citas => List.unmodifiable(_citas);

  /// CONTRATO: porEstado
  ///   Garantiza: la lista va ordenada por fecha y hora, y la pestaña de
  ///              «Próximas» no incluye citas cuya hora ya pasó
  ///   Falla si : nunca; una pestaña sin citas devuelve lista vacía
  ///
  /// Las vencidas salen de «Próximas» y entran en [citasVencidas]: siguen
  /// estando PROGRAMADA en la base de datos, porque nadie confirmó que se
  /// asistiera ni que se cancelara, pero anunciarlas como próximas era
  /// mentira (ver `Cita.vencidaA`).
  List<Cita> porEstado(EstadoCita estado) {
    final ahora = DateTime.now();
    final lista = _citas
        .where((c) =>
            c.estado == estado &&
            (estado != EstadoCita.proxima || !c.vencidaA(ahora)))
        .toList();
    lista.sort((a, b) {
      final cmp = a.fecha.compareTo(b.fecha);
      return cmp != 0 ? cmp : a.hora.compareTo(b.hora);
    });
    return lista;
  }

  /// Citas que siguen PROGRAMADA pero cuya hora ya pasó: ni se atendieron
  /// ni se cancelaron. Se muestran aparte para que la persona decida.
  /// Van de la más reciente a la más antigua.
  List<Cita> get citasVencidas {
    final ahora = DateTime.now();
    final lista = _citas.where((c) => c.vencidaA(ahora)).toList();
    lista.sort((a, b) => b.momento.compareTo(a.momento));
    return lista;
  }

  /// Proxima cita mostrada en HomeScreen: la cita en estado `proxima`
  /// con fecha/hora mas cercana que todavía no ha pasado. Null si no hay.
  Cita? get proximaCita {
    final proximas = porEstado(EstadoCita.proxima);
    return proximas.isEmpty ? null : proximas.first;
  }

  // ------------------------------------------------------------ estadisticas

  int get totalCitas => _citas.length;

  int get totalProximas => porEstado(EstadoCita.proxima).length;

  int get totalCompletadas => porEstado(EstadoCita.completada).length;

  int get totalCanceladas => porEstado(EstadoCita.cancelada).length;

  // ------------------------------------------------------------------ carga

  /// Arranque: comprueba el backend y trae catalogo (y citas si hay sesion).
  Future<void> inicializar() async {
    if (_soloLocal) {
      _fase = FaseCarga.listo;
      return;
    }
    _fase = FaseCarga.cargando;
    _mensajeError = null;
    notifyListeners();

    final repo = _repo!;
    await repo.comprobarConexion();
    _enLinea = repo.enLinea;

    await _restaurarSesionGuardada();

    try {
      final resultados = await Future.wait([
        repo.doctores(),
        repo.servicios(),
      ]);
      final doctores = resultados[0] as List<Doctor>;
      final servicios = resultados[1] as List<Servicio>;
      _reemplazarDoctores(doctores);
      _reemplazarServicios(servicios);
      _fase = FaseCarga.listo;
      if (_enLinea) {
        _desdeCache = false;
        await Preferencias.yo.guardarCache(
          doctores: [for (final d in doctores) d.aJson()],
          servicios: [for (final s in servicios) s.aJson()],
        );
      }
      traza.datos(
        _origen,
        'Catálogo cargado: ${_doctores.length} doctores, '
        '${_servicios.length} servicios '
        '(${_enLinea ? "servidor" : "respaldo local"})',
      );
    } catch (e) {
      // Orden de preferencia cuando el servidor falla: primero lo último
      // que vio este dispositivo, y solo si no hay nada, los de ejemplo.
      _fase = FaseCarga.listo;
      _mensajeError = _texto(e);
      final rescatado = _restaurarCatalogoDeCache();
      traza.error(
        _origen,
        'Catálogo desde ${rescatado ? "el caché del dispositivo" : "los datos "
            "de ejemplo"}: ${_texto(e)}',
      );
    }
    notifyListeners();

    if (autenticado) await cargarCitas();
  }

  /// CONTRATO: _restaurarSesionGuardada
  ///   Requiere : nada; si no hay token guardado no hace nada
  ///   Garantiza: si el token sigue siendo válido, la app arranca con la
  ///              sesión abierta sin pedir la contraseña otra vez
  ///   Falla si : el servidor rechaza el token (401) -> se borra del
  ///              dispositivo y la app arranca en /login
  ///
  /// Sin servidor no se descarta el token: puede seguir siendo bueno y es
  /// solo la red la que falla, así que se conserva y se pinta el usuario
  /// guardado para que la app sea usable sin conexión.
  Future<void> _restaurarSesionGuardada() async {
    final prefs = Preferencias.yo;
    final token = prefs.token;
    if (token == null || token.isEmpty) return;

    if (!_enLinea) {
      final guardado = prefs.usuario;
      if (guardado != null) {
        _usuario = Usuario.desdeJson(guardado);
        traza.datos(
          _origen,
          'Sesión local de ${_usuario!.email} (sin servidor para validarla)',
        );
      }
      return;
    }

    try {
      _usuario = await _repo!.restaurarSesion(token);
      traza.accion(
        _origen,
        'Sesión restaurada sin pedir contraseña: ${_usuario!.email}',
        contrato: 'SplashScreen.Garantiza (token válido -> /home)',
      );
      await prefs.guardarSesion(token, _usuario!.aJson());
    } on ApiExcepcion catch (e) {
      traza.error(_origen, 'Token guardado rechazado (${e.estado}): se borra');
      await prefs.borrarSesion();
    } on SinConexion {
      final guardado = prefs.usuario;
      if (guardado != null) _usuario = Usuario.desdeJson(guardado);
      traza.error(_origen, 'Sesión no validada: el servidor no respondió');
    }
  }

  /// Recarga catalogo y citas (gesto "deslizar para actualizar").
  Future<void> refrescar() async {
    if (_soloLocal) return;
    await inicializar();
  }

  /// Trae las citas del usuario autenticado desde la base de datos.
  Future<void> cargarCitas() async {
    if (_soloLocal || !autenticado) return;
    _fase = FaseCarga.cargando;
    notifyListeners();
    try {
      final remotas = await _repo!.citas();
      _citas
        ..clear()
        ..addAll(remotas);
      _enLinea = true;
      _mensajeError = null;
      _fase = FaseCarga.listo;
      traza.datos(_origen, 'Citas cargadas del servidor: ${remotas.length}',
          contrato: 'MisCitasScreen.Requiere (citas del usuario)');
      // El teléfono queda al día: se guardan para poder verlas sin red y
      // se reprograman los recordatorios con lo que realmente hay.
      await Preferencias.yo
          .guardarCache(citas: [for (final c in remotas) c.aJson()]);
      await Notificaciones.yo.sincronizar(_citas);
    } on SinConexion catch (e) {
      _enLinea = false;
      _fase = FaseCarga.listo;
      _mensajeError = e.detalle;
      _restaurarCitasDeCache(e.detalle);
    } on ApiExcepcion catch (e) {
      _fase = FaseCarga.error;
      _mensajeError = e.mensaje;
      traza.error(_origen, 'Citas no cargadas: ${e.mensaje}');
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- caché

  /// Momento en que se guardaron por última vez los datos del dispositivo.
  /// La interfaz lo usa para avisar de que lo que se ve no es de ahora.
  DateTime? get fechaCache => Preferencias.yo.fechaCache;

  /// true cuando lo que se está mostrando viene del disco, no del servidor.
  bool _desdeCache = false;

  bool get desdeCache => _desdeCache;

  /// CONTRATO: _restaurarCitasDeCache
  ///   Requiere : haber guardado citas en una sesión anterior
  ///   Garantiza: la lista de citas pasa a ser la última conocida del
  ///              usuario, en lugar de las de ejemplo de otra persona
  ///   Falla si : no hay caché -> se deja el respaldo de ejemplo y se
  ///              registra en la traza
  ///
  /// Sin esto, abrir la app sin red mostraba las citas de muestra como si
  /// fueran tuyas, que es peor que no mostrar nada.
  void _restaurarCitasDeCache(String motivo) {
    final guardadas = Preferencias.yo.citasEnCache;
    if (guardadas.isEmpty) {
      traza.error(_origen, 'Citas no cargadas: $motivo (sin caché en disco)');
      return;
    }
    final recuperadas = <Cita>[];
    for (final e in guardadas) {
      try {
        recuperadas.add(Cita.desdeJson(e as Map<String, dynamic>));
      } catch (err) {
        traza.error(_origen, 'Cita del caché descartada: $err');
      }
    }
    if (recuperadas.isEmpty) return;
    _citas
      ..clear()
      ..addAll(recuperadas);
    _desdeCache = true;
    traza.datos(
      _origen,
      '${recuperadas.length} citas recuperadas del dispositivo ($motivo)',
      contrato: 'MisCitasScreen.Requiere (modo sin conexión)',
    );
  }

  /// Igual que el anterior pero para el catálogo, que se pinta antes de
  /// tener sesión. Devuelve true si consiguió algo.
  bool _restaurarCatalogoDeCache() {
    final prefs = Preferencias.yo;
    final doctores = <Doctor>[];
    for (final e in prefs.doctoresEnCache) {
      try {
        doctores.add(Doctor.desdeJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    final servicios = <Servicio>[];
    for (final e in prefs.serviciosEnCache) {
      try {
        servicios.add(Repositorio.servicioDesdeJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    if (doctores.isEmpty && servicios.isEmpty) return false;
    _reemplazarDoctores(doctores);
    _reemplazarServicios(servicios);
    _desdeCache = true;
    traza.datos(
      _origen,
      'Catálogo recuperado del dispositivo: ${doctores.length} doctores, '
      '${servicios.length} servicios',
    );
    return true;
  }

  void _reemplazarDoctores(List<Doctor> lista) {
    if (lista.isEmpty) return;
    _doctores
      ..clear()
      ..addAll(lista);
  }

  void _reemplazarServicios(List<Servicio> lista) {
    if (lista.isEmpty) return;
    _servicios
      ..clear()
      ..addAll(lista);
  }

  static String _texto(Object e) {
    if (e is ApiExcepcion) return e.mensaje;
    if (e is SinConexion) return e.detalle;
    return 'Error inesperado: $e';
  }

  /// Horarios libres de un doctor en una fecha.
  ///
  /// En linea los calcula el servidor (misma regla que CitaService.java);
  /// sin servidor se calculan con HorariosService sobre las citas locales.
  Future<List<String>> horariosDisponibles(Doctor doctor, DateTime fecha) async {
    if (_soloLocal || !_enLinea) {
      return HorariosService.disponibles(
        doctor: doctor,
        fecha: fecha,
        citasExistentes: _citas,
      );
    }
    try {
      return await _repo!.horarios(doctor.id, fecha);
    } on SinConexion {
      _enLinea = false;
      notifyListeners();
      return HorariosService.disponibles(
        doctor: doctor,
        fecha: fecha,
        citasExistentes: _citas,
      );
    }
  }

  // --------------------------------------------------------------- mutaciones

  /// CONTRATO: reservarCita (PDF 3.3 paso 3)
  ///   Requiere : doctor, fecha y hora de un horario disponible
  ///   Garantiza: cita PROGRAMADA guardada (en la base de datos si hay
  ///              servidor) y devuelta a la pantalla de confirmacion
  ///   Falla si : el horario ya esta ocupado -> null y [mensajeError]
  ///
  /// Trazabilidad backend: POST /api/citas -> tabla citas, con el indice
  /// unico parcial ix_citas_slot que impide la doble reserva.
  Future<Cita?> reservarCita({
    required Doctor doctor,
    required DateTime fecha,
    required String hora,
    String servicio = 'Medicina General',
    String? servicioId,
  }) async {
    if (!_soloLocal && _enLinea) {
      try {
        final cita = await _repo!.reservar(
          doctorId: doctor.id,
          fecha: fecha,
          hora: hora,
          servicioId: servicioId,
        );
        _citas.add(cita);
        _mensajeError = null;
        traza.datos(
          _origen,
          'Cita creada en el servidor ${cita.id}: ${doctor.nombre} '
          '${Fechas.iso(fecha)} $hora (estado PROGRAMADA)',
          contrato: 'ReservarScreen.Garantiza (paso 3 -> confirmación)',
        );
        await Notificaciones.yo.programar(cita);
        notifyListeners();
        return cita;
      } on ApiExcepcion catch (e) {
        _mensajeError = e.mensaje;
        traza.error(_origen, 'Reserva rechazada por el servidor: ${e.mensaje}',
            contrato: 'CitaService.crearCita (hora no disponible)');
        notifyListeners();
        return null;
      } on SinConexion catch (e) {
        _enLinea = false;
        traza.error(_origen, 'Reserva local por falta de servidor: ${e.detalle}');
        // Continúa abajo con la reserva en memoria.
      }
    }

    return _reservarLocal(
      doctor: doctor,
      fecha: fecha,
      hora: hora,
      servicio: servicio,
    );
  }

  /// Reserva replicando la validacion del backend en memoria
  /// (CitaService.crearCita lanza error si la hora no esta disponible).
  Cita? _reservarLocal({
    required Doctor doctor,
    required DateTime fecha,
    required String hora,
    required String servicio,
  }) {
    final libre = HorariosService.estaDisponible(
      doctor: doctor,
      fecha: fecha,
      hora: hora,
      citasExistentes: _citas,
    );

    if (!libre) {
      _mensajeError = 'El horario $hora ya no está disponible.';
      traza.error(
        _origen,
        'Horario $hora del ${Fechas.iso(fecha)} ya no está disponible',
        contrato: 'CitaService.crearCita (hora no disponible)',
      );
      notifyListeners();
      return null;
    }

    final cita = Cita(
      id: 'cita-${DateTime.now().millisecondsSinceEpoch}',
      doctor: doctor,
      fecha: fecha,
      hora: hora,
      estado: EstadoCita.proxima,
      servicio: servicio,
    );

    _citas.add(cita);
    _mensajeError = null;
    traza.datos(
      _origen,
      'Cita creada ${cita.id}: ${doctor.nombre} '
      '${Fechas.iso(fecha)} $hora (estado PROGRAMADA)',
      contrato: 'ReservarScreen.Garantiza (paso 3 -> confirmación)',
    );
    notifyListeners();
    return cita;
  }

  /// CONTRATO: reprogramarCita
  ///   Requiere : el id de una cita propia y un hueco libre del mismo doctor
  ///   Garantiza: la cita queda movida conservando su id y su historial, y
  ///              sus recordatorios se reprograman a la hora nueva
  ///   Falla si : el servidor rechaza el cambio -> false y [mensajeError]
  ///
  /// Sin servidor no se intenta: mover una cita en memoria y que el resto
  /// del mundo siga creyendo que es a otra hora sería peor que no hacerlo.
  Future<bool> reprogramarCita(
    String id, {
    required DateTime fecha,
    required String hora,
  }) async {
    final i = _citas.indexWhere((c) => c.id == id);
    if (i == -1) {
      traza.error(_origen, 'No se encontró la cita $id para reprogramar');
      return false;
    }
    if (_soloLocal || !_enLinea) {
      _mensajeError = 'Necesitas conexión para reprogramar una cita.';
      traza.error(_origen, 'Reprogramación no intentada: sin servidor');
      notifyListeners();
      return false;
    }

    final antes = '${Fechas.iso(_citas[i].fecha)} ${_citas[i].hora}';
    try {
      final actualizada =
          await _repo!.reprogramar(id, fecha: fecha, hora: hora);
      _citas[i] = actualizada;
      _mensajeError = null;
      traza.datos(
        _origen,
        'Cita $id movida de $antes a ${Fechas.iso(fecha)} $hora',
        contrato: 'PATCH /api/citas/<id> {fecha, hora}',
      );
      // Los avisos viejos apuntaban a la hora anterior.
      await Notificaciones.yo.cancelar(id);
      await Notificaciones.yo.programar(actualizada);
      notifyListeners();
      return true;
    } on ApiExcepcion catch (e) {
      _mensajeError = e.mensaje;
      traza.error(_origen, 'Reprogramación rechazada: ${e.mensaje}');
      notifyListeners();
      return false;
    } on SinConexion catch (e) {
      _enLinea = false;
      _mensajeError = 'Sin conexión: la cita no se movió.';
      traza.error(_origen, 'Reprogramación sin servidor: ${e.detalle}');
      notifyListeners();
      return false;
    }
  }

  /// Cancela una cita existente.
  /// Trazabilidad backend: PATCH /api/citas/<id> {estado: CANCELADA}, que
  /// además libera el horario gracias al índice único parcial.
  Future<bool> cancelarCita(String id) =>
      _cambiarEstado(id, EstadoCita.cancelada);

  /// Marca una cita como completada (usado desde Mis Citas).
  Future<bool> completarCita(String id) =>
      _cambiarEstado(id, EstadoCita.completada);

  Future<bool> _cambiarEstado(String id, EstadoCita nuevo) async {
    final i = _citas.indexWhere((c) => c.id == id);
    if (i == -1) {
      traza.error(_origen, 'No se encontró la cita $id para actualizar');
      return false;
    }
    if (_citas[i].estado != EstadoCita.proxima) {
      traza.error(
        _origen,
        'Solo se pueden actualizar citas próximas (cita $id está '
        '${_citas[i].estado.etiqueta})',
      );
      return false;
    }

    if (!_soloLocal && _enLinea) {
      try {
        final actualizada = await _repo!.cambiarEstado(id, nuevo);
        _citas[i] = actualizada;
        _mensajeError = null;
        traza.datos(
          _origen,
          'Cita $id -> ${nuevo.estadoBackend} en la base de datos',
          contrato: 'CitaService.cambiarEstadoCita',
        );
        // Una cita que ya no está programada no debe seguir avisando.
        await Notificaciones.yo.cancelar(id);
        notifyListeners();
        return true;
      } on ApiExcepcion catch (e) {
        _mensajeError = e.mensaje;
        traza.error(_origen, 'El servidor rechazó el cambio: ${e.mensaje}');
        notifyListeners();
        return false;
      } on SinConexion catch (e) {
        _enLinea = false;
        traza.error(_origen, 'Cambio local por falta de servidor: ${e.detalle}');
      }
    }

    _citas[i] = _citas[i].copyWith(estado: nuevo);
    traza.datos(_origen, 'Cita $id actualizada a ${nuevo.estadoBackend}',
        contrato: 'CitaService.cambiarEstadoCita');
    notifyListeners();
    return true;
  }
}

/// Provee el AppState al arbol de widgets sin dependencias externas.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState estado,
    required super.child,
  }) : super(notifier: estado);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope no encontrado en el arbol de widgets');
    return scope!.notifier!;
  }

  /// Lectura sin suscripcion (para callbacks que no necesitan rebuild).
  static AppState leer(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope no encontrado en el arbol de widgets');
    return scope!.notifier!;
  }
}
