import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcuidado/data/api/repositorio.dart';
import 'package:saludcuidado/data/app_state.dart';
import 'package:saludcuidado/models/cita.dart';
import 'package:saludcuidado/models/doctor.dart';
import 'package:saludcuidado/models/estado_cita.dart';
import 'package:saludcuidado/models/usuario.dart';
import 'package:saludcuidado/widgets/avatar_ilustrado.dart';

/// Pruebas de la capa que habla con el backend (SaludCuidado-backend).
///
/// Verifican los contratos de deserializacion: lo que la API promete
/// devolver es exactamente lo que los modelos saben leer, y una respuesta
/// incompleta falla de forma controlada en lugar de corromper la pantalla.
void main() {
  const doctorJson = <String, dynamic>{
    'id': 'doc-001',
    'nombre': 'Dr. Carlos Mendoza',
    'especialidad': 'Cardiología',
    'iniciales': 'CM',
    'rating': 4.9,
    'experiencia': 12,
    'clinica': 'Clínica Comfenalco',
    'descripcion': 'Especialista en cardiología clínica.',
    'color': 0xFF1A5FBF,
    'horariosDisponibles': ['07:00', '07:30', '08:00'],
    'avatarSemilla': 1234,
  };

  group('Contrato Doctor.desdeJson (GET /api/doctores)', () {
    test('lee todos los campos que envía el backend', () {
      final d = Doctor.desdeJson(doctorJson);

      expect(d.id, 'doc-001');
      expect(d.nombre, 'Dr. Carlos Mendoza');
      expect(d.especialidad, 'Cardiología');
      expect(d.rating, 4.9);
      expect(d.experiencia, 12);
      expect(d.color.toARGB32(), 0xFF1A5FBF);
      expect(d.horariosDisponibles, hasLength(3));
      expect(d.avatarSemilla, 1234);
      expect(d.fotoUrl, isNull);
    });

    test('usa valores por defecto cuando faltan campos opcionales', () {
      final d = Doctor.desdeJson(const {'id': 'doc-099'});

      expect(d.nombre, 'Doctor');
      expect(d.especialidad, 'General');
      expect(d.rating, 0);
      expect(d.horariosDisponibles, isEmpty);
      // Sin semilla explícita se deriva del id: el avatar sigue siendo
      // estable para ese doctor.
      expect(d.avatarSemilla, 'doc-099'.hashCode.abs());
    });
  });

  group('Contrato Cita.desdeJson (GET/POST /api/citas)', () {
    test('construye la cita con su doctor embebido', () {
      final c = Cita.desdeJson({
        'id': 'cita-001',
        'doctor': doctorJson,
        'fecha': '2026-11-20',
        'hora': '09:30',
        'estado': 'PROGRAMADA',
        'servicio': 'Cardiología',
      });

      expect(c.id, 'cita-001');
      expect(c.doctor.id, 'doc-001');
      expect(c.fecha, DateTime(2026, 11, 20));
      expect(c.hora, '09:30');
      expect(c.estado, EstadoCita.proxima);
      expect(c.claveSlot, '2026-11-20 09:30');
    });

    test('mapea los tres estados del backend', () {
      EstadoCita leer(String estado) => Cita.desdeJson({
            'id': 'x',
            'doctor': doctorJson,
            'fecha': '2026-11-20',
            'hora': '09:30',
            'estado': estado,
          }).estado;

      expect(leer('PROGRAMADA'), EstadoCita.proxima);
      expect(leer('COMPLETADA'), EstadoCita.completada);
      expect(leer('CANCELADA'), EstadoCita.cancelada);
    });

    test('Falla si: la cita llega sin doctor -> FormatException', () {
      expect(
        () => Cita.desdeJson({
          'id': 'cita-002',
          'fecha': '2026-11-20',
          'hora': '09:30',
          'estado': 'PROGRAMADA',
        }),
        throwsFormatException,
      );
    });

    test('Falla si: la fecha no es interpretable -> FormatException', () {
      expect(
        () => Cita.desdeJson({
          'id': 'cita-003',
          'doctor': doctorJson,
          'fecha': 'ayer',
          'hora': '09:30',
          'estado': 'PROGRAMADA',
        }),
        throwsFormatException,
      );
    });
  });

  group('Contrato Usuario.desdeJson (POST /api/auth/login)', () {
    test('lee el usuario y sus roles', () {
      final u = Usuario.desdeJson({
        'nombre': 'Brandon Llamas',
        'email': 'brandon@saludcuidado.com',
        'iniciales': 'BL',
        'avatarSemilla': 77,
        'roles': ['ROLE_USER', 'ROLE_ADMIN'],
      });

      expect(u.nombre, 'Brandon Llamas');
      expect(u.iniciales, 'BL');
      expect(u.avatarSemilla, 77);
      expect(u.esAdmin, isTrue);
    });

    test('deriva las iniciales si el backend no las envía', () {
      final u = Usuario.desdeJson({
        'nombre': 'Camilo Mackensie',
        'email': 'camilo@saludcuidado.com',
      });

      expect(u.iniciales, 'CM');
      expect(u.esAdmin, isFalse);
    });
  });

  group('Avatares ilustrados', () {
    test('la misma semilla produce siempre los mismos rasgos', () {
      final a = RasgosAvatar.desdeSemilla(1234);
      final b = RasgosAvatar.desdeSemilla(1234);

      expect(a.piel, b.piel);
      expect(a.cabello, b.cabello);
      expect(a.peinado, b.peinado);
      expect(a.gafas, b.gafas);
      expect(a.estetoscopio, b.estetoscopio);
    });

    test('semillas distintas generan variedad de peinados', () {
      final peinados = <int>{
        for (var s = 0; s < 60; s++) RasgosAvatar.desdeSemilla(s).peinado,
      };
      // Los 5 peinados deben aparecer en un grupo pequeño de semillas.
      expect(peinados.length, 5);
    });

    test('el peinado siempre está dentro del rango dibujable', () {
      for (var s = 0; s < 500; s++) {
        final r = RasgosAvatar.desdeSemilla(s);
        expect(r.peinado, inInclusiveRange(0, 4));
      }
    });
  });

  group('AppState en modo local (sin servidor)', () {
    test('avisa de que trabaja con datos de demostración', () {
      final estado = AppState();
      // Recién creado, todavía no se ha comprobado el servidor.
      expect(estado.enLinea, isFalse);
      expect(estado.avisoSinConexion, isNotNull);
    });

    test('el modo local no muestra el aviso de sin conexión', () {
      final estado = AppState.local();
      expect(estado.soloLocal, isTrue);
      expect(estado.avisoSinConexion, isNull);
      expect(estado.doctores, isNotEmpty);
      expect(estado.servicios, isNotEmpty);
    });

    test('las especialidades incluyen "Todas" y no se repiten', () {
      final estado = AppState.local();
      final lista = estado.especialidadesDisponibles;

      expect(lista.first, 'Todas');
      expect(lista.toSet().length, lista.length);
    });

    test('filtrarDoctores combina especialidad y texto', () {
      final estado = AppState.local();
      final cardiologos =
          estado.filtrarDoctores(especialidad: 'Cardiología');

      expect(cardiologos, isNotEmpty);
      expect(
        cardiologos.every((d) => d.especialidad == 'Cardiología'),
        isTrue,
      );
      expect(estado.filtrarDoctores(texto: 'zzzz'), isEmpty);
    });
  });

  // ------------------------------------------- API de administración
  // La API de administración (/api/admin/**) devuelve más campos que la
  // pública: los datos sueltos del doctor (para poder editarlos por
  // partes) y el paciente dueño de cada cita.
  group('Contratos de la API de administración', () {
    const doctorAdminJson = <String, dynamic>{
      'id': 'doc-001',
      'nombre': 'Dra. Laura Pérez',
      'nombrePila': 'Laura',
      'apellido': 'Pérez',
      'titulo': 'Dra.',
      'especialidad': 'Cardiología',
      'correo': 'laura@saludcuidado.com',
      'telefono': '3001234567',
      'rating': 4.8,
      'experiencia': 12,
      'clinica': 'Sede Norte',
      'descripcion': 'Cardióloga',
      'color': 0xFFE11D48,
      'horariosDisponibles': ['08:00', '09:00'],
    };

    test('Garantiza: el doctor del panel trae sus campos por separado', () {
      final d = Doctor.desdeJson(doctorAdminJson);

      // El nombre compuesto se sigue usando en las listas...
      expect(d.nombre, 'Dra. Laura Pérez');
      // ...y las partes permiten rellenar el formulario de edición.
      expect(d.titulo, 'Dra.');
      expect(d.nombrePila, 'Laura');
      expect(d.apellido, 'Pérez');
      expect(d.correo, 'laura@saludcuidado.com');
      expect(d.telefono, '3001234567');
    });

    test('Garantiza: sin esos campos el doctor sigue siendo válido', () {
      // Esto es lo que recibe el paciente en /api/doctores.
      final d = Doctor.desdeJson(doctorJson);

      expect(d.nombrePila, isNull);
      expect(d.apellido, isNull);
      expect(d.correo, isNull);
      expect(d.nombre, isNotEmpty);
    });

    test('Garantiza: la cita de administración identifica al paciente', () {
      final cita = Cita.desdeJson({
        'id': 'cita-100',
        'fecha': '2026-12-01',
        'hora': '10:00',
        'estado': 'PROGRAMADA',
        'servicio': 'Cardiología',
        'doctor': doctorAdminJson,
        'paciente': {
          'id': 2,
          'nombre': 'Brandon Llamas',
          'email': 'brandon@saludcuidado.com',
          'avatarSemilla': 77,
        },
      });

      expect(cita.pacienteNombre, 'Brandon Llamas');
      expect(cita.pacienteEmail, 'brandon@saludcuidado.com');
      expect(cita.pacienteSemilla, 77);
    });

    test('Garantiza: la cita del paciente no trae paciente y no falla', () {
      final cita = Cita.desdeJson({
        'id': 'cita-101',
        'fecha': '2026-12-02',
        'hora': '11:00',
        'estado': 'PROGRAMADA',
        'doctor': doctorAdminJson,
      });

      expect(cita.pacienteNombre, isNull);
      expect(cita.pacienteSemilla, 0);
    });

    test('Garantiza: el nombre de icono del backend se traduce a IconData',
        () {
      final s = Repositorio.servicioDesdeJson({
        'id': 'srv-004',
        'nombre': 'Cardiología',
        'descripcion': 'Control cardiovascular',
        'duracionMinutos': 40,
        'icono': 'heart',
        'color': 0xFFE11D48,
      });

      expect(s.icono, Repositorio.iconosServicio['heart']);
      expect(s.color, const Color(0xFFE11D48));
      expect(s.duracionMinutos, 40);
    });

    test('Falla si: un icono desconocido no rompe la pantalla', () {
      // Un servicio creado en el panel con un icono que esta versión de la
      // app no conoce debe seguir siendo usable.
      final s = Repositorio.servicioDesdeJson({
        'id': 'srv-099',
        'nombre': 'Nutrición',
        'icono': 'no-existe-este-icono',
      });

      expect(s.icono, Icons.local_hospital_outlined);
      expect(s.nombre, 'Nutrición');
      expect(s.duracionMinutos, 30);
    });
  });
}
