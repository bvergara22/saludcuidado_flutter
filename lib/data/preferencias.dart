import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/trace/trace_logger.dart';

/// Preferencia de tema elegida por la persona.
enum ModoTema {
  sistema,
  claro,
  oscuro;

  static ModoTema desdeTexto(String? v) => switch (v) {
        'claro' => ModoTema.claro,
        'oscuro' => ModoTema.oscuro,
        _ => ModoTema.sistema,
      };

  String get etiqueta => switch (this) {
        ModoTema.sistema => 'Según el sistema',
        ModoTema.claro => 'Siempre claro',
        ModoTema.oscuro => 'Siempre oscuro',
      };
}

/// Almacenamiento local del dispositivo.
///
/// CONTRATO: Preferencias
///   Requiere : [abrir] llamado una vez antes de leer o escribir
///   Garantiza: los valores sobreviven al cierre de la aplicación
///   Falla si : la plataforma no ofrece almacenamiento -> [disponible] es
///              false y cada lectura devuelve su valor por defecto, sin
///              lanzar excepciones
///
/// Es la pieza de la que cuelgan la sesión persistente, la biometría, el
/// caché sin conexión y el tema. Envuelve `shared_preferences`, que guarda
/// en `SharedPreferences` (Android), `NSUserDefaults` (iOS) y
/// `localStorage` (web), de modo que el resto de la app no sabe en qué
/// plataforma corre.
///
/// Lo que aquí se guarda **no es secreto**: el token es opaco y de sesión,
/// y las contraseñas nunca se escriben. Para datos sensibles de verdad el
/// paso siguiente sería `flutter_secure_storage` (Keystore / Keychain).
class Preferencias {
  Preferencias._(this._prefs);

  static const String _origen = 'Preferencias';

  // Claves con prefijo para que se lean de un vistazo al depurar.
  static const String _kToken = 'sesion.token';
  static const String _kUsuario = 'sesion.usuario';
  static const String _kOnboarding = 'onboarding.visto';
  static const String _kTour = 'onboarding.tour';
  static const String _kTema = 'ajustes.tema';
  static const String _kBiometria = 'seguridad.biometria';
  static const String _kNotificaciones = 'ajustes.notificaciones';
  static const String _kCacheCitas = 'cache.citas';
  static const String _kCacheDoctores = 'cache.doctores';
  static const String _kCacheServicios = 'cache.servicios';
  static const String _kCacheFecha = 'cache.fecha';

  final SharedPreferences? _prefs;

  /// false cuando la plataforma no dio almacenamiento: la app sigue
  /// funcionando, simplemente no recuerda nada entre arranques.
  bool get disponible => _prefs != null;

  static Preferencias? _instancia;

  /// Instancia ya abierta. Antes de [abrir] devuelve una vacía, para que
  /// nadie tenga que comprobar null.
  static Preferencias get yo => _instancia ??= Preferencias._(null);

