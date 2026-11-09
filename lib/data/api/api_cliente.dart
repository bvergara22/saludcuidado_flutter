import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:http/http.dart' as http;

import '../../core/trace/trace_logger.dart';

/// Error devuelto por la API con formato conocido.
class ApiExcepcion implements Exception {
  final int estado;
  final String codigo;
  final String mensaje;

  const ApiExcepcion(this.estado, this.codigo, this.mensaje);

  bool get esNoAutorizado => estado == 401;
  bool get esConflicto => estado == 409;

  @override
  String toString() => 'ApiExcepcion($estado/$codigo): $mensaje';
}

/// El servidor no respondió: apagado, sin red o agotó el tiempo de espera.
class SinConexion implements Exception {
  final String detalle;

  const SinConexion(this.detalle);

  @override
  String toString() => 'SinConexion: $detalle';
}

/// Configuración del origen de la API.
///
/// Se resuelve en este orden:
///   1. `--dart-define=API_BASE=https://mi-api.onrender.com` al compilar.
///      Es la forma de apuntar a la API publicada sin tocar el código.
///   2. En web, el parámetro de consulta `?api=` de la propia URL.
///      Sirve para probar otro servidor sin recompilar.
///   3. Valor por defecto según la plataforma, para desarrollo local:
///      - Flutter Web / escritorio -> localhost
///      - emulador de Android      -> 10.0.2.2 (alias del host)
///      - app publicada en web      -> vacío (sin API: modo demostración)
///
/// Para un teléfono físico en la red local hay que poner la IP del PC.
/// Si [base] queda vacía, la app no intenta ninguna petición y trabaja
/// directamente con los datos de demostración.
class ApiConfig {
  ApiConfig._();

  static const int puerto = 8080;

  /// Valor fijado al compilar con `--dart-define=API_BASE=...`.
  static const String definidaAlCompilar = String.fromEnvironment('API_BASE');

  static String _base = _predeterminada();

  static String get base => _base;

  /// true cuando no hay servidor configurado: la app arranca en modo
  /// demostración sin esperar tiempos de espera de red.
  static bool get sinServidor => _base.isEmpty;

  /// Permite cambiar el servidor en tiempo de ejecución (pantalla Ajustes).
  static set base(String valor) {
    _base = _limpiar(valor);
    traza.datos('ApiConfig', 'Servidor cambiado a $_base');
  }

  static String _limpiar(String valor) =>
      valor.trim().replaceAll(RegExp(r'/+$'), '');

  static String _predeterminada() {
    // 1. Definida al compilar.
    if (definidaAlCompilar.isNotEmpty) return _limpiar(definidaAlCompilar);

    if (kIsWeb) {
      // 2. ?api= en la URL de la página.
      final deUrl = Uri.base.queryParameters['api'];
      if (deUrl != null && deUrl.trim().isNotEmpty) return _limpiar(deUrl);

      // 3. Solo se asume localhost cuando la app se sirve desde el PC.
      final host = Uri.base.host;
      final esLocal = host == 'localhost' || host == '127.0.0.1' || host.isEmpty;
      return esLocal ? 'http://localhost:$puerto' : '';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$puerto';
    }
    return 'http://localhost:$puerto';
  }
}

/// Cliente HTTP de la API de SaludCuidado.
///
/// Responsabilidades:
///   - componer las URL y adjuntar el token de sesión
///   - imponer un tiempo máximo de espera a cada petición
///   - traducir fallos de red y errores HTTP a excepciones tipadas
///   - registrar cada llamada en la traza de la aplicación
class ApiCliente {
  static const String _origen = 'ApiCliente';
  static const Duration _tiempoMaximo = Duration(seconds: 10);

  final http.Client _http;

  ApiCliente({http.Client? cliente}) : _http = cliente ?? http.Client();

  /// Token de sesión devuelto por /api/auth/login o /api/auth/registro.
  String? token;

