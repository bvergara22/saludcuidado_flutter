import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcuidado/data/api/repositorio.dart';
import 'package:saludcuidado/data/preferencias.dart';
import 'package:saludcuidado/models/cita.dart';
import 'package:saludcuidado/models/doctor.dart';
import 'package:saludcuidado/models/estado_cita.dart';
import 'package:saludcuidado/models/usuario.dart';
import 'package:saludcuidado/servicios/notificaciones.dart';

/// Pruebas de las integraciones con el dispositivo.
///
/// Lo que se comprueba aquí es la lógica que NO depende del sistema
/// operativo: la ida y vuelta de los modelos (de la que vive el caché sin
/// conexión), el cálculo de caducidad de una cita y la derivación de los
/// identificadores de aviso. Los permisos y el lector de huella no se
/// pueden simular en una prueba de widget, así que esos quedan para la
/// comprobación manual en el teléfono.
void main() {
  const doctor = Doctor(
    id: 'doc-001',
    nombre: 'Dra. Ana García',
    especialidad: 'Pediatría',
    iniciales: 'AG',
    rating: 4.8,
    experiencia: 8,
    clinica: 'Clínica SaludCuidado - Sede Centro',
    descripcion: 'Pediatra.',
    color: Color(0xFF7C3AED),
    horariosDisponibles: ['09:00', '09:30'],
    avatarSemilla: 42,
    titulo: 'Dra.',
    nombrePila: 'Ana',
    apellido: 'García',
    correo: 'ana@saludcuidado.com',
    telefono: '555-1234',
  );

  group('Caché: los modelos van y vuelven sin perder nada', () {
    test('Garantiza: Doctor.desdeJson(d.aJson()) devuelve el mismo doctor',
        () {
      final vuelta = Doctor.desdeJson(doctor.aJson());

      expect(vuelta.id, doctor.id);
      expect(vuelta.nombre, doctor.nombre);
      expect(vuelta.especialidad, doctor.especialidad);
      expect(vuelta.rating, doctor.rating);
      expect(vuelta.experiencia, doctor.experiencia);
      expect(vuelta.clinica, doctor.clinica);
      expect(vuelta.color.toARGB32(), doctor.color.toARGB32());
      expect(vuelta.horariosDisponibles, doctor.horariosDisponibles);
      expect(vuelta.avatarSemilla, doctor.avatarSemilla);
      // Los campos sueltos del panel de administración también vuelven.
      expect(vuelta.titulo, 'Dra.');
      expect(vuelta.correo, 'ana@saludcuidado.com');
    });

    test('Garantiza: una cita vuelve con su doctor, su estado y su hora', () {
      final cita = Cita(
        id: 'cita-1',
        doctor: doctor,
        fecha: DateTime(2026, 11, 20),
        hora: '09:30',
        estado: EstadoCita.cancelada,
        servicio: 'Pediatría',
      );

      final vuelta = Cita.desdeJson(cita.aJson());

      expect(vuelta.id, 'cita-1');
      expect(vuelta.doctor.id, doctor.id);
      expect(vuelta.fecha, DateTime(2026, 11, 20));
      expect(vuelta.hora, '09:30');
      expect(vuelta.estado, EstadoCita.cancelada);
      expect(vuelta.servicio, 'Pediatría');
    });

    test('Garantiza: el servicio conserva su icono al volver del disco', () {
      // El icono no se puede serializar: viaja el nombre y se vuelve a
      // resolver con el mismo catálogo que usa la API.
      final original = Repositorio.servicioDesdeJson(const {
        'id': 'srv-003',
        'nombre': 'Pediatría',
        'descripcion': 'Control de niño sano.',
        'duracionMinutos': 45,
        'icono': 'child',
        'color': 0xFF7C3AED,
      });

      final vuelta = Repositorio.servicioDesdeJson(original.aJson());

      expect(vuelta.id, 'srv-003');
      expect(vuelta.duracionMinutos, 45);
      expect(vuelta.iconoNombre, 'child');
      expect(vuelta.icono, Icons.child_care_outlined);
      expect(vuelta.icono, original.icono);
    });

    test('Garantiza: el usuario guardado conserva sus roles', () {
      const admin = Usuario(
        nombre: 'Administrador',
        email: 'admin@saludcuidado.com',
        iniciales: 'AD',
        roles: ['ROLE_USER', 'ROLE_ADMIN'],
      );

      final vuelta = Usuario.desdeJson(admin.aJson());

      expect(vuelta.email, 'admin@saludcuidado.com');
      expect(vuelta.esAdmin, isTrue);
    });
  });

  group('Citas vencidas', () {
    Cita conFechaHora(DateTime f, String h, EstadoCita e) => Cita(
          id: 'c-${f.day}$h',
          doctor: doctor,
          fecha: f,
          hora: h,
          estado: e,
        );

    final referencia = DateTime(2026, 11, 18, 12, 0);

    test('Garantiza: PROGRAMADA con la hora pasada está vencida', () {
      final ayer =
          conFechaHora(DateTime(2026, 11, 17), '10:00', EstadoCita.proxima);
      expect(ayer.vencidaA(referencia), isTrue);
    });

    test('Garantiza: PROGRAMADA en el futuro no está vencida', () {
      final manana =
          conFechaHora(DateTime(2026, 11, 19), '09:00', EstadoCita.proxima);
      expect(manana.vencidaA(referencia), isFalse);
    });

    test('Garantiza: el corte es la hora, no solo el día', () {
      final hoyTemprano =
          conFechaHora(DateTime(2026, 11, 18), '09:00', EstadoCita.proxima);
      final hoyTarde =
          conFechaHora(DateTime(2026, 11, 18), '16:00', EstadoCita.proxima);

      expect(hoyTemprano.vencidaA(referencia), isTrue);
      expect(hoyTarde.vencidaA(referencia), isFalse);
    });

    test('Falla si: una cancelada o completada nunca cuenta como vencida',
        () {
      final cancelada =
          conFechaHora(DateTime(2026, 11, 10), '10:00', EstadoCita.cancelada);
      final completada =
          conFechaHora(DateTime(2026, 11, 10), '10:00', EstadoCita.completada);

      expect(cancelada.vencidaA(referencia), isFalse);
      expect(completada.vencidaA(referencia), isFalse);
    });

    test('Garantiza: momento combina fecha y hora', () {
      final c =
          conFechaHora(DateTime(2026, 11, 20), '09:30', EstadoCita.proxima);
      expect(c.momento, DateTime(2026, 11, 20, 9, 30));
    });
  });

  group('Recordatorios', () {
    test('Garantiza: el id de aviso es estable para la misma cita', () {
      final a = Notificaciones.idAviso('cita-123', 0);
      final b = Notificaciones.idAviso('cita-123', 0);
      expect(a, b, reason: 'Sin esto no se podría cancelar un aviso después');
    });

    test('Garantiza: los dos avisos de una cita no chocan entre sí', () {
      expect(
        Notificaciones.idAviso('cita-123', 0),
        isNot(Notificaciones.idAviso('cita-123', 1)),
      );
    });

    test('Garantiza: citas distintas no comparten identificador', () {
      expect(
        Notificaciones.idAviso('cita-123', 0),
        isNot(Notificaciones.idAviso('cita-124', 0)),
      );
    });

    test('Falla si: el identificador fuese negativo (el sistema lo rechaza)',
        () {
      for (final id in ['a', 'cita-999999999999', '', 'ñ-áé']) {
        for (var aviso = 0; aviso < 2; aviso++) {
          expect(Notificaciones.idAviso(id, aviso), greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('Preferencias sin almacenamiento', () {
    test('Garantiza: sin plataforma devuelve valores por defecto y no lanza',
        () {
      // Es el caso de una plataforma que no da almacenamiento: la app
      // tiene que seguir funcionando, solo que sin recordar nada.
      final vacias = Preferencias.vacia();

      expect(vacias.disponible, isFalse);
      expect(vacias.token, isNull);
      expect(vacias.usuario, isNull);
      expect(vacias.onboardingVisto, isFalse);
      expect(vacias.biometriaActiva, isFalse);
      expect(vacias.notificacionesActivas, isTrue);
      expect(vacias.tema, ModoTema.sistema);
      expect(vacias.citasEnCache, isEmpty);
      expect(vacias.fechaCache, isNull);
    });

    test('Garantiza: escribir sin almacenamiento no revienta', () async {
      final vacias = Preferencias.vacia();
      await vacias.guardarSesion('tok', const {'email': 'a@b.c'});
      await vacias.guardarCache(citas: const []);
      await vacias.borrarSesion();
      expect(vacias.token, isNull);
    });

    test('Garantiza: ModoTema se reconstruye desde el texto guardado', () {
      expect(ModoTema.desdeTexto('oscuro'), ModoTema.oscuro);
      expect(ModoTema.desdeTexto('claro'), ModoTema.claro);
      expect(ModoTema.desdeTexto(null), ModoTema.sistema);
      expect(ModoTema.desdeTexto('cualquier cosa'), ModoTema.sistema);
    });
  });
}