  /// CONTRATO: abrir
  ///   Garantiza: [yo] queda lista para usarse
  ///   Falla si : el canal de la plataforma falla -> se registra en la
  ///              traza y se sigue sin almacenamiento
  static Future<Preferencias> abrir() async {
    if (_instancia != null && _instancia!.disponible) return _instancia!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _instancia = Preferencias._(prefs);
      traza.datos(_origen, 'Almacenamiento local abierto');
    } catch (e) {
      _instancia = Preferencias._(null);
      traza.error(_origen, 'Sin almacenamiento local: $e');
    }
    return _instancia!;
  }

  /// Solo para pruebas: inyecta una instancia concreta.
  static void usarEnPruebas(Preferencias p) => _instancia = p;

  static Preferencias vacia() => Preferencias._(null);

  // --------------------------------------------------------------- sesión

  String? get token => _prefs?.getString(_kToken);

  /// JSON del usuario de la última sesión, para pintar la interfaz antes
  /// de que el servidor confirme el token.
  Map<String, dynamic>? get usuario {
    final texto = _prefs?.getString(_kUsuario);
    if (texto == null || texto.isEmpty) return null;
    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarSesion(String token, Map<String, dynamic> usuario) async {
    await _prefs?.setString(_kToken, token);
    await _prefs?.setString(_kUsuario, jsonEncode(usuario));
    traza.datos(_origen, 'Sesión guardada en el dispositivo');
  }

  Future<void> borrarSesion() async {
    await _prefs?.remove(_kToken);
    await _prefs?.remove(_kUsuario);
    await _prefs?.remove(_kCacheCitas);
    traza.datos(_origen, 'Sesión y citas en caché borradas del dispositivo');
  }

  // --------------------------------------------------------------- ajustes

  bool get onboardingVisto => _prefs?.getBool(_kOnboarding) ?? false;

  Future<void> marcarOnboardingVisto(bool visto) async {
    await _prefs?.setBool(_kOnboarding, visto);
  }

  /// true cuando el usuario ya hizo el recorrido guiado de la app.
  ///
  /// Es distinto de [onboardingVisto]: aquel es la bienvenida anterior al
  /// inicio de sesión, y este el recorrido que explica cómo usar la app
  /// una vez dentro. Quien ya tenía cuenta no vio ninguno de los dos.
  bool get tourVisto => _prefs?.getBool(_kTour) ?? false;

  Future<void> marcarTourVisto(bool visto) async {
    await _prefs?.setBool(_kTour, visto);
  }

  ModoTema get tema => ModoTema.desdeTexto(_prefs?.getString(_kTema));

  Future<void> guardarTema(ModoTema modo) async {
    await _prefs?.setString(_kTema, modo.name);
    traza.accion(_origen, 'Tema guardado: ${modo.etiqueta}');
  }

  bool get biometriaActiva => _prefs?.getBool(_kBiometria) ?? false;

  Future<void> guardarBiometria(bool activa) async {
    await _prefs?.setBool(_kBiometria, activa);
    traza.accion(_origen, 'Desbloqueo biométrico ${activa ? "activado" : "desactivado"}');
  }

  /// Por defecto activas: una app de citas que no avisa no sirve de mucho.
  bool get notificacionesActivas => _prefs?.getBool(_kNotificaciones) ?? true;

  Future<void> guardarNotificaciones(bool activas) async {
    await _prefs?.setBool(_kNotificaciones, activas);
    traza.accion(
        _origen, 'Recordatorios ${activas ? "activados" : "desactivados"}');
  }

  // ----------------------------------------------------------------- caché

  /// Momento en que se guardó el último caché, para poder avisar de que
  /// los datos que se están viendo no son de ahora mismo.
  DateTime? get fechaCache {
    final t = _prefs?.getString(_kCacheFecha);
    return t == null ? null : DateTime.tryParse(t);
  }

  List<dynamic> get citasEnCache => _leerLista(_kCacheCitas);

  List<dynamic> get doctoresEnCache => _leerLista(_kCacheDoctores);

  List<dynamic> get serviciosEnCache => _leerLista(_kCacheServicios);

  Future<void> guardarCache({
    List<dynamic>? citas,
    List<dynamic>? doctores,
    List<dynamic>? servicios,
  }) async {
    if (_prefs == null) return;
    if (citas != null) await _prefs.setString(_kCacheCitas, jsonEncode(citas));
    if (doctores != null) {
      await _prefs.setString(_kCacheDoctores, jsonEncode(doctores));
    }
    if (servicios != null) {
      await _prefs.setString(_kCacheServicios, jsonEncode(servicios));
    }
    await _prefs.setString(_kCacheFecha, DateTime.now().toIso8601String());
  }

  List<dynamic> _leerLista(String clave) {
    final texto = _prefs?.getString(clave);
    if (texto == null || texto.isEmpty) return const [];
    try {
      final v = jsonDecode(texto);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }
}