  bool get autenticado => token != null;

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String ruta, [Map<String, String>? query]) {
    final limpia = ruta.startsWith('/') ? ruta : '/$ruta';
    return Uri.parse('${ApiConfig.base}$limpia').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  // ------------------------------------------------------------- verbos

  Future<Map<String, dynamic>> obtener(
    String ruta, {
    Map<String, String>? query,
  }) =>
      _enviar('GET', ruta, query: query);

  Future<Map<String, dynamic>> publicar(String ruta, Object cuerpo) =>
      _enviar('POST', ruta, cuerpo: cuerpo);

  Future<Map<String, dynamic>> parchear(String ruta, Object cuerpo) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo);

  /// PUT: reemplaza el recurso completo (usado por la API de administración).
  Future<Map<String, dynamic>> actualizar(String ruta, Object cuerpo) =>
      _enviar('PUT', ruta, cuerpo: cuerpo);

  Future<Map<String, dynamic>> eliminar(String ruta) =>
      _enviar('DELETE', ruta);

  // ------------------------------------------------------------- interno

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
  }) async {
    if (ApiConfig.sinServidor) {
      // Sin servidor configurado no se intenta la petición: la app entra en
      // modo demostración de inmediato, sin esperar el tiempo máximo.
      throw const SinConexion('No hay un servidor configurado.');
    }

    final uri = _uri(ruta, query);
    final inicio = DateTime.now();

    try {
      final http.Response res;
      final cuerpoJson = cuerpo == null ? null : jsonEncode(cuerpo);

      switch (metodo) {
        case 'POST':
          res = await _http
              .post(uri, headers: _cabeceras, body: cuerpoJson)
              .timeout(_tiempoMaximo);
        case 'PATCH':
          res = await _http
              .patch(uri, headers: _cabeceras, body: cuerpoJson)
              .timeout(_tiempoMaximo);
        case 'PUT':
          res = await _http
              .put(uri, headers: _cabeceras, body: cuerpoJson)
              .timeout(_tiempoMaximo);
        case 'DELETE':
          res = await _http
              .delete(uri, headers: _cabeceras)
              .timeout(_tiempoMaximo);
        default:
          res = await _http.get(uri, headers: _cabeceras).timeout(_tiempoMaximo);
      }

      final ms = DateTime.now().difference(inicio).inMilliseconds;
      traza.datos(_origen, '$metodo ${uri.path} -> ${res.statusCode} (${ms}ms)');

      final texto = utf8.decode(res.bodyBytes);
      final decodificado = texto.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(texto) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return decodificado;
      }

      // Error con el formato { "error": { "codigo", "mensaje" } }.
      final err = decodificado['error'];
      final codigo = err is Map ? (err['codigo'] as String? ?? 'error') : 'error';
      final mensaje = err is Map
          ? (err['mensaje'] as String? ?? 'Error desconocido')
          : 'Error ${res.statusCode}';
      traza.error(_origen, '$metodo ${uri.path} falló: $mensaje');
      throw ApiExcepcion(res.statusCode, codigo, mensaje);
    } on ApiExcepcion {
      rethrow;
    } on TimeoutException {
      traza.error(_origen, '$metodo ${uri.path}: tiempo de espera agotado');
      throw const SinConexion('El servidor tardó demasiado en responder.');
    } on SocketException catch (e) {
      traza.error(_origen, '$metodo ${uri.path}: sin conexión (${e.message})');
      throw SinConexion('No se pudo conectar con el servidor. ${e.message}');
    } catch (e) {
      // En web un fallo de red llega como ClientException, no SocketException.
      traza.error(_origen, '$metodo ${uri.path}: $e');
      throw const SinConexion('No se pudo conectar con el servidor.');
    }
  }

  /// Comprueba si la API responde. Usado al arrancar para decidir si se
  /// trabaja en línea o con los datos locales de respaldo.
  Future<bool> disponible() async {
    try {
      await obtener('/api/salud');
      return true;
    } catch (_) {
      return false;
    }
  }

  void cerrar() => _http.close();
}
