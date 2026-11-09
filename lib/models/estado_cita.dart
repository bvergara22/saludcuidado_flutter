import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// CONTRATO: EstadoCita (PDF 1.1)
///   Requiere : uno de los valores { proxima | completada | cancelada }
///   Garantiza: clasificacion de la cita para filtrado y visualizacion
///   Falla si : se asigna un valor fuera del enum -> error de compilacion
///
/// Trazabilidad backend: Cita.estado (String) = PROGRAMADA | COMPLETADA | CANCELADA
enum EstadoCita {
  proxima,
  completada,
  cancelada;

  /// Etiqueta visible en UI.
  String get etiqueta {
    switch (this) {
      case EstadoCita.proxima:
        return 'Próxima';
      case EstadoCita.completada:
        return 'Completada';
      case EstadoCita.cancelada:
        return 'Cancelada';
    }
  }

  /// Nombre de la pestaña en MisCitasScreen.
  String get etiquetaPlural {
    switch (this) {
      case EstadoCita.proxima:
        return 'Próximas';
      case EstadoCita.completada:
        return 'Completadas';
      case EstadoCita.cancelada:
        return 'Canceladas';
    }
  }

  Color get color {
    switch (this) {
      case EstadoCita.proxima:
        return AppColors.primary;
      case EstadoCita.completada:
        // Completada usa un verde más oscuro para distinguirse del primario.
        return AppColors.primaryDeep;
      case EstadoCita.cancelada:
        return AppColors.peligro;
    }
  }

  IconData get icono {
    switch (this) {
      case EstadoCita.proxima:
        return Icons.schedule_rounded;
      case EstadoCita.completada:
        return Icons.check_circle_outline_rounded;
      case EstadoCita.cancelada:
        return Icons.cancel_outlined;
    }
  }

  /// Mensaje mostrado cuando la pestaña no tiene citas.
  /// CONTRATO MisCitasScreen: "pestaña vacía muestra mensaje informativo".
  String get mensajeVacio {
    switch (this) {
      case EstadoCita.proxima:
        return 'No tienes citas próximas.\nReserva una nueva cita para comenzar.';
      case EstadoCita.completada:
        return 'Aún no tienes citas completadas.';
      case EstadoCita.cancelada:
        return 'No has cancelado ninguna cita.';
    }
  }

  /// Equivalente en el backend Spring Boot (ejemplo_99 / Cita.estado).
  String get estadoBackend {
    switch (this) {
      case EstadoCita.proxima:
        return 'PROGRAMADA';
      case EstadoCita.completada:
        return 'COMPLETADA';
      case EstadoCita.cancelada:
        return 'CANCELADA';
    }
  }

  /// Mapea el estado del backend al enum movil.
  static EstadoCita desdeBackend(String estado) {
    switch (estado.toUpperCase()) {
      case 'COMPLETADA':
        return EstadoCita.completada;
      case 'CANCELADA':
        return EstadoCita.cancelada;
      case 'PROGRAMADA':
      default:
        return EstadoCita.proxima;
    }
  }
}
