import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/trace/trace_logger.dart';
import '../data/preferencias.dart';

/// Resultado de un intento de desbloqueo, para que la interfaz pueda
/// decir qué pasó en lugar de limitarse a no dejar entrar.
enum ResultadoBiometria {
  concedido,
  denegado,
  noDisponible,
  sinRegistrar,
  bloqueado,
  error;

  String get mensaje => switch (this) {
        ResultadoBiometria.concedido => 'Identidad verificada.',
        ResultadoBiometria.denegado => 'No se verificó tu identidad.',
        ResultadoBiometria.noDisponible =>
          'Este dispositivo no tiene lector biométrico.',
        ResultadoBiometria.sinRegistrar =>
          'No tienes huella ni rostro registrados en el teléfono.',
        ResultadoBiometria.bloqueado =>
          'Demasiados intentos fallidos. Desbloquea el teléfono y repite.',
        ResultadoBiometria.error => 'No se pudo verificar tu identidad.',
      };
}

/// Desbloqueo de la sesión con huella o rostro.
///
/// CONTRATO: Biometria
///   Requiere : un dispositivo con sensor y al menos una huella o rostro
///              registrados en el sistema
///   Garantiza: [verificar] devuelve `concedido` solo si el sistema
///              operativo confirmó la identidad
///   Falla si : no hay sensor, no hay nada registrado o la persona cancela
///              -> el valor correspondiente de [ResultadoBiometria], nunca
///              una excepción
///
/// Importante, y conviene decirlo en la sustentación: esto **no** sustituye
/// al inicio de sesión. La contraseña sigue siendo lo que autentica contra
/// el servidor; la huella solo protege la sesión ya guardada en este
/// teléfono, que es exactamente el papel que cumple en un banco o en una
/// app de salud. El token nunca se deriva de la huella.
class Biometria {
  Biometria._();

  static final Biometria yo = Biometria._();

  static const String _origen = 'Biometria';

  final LocalAuthentication _auth = LocalAuthentication();

  /// La web no expone un API de biometría comparable.
  bool get soportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// true si el aparato tiene sensor y hay algo registrado en el sistema.
  Future<bool> get disponible async {
    if (!soportada) return false;
    try {
      final hay = await _auth.canCheckBiometrics;
      final soportaDispositivo = await _auth.isDeviceSupported();
      return hay && soportaDispositivo;
    } on PlatformException catch (e) {
      traza.error(_origen, 'Consulta de disponibilidad fallida: ${e.code}');
      return false;
    }
  }

  /// Tipos registrados, para poder decir "huella" o "rostro" en la UI en
  /// lugar de un genérico "biometría".
  Future<List<BiometricType>> get tipos async {
    if (!soportada) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Nombre legible de lo que tiene configurado este teléfono.
  Future<String> get descripcion async {
    final lista = await tipos;
    if (lista.contains(BiometricType.face)) return 'reconocimiento facial';
    if (lista.contains(BiometricType.fingerprint)) return 'huella digital';
    if (lista.contains(BiometricType.iris)) return 'iris';
    if (lista.isNotEmpty) return 'biometría del dispositivo';
    return 'sin biometría registrada';
  }

  /// true cuando la persona la activó en Ajustes y el aparato la soporta.
  Future<bool> get activa async =>
      Preferencias.yo.biometriaActiva && await disponible;

  /// CONTRATO: verificar
  ///   Requiere : [razon] explica a la persona para qué se le pide
  ///   Garantiza: `concedido` solo tras confirmación del sistema operativo
  ///   Falla si : ver [ResultadoBiometria]
  Future<ResultadoBiometria> verificar({
    String razon = 'Confirma tu identidad para entrar a SaludCuidado',
  }) async {
    if (!soportada) return ResultadoBiometria.noDisponible;
    try {
      final ok = await _auth.authenticate(
        localizedReason: razon,
        // Solo biometría: si se permitiera el PIN del teléfono, esto
        // dejaría de ser un factor distinto de la contraseña.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      traza.accion(
        _origen,
        'Verificación biométrica ${ok ? "concedida" : "rechazada"}',
        contrato: 'Biometria.Garantiza',
      );
      return ok ? ResultadoBiometria.concedido : ResultadoBiometria.denegado;
    } on LocalAuthException catch (e) {
      // local_auth 3 devuelve códigos tipados, así que cada motivo se
      // puede explicar en lugar de mostrar un error genérico.
      final resultado = switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable =>
          ResultadoBiometria.noDisponible,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          ResultadoBiometria.sinRegistrar,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          ResultadoBiometria.bloqueado,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          ResultadoBiometria.denegado,
        _ => ResultadoBiometria.error,
      };
      traza.error(
          _origen, 'Verificación fallida (${e.code.name}): ${resultado.name}');
      return resultado;
    }
  }

  /// Activa o desactiva el desbloqueo, pidiendo la huella antes de
  /// activarlo: no tiene sentido encender un candado cuya llave no se ha
  /// comprobado que funcione.
  Future<ResultadoBiometria> cambiar(bool activar) async {
    if (!activar) {
      await Preferencias.yo.guardarBiometria(false);
      return ResultadoBiometria.concedido;
    }
    if (!await disponible) {
      return soportada
          ? ResultadoBiometria.sinRegistrar
          : ResultadoBiometria.noDisponible;
    }
    final r = await verificar(
      razon: 'Confirma tu huella para activar el desbloqueo',
    );
    if (r == ResultadoBiometria.concedido) {
      await Preferencias.yo.guardarBiometria(true);
    }
    return r;
  }
}
