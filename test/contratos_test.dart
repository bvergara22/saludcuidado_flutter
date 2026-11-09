import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saludcuidado/core/fechas.dart';
import 'package:saludcuidado/data/app_state.dart';
import 'package:saludcuidado/data/horarios_service.dart';
import 'package:saludcuidado/data/sample_data.dart';
import 'package:saludcuidado/models/cita.dart';
import 'package:saludcuidado/models/estado_cita.dart';
import 'package:saludcuidado/screens/login_screen.dart';
import 'package:saludcuidado/screens/registro_screen.dart';

/// Pruebas que verifican, una a una, las clausulas "Garantiza" y "Falla si"
/// de los contratos del documento entregables-mocks-movil2.pdf.
void main() {
  group('Contrato EstadoCita (PDF 1.1)', () {
    test('tiene exactamente los 3 valores del contrato', () {
      expect(EstadoCita.values, hasLength(3));
      expect(
        EstadoCita.values.map((e) => e.name),
        containsAll(['proxima', 'completada', 'cancelada']),
      );
    });

    test('mapea los estados del backend Spring Boot', () {
      expect(EstadoCita.desdeBackend('PROGRAMADA'), EstadoCita.proxima);
      expect(EstadoCita.desdeBackend('COMPLETADA'), EstadoCita.completada);
      expect(EstadoCita.desdeBackend('CANCELADA'), EstadoCita.cancelada);
      expect(EstadoCita.proxima.estadoBackend, 'PROGRAMADA');
    });
  });

  group('Contrato Doctor (PDF 1.1)', () {
    test('todos los doctores de ejemplo tienen sus campos accesibles', () {
      expect(sampleDoctors, isNotEmpty);
      for (final d in sampleDoctors) {
        expect(d.id, isNotEmpty);
        expect(d.nombre, isNotEmpty);
        expect(d.especialidad, isNotEmpty);
        expect(d.iniciales.length, inInclusiveRange(1, 3));
        expect(d.rating, inInclusiveRange(0.0, 5.0));
        expect(d.experiencia, greaterThan(0));
        expect(d.clinica, isNotEmpty);
        expect(d.descripcion, isNotEmpty);
        expect(d.color, isA<Color>());
        expect(d.horariosDisponibles, isNotEmpty);
      }
    });

    test('los horarios del doctor pertenecen a la rejilla 07:00-19:00', () {
      for (final d in sampleDoctors) {
        for (final h in d.horariosDisponibles) {
          expect(horariosBase, contains(h),
              reason: '$h no esta en la rejilla de 30 minutos');
        }
      }
    });
  });

  group('Contrato LoginScreen (PDF 1.2)', () {
    test('Falla si: email vacio', () {
      expect(LoginScreen.validarEmail(''), isNotNull);
      expect(LoginScreen.validarEmail('   '), isNotNull);
    });

    test('Falla si: contrasena menor a 6 caracteres', () {
      expect(LoginScreen.validarPassword('12345'), isNotNull);
      expect(LoginScreen.validarPassword('123456'), isNull);
    });

    test('Garantiza: credenciales validas pasan la validacion', () {
      expect(LoginScreen.validarEmail('juan.perez@email.com'), isNull);
      expect(LoginScreen.validarPassword('secreto123'), isNull);
    });
  });

  group('Contrato RegistroScreen (PDF 1.2)', () {
    test('Falla si: campos vacios', () {
      expect(RegistroScreen.validarNombre(''), isNotNull);
      expect(RegistroScreen.validarEmail(''), isNotNull);
      expect(RegistroScreen.validarPassword(''), isNotNull);
    });

    test('Falla si: contrasena menor al minimo del mock (8)', () {
      expect(RegistroScreen.validarPassword('1234567'), isNotNull);
      expect(RegistroScreen.validarPassword('12345678'), isNull);
    });
  });

  group('Contrato MisCitasScreen / AppState (PDF 1.2)', () {
    test('filtra las citas por EstadoCita en las 3 pestanas', () {
      final estado = AppState.local();
      final total = estado.totalCitas;
      final suma = estado.totalProximas +
          estado.totalCompletadas +
          estado.totalCanceladas;
      expect(suma, total);
    });

    test('Garantiza: cancelar una cita proxima la pasa a cancelada', () async {
      final estado = AppState.local();
      final proxima = estado.porEstado(EstadoCita.proxima).first;
      final cancelasAntes = estado.totalCanceladas;

      expect(await estado.cancelarCita(proxima.id), isTrue);
      expect(estado.totalCanceladas, cancelasAntes + 1);
      expect(
        estado.citas.firstWhere((c) => c.id == proxima.id).estado,
        EstadoCita.cancelada,
      );
    });

    test('no permite cancelar una cita que ya esta completada', () async {
      final estado = AppState.local();
      final completada = estado.porEstado(EstadoCita.completada).first;
      expect(await estado.cancelarCita(completada.id), isFalse);
    });
  });

  group('Contrato PerfilScreen (PDF 1.2)', () {
    test('Falla si: estadisticas en 0 cuando no hay citas', () async {
      final estado = AppState.local();
      for (final c in [...estado.citas]) {
        await estado.cancelarCita(c.id);
      }
      // Tras cancelar todo, no deben quedar proximas.
      expect(estado.totalProximas, 0);
      expect(estado.proximaCita, isNull);
    });
  });

  group('Reglas de horarios (trazadas desde CitaService.java)', () {
    test('la rejilla base va de 07:00 a 19:00 cada 30 minutos', () {
      expect(horariosBase.first, '07:00');
      expect(horariosBase.last, '19:00');
      expect(horariosBase, hasLength(25));
      for (var i = 1; i < horariosBase.length; i++) {
        final previo = Fechas.horaAMinutos(horariosBase[i - 1]);
        final actual = Fechas.horaAMinutos(horariosBase[i]);
        expect(actual - previo, 30);
      }
    });

    test('un horario ocupado deja de estar disponible', () {
      final doctor = sampleDoctors.first;
      final fecha = DateTime.now().add(const Duration(days: 3));
      final hora = doctor.horariosDisponibles.first;

      final sinCitas = HorariosService.disponibles(
        doctor: doctor,
        fecha: fecha,
        citasExistentes: const [],
      );
      expect(sinCitas, contains(hora));

      final ocupada = Cita(
        id: 'tmp',
        doctor: doctor,
        fecha: fecha,
        hora: hora,
        estado: EstadoCita.proxima,
      );
      final conCita = HorariosService.disponibles(
        doctor: doctor,
        fecha: fecha,
        citasExistentes: [ocupada],
      );
      expect(conCita, isNot(contains(hora)));
    });

    test('una cita cancelada libera de nuevo el horario', () {
      final doctor = sampleDoctors.first;
      final fecha = DateTime.now().add(const Duration(days: 4));
      final hora = doctor.horariosDisponibles.first;

      final cancelada = Cita(
        id: 'tmp2',
        doctor: doctor,
        fecha: fecha,
        hora: hora,
        estado: EstadoCita.cancelada,
      );
      final disponibles = HorariosService.disponibles(
        doctor: doctor,
        fecha: fecha,
        citasExistentes: [cancelada],
      );
      expect(disponibles, contains(hora));
    });

    test('los dias seleccionables excluyen domingos', () {
      final dias = HorariosService.diasSeleccionables(cantidad: 14);
      expect(dias, hasLength(14));
      for (final d in dias) {
        expect(d.weekday, isNot(DateTime.sunday));
      }
    });
  });

  group('Contrato ReservarScreen / AppState (PDF 1.2)', () {
    test('Garantiza: reservar crea una cita en estado proxima', () async {
      final estado = AppState.local();
      final doctor = sampleDoctors[1];
      final fecha = DateTime.now().add(const Duration(days: 6));
      final hora = doctor.horariosDisponibles.first;

      final cita = await estado.reservarCita(
        doctor: doctor,
        fecha: fecha,
        hora: hora,
      );

      expect(cita, isNotNull);
      expect(cita!.estado, EstadoCita.proxima);
      expect(cita.doctor.id, doctor.id);
      expect(estado.citas, contains(cita));
    });

    test('no permite reservar dos veces el mismo horario', () async {
      final estado = AppState.local();
      final doctor = sampleDoctors[2];
      final fecha = DateTime.now().add(const Duration(days: 8));
      final hora = doctor.horariosDisponibles.first;

      expect(
        await estado.reservarCita(doctor: doctor, fecha: fecha, hora: hora),
        isNotNull,
      );
      // Segunda reserva en el mismo slot: debe rechazarse.
      expect(
        await estado.reservarCita(doctor: doctor, fecha: fecha, hora: hora),
        isNull,
      );
    });
  });

  group('Utilidades de fecha', () {
    test('convierte a formato de 12 horas', () {
      expect(Fechas.hora12('07:00'), '7:00 AM');
      expect(Fechas.hora12('12:30'), '12:30 PM');
      expect(Fechas.hora12('14:30'), '2:30 PM');
      expect(Fechas.hora12('19:00'), '7:00 PM');
    });

    test('genera la clave ISO igual que LocalDate del backend', () {
      expect(Fechas.iso(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });
}
