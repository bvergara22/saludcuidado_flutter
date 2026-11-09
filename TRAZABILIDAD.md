# Matriz de trazabilidad — SaludCuidado

Relaciona cada elemento del documento **`entregables-mocks-movil2.pdf`** y del
backend **`ejemplo_99` (Spring Boot)** con el código Flutter que lo implementa y
con la prueba que lo verifica.

Leyenda: ✅ implementado y probado · ⚪ implementado sin prueba automática

Cobertura: **42 pruebas** automatizadas — `test/contratos_test.dart` (21, contratos
del PDF) y `test/api_test.dart` (21: capa de API, serialización, avatares y la
API de administración).
El sistema son dos proyectos: la app (`SaludCuidado-flutter`) y la API con base
de datos SQLite (`SaludCuidado-backend`), cuyo mapeo con el dominio Java está en
la §4.

---

## 1. Contratos de modelos de datos (PDF §1.1)

| Contrato | Implementación | Cómo se cumple | Prueba |
|---|---|---|---|
| **Doctor** · *Requiere*: id, nombre, especialidad, iniciales, rating, experiencia, clinica, descripcion, color, horariosDisponibles | `lib/models/doctor.dart` | Campos `final` no-nullable + constructor `const` con `required` | ✅ `Contrato Doctor` |
| **Doctor** · *Falla si*: algún campo null → error de compilación | `lib/models/doctor.dart` | Null-safety: omitir un `required` no compila | ✅ (garantía del compilador) |
| **Cita** · *Requiere*: id, doctor (Doctor existente), fecha, hora, estado | `lib/models/cita.dart` | `final Doctor doctor` no-nullable | ✅ `Contrato ReservarScreen` |
| **Cita** · *Garantiza*: objeto válido enlazado a un doctor | `lib/models/cita.dart` | El doctor se embebe como objeto, no como id suelto | ✅ |
| **EstadoCita** · 3 valores: proxima \| completada \| cancelada | `lib/models/estado_cita.dart` | `enum EstadoCita` + extensiones de etiqueta, color e icono | ✅ `Contrato EstadoCita` |
| **EstadoCita** · *Garantiza*: clasificación para filtrado y visualización | `estado_cita.dart` → `etiquetaPlural`, `color`, `icono`, `mensajeVacio` | Consumido por `MisCitasScreen` y `EstadoBadge` | ✅ |

---

## 2. Contratos de pantallas (PDF §1.2)

### SplashScreen
| Cláusula | Implementación |
|---|---|
| *Requiere*: ningún parámetro | `const SplashScreen()` |
| *Garantiza*: logo animado, navegación automática tras ~2.3 s | `splash_screen.dart` · `_espera = 2300 ms`, secuencia de 6 tramos encadenados, `pushReplacementNamed(destino)` |
| *Falla si*: desmontado antes de terminar → cancela navegación | `_continuar()` comprueba `if (!mounted) return;` y registra el evento en la traza ⚪ |

> ⚠️ **Desviación documentada.** El PDF fija el destino en `/login`. La
> implementación navega a `/onboarding` cuando la introducción no se ha visto,
> y esa pantalla termina en `/login`. El resto del contrato (duración, logo
> animado, cancelación si `mounted == false`) se mantiene intacto.
> Ver *Extensiones* más abajo.

### LoginScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Garantiza*: formulario email + contraseña, al enviar → `/home` | `login_screen.dart` · `_ingresar()` → `pushReplacementNamed(AppRoutes.home)` | ✅ |
| *Falla si*: email vacío → mensaje, **no** navega | `validarEmail()` estático | ✅ `Falla si: email vacio` |
| *Falla si*: contraseña < 6 → mensaje, **no** navega | `validarPassword()` · `minPassword = 6` | ✅ `Falla si: contrasena menor a 6` |

### RegistroScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Garantiza*: nombre, email, contraseña, confirmación y términos → `/home` | `registro_screen.dart` · `_registrar()` → `pushNamedAndRemoveUntil(home)` | ✅ |
| *Falla si*: campos vacíos | `validarNombre/validarEmail/validarPassword` | ✅ |
| *Falla si*: contraseñas no coinciden | `_validarConfirmacion()` compara con `_passCtrl.text` | ⚪ |
| *Falla si*: términos no aceptados | `_terminosAceptados` + `_mostrarErrorTerminos` | ⚪ |

> **Nota:** el contrato del PDF fija mínimo **6** caracteres para *login*; el mock de
> Penpot rotula *"Mínimo 8 caracteres"* en el formulario de **registro**. Se respetan
> ambos: `LoginScreen.minPassword = 6`, `RegistroScreen.minPassword = 8`.

### HomeScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: citas y catálogo disponibles | `AppState`, alimentado por `GET /api/citas`, `/api/servicios` y `/api/doctores` (respaldo: `data/sample_data.dart`) | ✅ |
| *Garantiza*: próxima cita | `AppState.proximaCita` (la `proxima` más cercana) → `_TarjetaProximaCita` | ✅ |
| *Garantiza*: grid de servicios | `GridView` 3 columnas sobre `AppState.servicios` | ✅ `AppState en modo local` |
| *Garantiza*: top 3 doctores | `AppState.topDoctores` (orden por rating, `take(3)`) | ⚪ |
| *Garantiza*: navega a otras secciones | `onCambiarPestana` + `pushNamed(/reservar)` | ⚪ |
| *Falla si*: catálogo vacío → lista vacía, **sin crash** | `if (top.isEmpty) _MensajeVacio(...)` | ⚪ |

### DoctoresScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: catálogo de doctores (puede estar vacío) | `AppState.doctores` ← `GET /api/doctores` (respaldo: `sample_data.dart`) | ✅ |
| *Garantiza*: lista filtrable por especialidad | `AppState.filtrarDoctores()` = chips (`especialidadesDisponibles`) + buscador por texto | ✅ `filtrarDoctores combina especialidad y texto` |
| *Garantiza*: al tocar un doctor → `/reservar` con el doctor como argumento | `_abrirReserva()` → `pushNamed(reservar, arguments: doctor)` | ⚪ |
| *Falla si*: sin fallo; lista vacía | `_sinResultados()` muestra estado vacío explicativo | ⚪ |

### MisCitasScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: citas del usuario (puede estar vacía) | `AppState.citas` ← `GET /api/citas` | ✅ |
| *Garantiza*: TabBar con 3 pestañas filtrando por `EstadoCita` | `pestanas = [proxima, completada, cancelada]`, `AppState.porEstado()` | ✅ `filtra las citas por EstadoCita` |
| *Garantiza*: FAB navega a `/reservar` | `FloatingActionButton.extended` → `_irAReservar()` | ⚪ |
| *Falla si*: pestaña vacía → mensaje informativo | `EstadoCita.mensajeVacio` renderizado en `_ListaCitas` | ⚪ |
| (extra) cancelar cita con diálogo | `_confirmarCancelacion()` → `AppState.cancelarCita()` | ✅ |

### ReservarScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: `arguments: Doctor?` (opcional, preselecciona) | `AppRoutes.generar()` valida el tipo; `doctorInicial` abre en paso 2 | ⚪ |
| *Garantiza*: 3 pasos — doctor, fecha/hora, confirmación | `_paso` 0/1/2 + `_indicadorPasos()` | ✅ |
| *Garantiza*: al confirmar muestra diálogo y navega a `/mis-citas` | `_mostrarDialogoExito()` → `pushNamedAndRemoveUntil(misCitas)` | ⚪ |
| *Falla si*: sin doctor o sin horario → **botón deshabilitado** | `_puedeAvanzar` → `onPressed: _puedeAvanzar ? _siguiente : null` | ⚪ |
| (extra) horario tomado entre selección y confirmación | `AppState.reservarCita()` devuelve `null` → vuelve a paso 2 | ✅ `no permite reservar dos veces` |

### PerfilScreen
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: `sampleCitas` para estadísticas | `AppState.total*` | ✅ |
| *Garantiza*: avatar, nombre, email | Cabecera con degradado + iniciales de `Usuario` | ⚪ |
| *Garantiza*: estadísticas de citas | 4 tarjetas `_Estadistica` (Total/Próximas/Completadas/Canceladas) | ✅ |
| *Garantiza*: menú de opciones | `_grupoOpciones([...])` en 2 bloques (Cuenta / Aplicación), más un tercero (Administración) que solo se dibuja si `usuario.esAdmin` | ⚪ |
| *Garantiza*: cerrar sesión → diálogo → `/login` | `_confirmarCierre()` → `AppState.cerrarSesion()` → `pushNamedAndRemoveUntil(login)` | ⚪ |
| *Falla si*: estadísticas en 0 sin citas | Los contadores derivan de la lista, que puede estar vacía | ✅ `estadisticas en 0` |

### AdminScreen (extensión — no está en el PDF; traza `admin.html` / `AdminController`)
| Cláusula | Implementación | Prueba |
|---|---|---|
| *Requiere*: sesión con `ROLE_ADMIN` | `_preparar()` comprueba `estado.usuarioActual.esAdmin`; el backend lo vuelve a exigir en cada endpoint | ✅ 403 verificado con `ROLE_USER` |
| *Requiere*: repositorio en línea | Sin `AppState.repositorio` no se construye `AdminState` (el panel no tiene modo demostración: administra datos reales) | ⚪ |
| *Garantiza*: tablero con cifras y gráficas | `_PestanaTablero` + `GraficaBarras` / `GraficaDona` / `BarraProporcion` | ⚪ |
| *Garantiza*: gestión de todas las citas | `_PestanaCitas` (buscador, rango, estado; completar / cancelar / eliminar) | ✅ endpoints |
| *Garantiza*: CRUD de doctores y servicios | `PestanaDoctores` / `PestanaServicios` + formularios | ✅ endpoints |
| *Garantiza*: gestión de usuarios | `PestanaUsuarios` (activa / admin) | ✅ endpoints |
| *Falla si*: el usuario no es admin | `_AccesoDenegado` + traza de la denegación citando `SecurityConfig` | ⚪ |
| *Falla si*: un admin se desactiva a sí mismo | Su fila tiene los interruptores deshabilitados; el backend responde `409` | ✅ |

---

## 3. Contratos de widgets compartidos (PDF §1.3)

| Contrato | Implementación | Cumplimiento |
|---|---|---|
| **DoctorCard** · *Requiere*: `doctor`, `onTap` | `lib/widgets/doctor_card.dart` | Ambos `required`; `InkWell(onTap: onTap)` |
| **DoctorCard** · *Garantiza*: avatar, nombre, especialidad, rating, experiencia | idem | `DoctorAvatar` + nombre + especialidad coloreada + ⭐ rating + 💼 `experienciaTexto` |
| **CitaCard** · *Requiere*: `cita` | `lib/widgets/cita_card.dart` | Parámetro `required Cita cita` |
| **CitaCard** · *Garantiza*: info del doctor, fecha, hora y badge de estado coloreado | idem | `DoctorAvatar` + `Fechas.conDia` + `Fechas.hora12` + `EstadoBadge(estado.color)` |
| **AppTextField** · *Requiere*: `label`, `controller`, `prefixIcon` | `lib/widgets/app_text_field.dart` | Los tres `required` |
| **AppTextField** · *Garantiza*: campo estilizado con label e icono, texto vía controller | idem | Label encima + `prefixIcon` + `TextFormField(controller:)`; extra: toggle de visibilidad |

---

## 4. Trazabilidad con el backend `ejemplo_99` (Spring Boot)

| Regla / elemento en Java | Archivo Java | Equivalente Flutter | Prueba |
|---|---|---|---|
| Horarios 07:00–19:00 cada 30 min | `CitaService.obtenerHorariosDisponiblesString()` | `sample_data.dart` → `horariosBase` (25 slots) | ✅ `rejilla base` |
| Si la fecha es hoy, descartar horas pasadas | idem | `HorariosService.disponibles()` regla 2 | ⚪ |
| Descartar horarios ya ocupados | idem | `HorariosService.disponibles()` regla 3 | ✅ `horario ocupado` |
| Rechazar reserva si la hora no está disponible | `CitaService.crearCita()` (lanza `RuntimeException`) | `AppState.reservarCita()` devuelve `null` | ✅ `no permite reservar dos veces` |
| Estado por defecto `PROGRAMADA` | `CitaService.save()` | `reservarCita()` crea con `EstadoCita.proxima` | ✅ |
| Cambiar estado de cita | `CitaService.cambiarEstadoCita()` | `AppState.cancelarCita()` / `completarCita()` | ✅ |
| Estados `PROGRAMADA`/`COMPLETADA`/`CANCELADA` | `Cita.estado` (String) | `EstadoCita.estadoBackend` / `.desdeBackend()` | ✅ |
| `Doctor`: nombre, apellido, especialidad, descripcion | `models/mongo/Doctor.java` | `models/doctor.dart` (nombre ya combinado; `imagenUrl` → `iniciales` + `color`) | ✅ |
| `Servicio`: nombre, descripcion, duracionMinutos, icono | `models/mongo/Servicio.java` | `models/servicio.dart` (`icono` `ri-*` → `IconData`) | ⚪ |
| Servicios sembrados: Medicina General 30′, Odontología 60′, Pediatría 45′ | `DataInitializer.run()` | `sampleServicios` conserva nombres y duraciones | ⚪ |
| `Usuario`: username, email, nombre | `models/mysql/Usuario.java` | `models/usuario.dart` | ⚪ |
| Cancelar cita | `CitaController.cancelarCita()` | `MisCitasScreen._confirmarCancelacion()` | ✅ |

### Dominio Java → tablas SQLite del backend propio

El backend `SaludCuidado-backend` (Dart + shelf + SQLite) replica el dominio Java
en una base de datos real. Equivalencias exactas:

| Clase Java | Tabla en `saludcuidado.db` | Notas |
|---|---|---|
| `models/mysql/Usuario.java` | `usuarios` + `usuario_roles` | contraseña como PBKDF2-HMAC-SHA256 (12 000 iteraciones, sal por usuario) |
| (sesión de Spring Security) | `sesiones` | token opaco de portador, enlazado al usuario |
| `models/mongo/Doctor.java` | `doctores` + `doctor_horarios` | la agenda del doctor pasa a tabla hija |
| `models/mongo/Servicio.java` | `servicios` | conserva nombre, descripción, duración e icono |
| `models/mongo/Cita.java` | `citas` | FK a `doctores`, `servicios` y `usuarios` |
| `CitaService.crearCita()` (chequeo en memoria) | índice `ix_citas_slot` | regla antidoble-reserva **impuesta por la base de datos** |

```sql
CREATE UNIQUE INDEX ix_citas_slot
  ON citas (doctor_id, fecha, hora)
  WHERE estado <> 'CANCELADA';
```

El índice es parcial a propósito: impide dos citas activas en la misma hora con
el mismo doctor **y** libera el horario cuando la cita pasa a `CANCELADA`, que es
exactamente el comportamiento que `CitaService.java` lograba filtrando en memoria.

### Capa de red en Flutter

| Endpoint | Consumidor en Flutter | Contrato que cumple |
|---|---|---|
| `POST /api/auth/login` | `AppState.autenticar()` | `LoginScreen.Garantiza` / `Falla si` (401) |
| `POST /api/auth/registro` | `AppState.registrarUsuario()` | `RegistroScreen.Garantiza` (409 si el correo existe) |
| `GET /api/doctores` | `AppState.inicializar()` → `Repositorio.doctores()` | `DoctoresScreen.Requiere` |
| `GET /api/doctores/<id>/horarios` | `ReservarScreen._cargarHorarios()` | `CitaService.obtenerHorariosDisponiblesString` |
| `GET /api/servicios` | `Repositorio.servicios()` | `HomeScreen.Garantiza` (grid de servicios) |
| `GET /api/citas` | `AppState.cargarCitas()` | `MisCitasScreen.Requiere` |
| `POST /api/citas` | `AppState.reservarCita()` | `ReservarScreen.Garantiza` (paso 3) |
| `PATCH /api/citas/<id>` | `AppState.cancelarCita()` / `completarCita()` | `CitaService.cambiarEstadoCita` |

#### API de administración (🔒 exige `ROLE_ADMIN`)

Traza directa contra `AdminController.java` (`@RequestMapping("/admin")`) y
`UsuarioController.java`, cuyo acceso `SecurityConfig` restringe con
`.requestMatchers("/admin/**").hasAuthority("ROLE_ADMIN")`:

| Endpoint propio | Origen en el proyecto Java | Consumidor en Flutter |
|---|---|---|
| `GET /api/admin/resumen` 🔒 | `AdminController.GET /admin` + `DashboardService` (estadísticas generales, doctores populares, estadísticas mensuales) | `AdminState.cargarResumen()` → pestaña **Tablero** |
| `GET /api/admin/citas` 🔒 | `GET /admin/citas`, `/admin/citas/filtrar`, `/admin/citas/buscar` | `AdminState.cargarCitas()` → pestaña **Citas** |
| `PATCH /api/admin/citas/<id>` 🔒 | `POST /admin/citas/{id}/estado` | `AdminState.cambiarEstadoCita()` |
| `DELETE /api/admin/citas/<id>` 🔒 | `DELETE /admin/citas/{id}` | `AdminState.eliminarCita()` |
| `GET/POST /api/admin/doctores` 🔒 | `GET/POST /admin/doctores` | pestaña **Doctores** + `_FormularioDoctor` |
| `PUT/DELETE /api/admin/doctores/<id>` 🔒 | `PUT /admin/doctores/{id}`, `DELETE /admin/doctores/{id}` | `AdminState.actualizarDoctor()` / `eliminarDoctor()` |
| `GET/POST /api/admin/servicios` 🔒 | `GET/POST /admin/servicios` | pestaña **Servicios** + `_FormularioServicio` |
| `PUT/DELETE /api/admin/servicios/<id>` 🔒 | `PUT /admin/servicios/{id}`, `DELETE /admin/servicios/{id}` | `AdminState.actualizarServicio()` / `eliminarServicio()` |
| `GET /api/admin/usuarios` 🔒 | `GET /admin/usuarios` (`UsuarioController`) | pestaña **Usuarios** |
| `PATCH /api/admin/usuarios/<id>` 🔒 | `POST /admin/usuarios/{id}/cambiar-estado` | `AdminState.cambiarActivoUsuario()` / `cambiarRolAdmin()` |

Reglas de negocio que el backend impone y la app explica al usuario:

| Regla | Dónde se impone | Respuesta |
|---|---|---|
| Sin sesión no se entra al panel | `_exigirAdmin()` | `401 no_autorizado` |
| Con sesión pero sin `ROLE_ADMIN` | `_exigirAdmin()` | `403 prohibido` |
| Borrar un doctor o servicio con citas lo **desactiva** | `DELETE /api/admin/{doctores,servicios}/<id>` | `200` con aviso de desactivación |
| Desactivar un usuario invalida su token | `PATCH /api/admin/usuarios/<id>` borra sus filas de `sesiones` | `200` |
| Un admin no puede desactivarse a sí mismo | `PATCH /api/admin/usuarios/<id>` | `409 conflicto` |
| Dos citas no pueden ocupar el mismo hueco | índice parcial `ix_citas_slot` | `409 conflicto` |

Verificado con 22 comprobaciones sobre una base de datos de usar y tirar, más
una prueba de autorización dedicada: con `ROLE_USER`,
`/api/admin/resumen|citas|doctores|usuarios` devuelven **403**, mientras
`/api/citas` sigue devolviendo **200** con las citas propias.

Cada modelo tiene su fábrica de deserialización con el contrato probado:
`Doctor.desdeJson`, `Cita.desdeJson` (lanza `FormatException` si la cita llega
sin doctor o con fecha ilegible) y `Usuario.desdeJson`. Las pruebas están en
`test/api_test.dart`.

### Diferencias deliberadas

1. **Persistencia propia, no MySQL+MongoDB.** El backend Java usaba dos motores
   (MySQL para usuarios, MongoDB para el resto). Aquí todo vive en un único
   archivo SQLite con claves foráneas y transacciones, para que el sistema se
   levante con un solo comando y sin instalar servidores. Las tablas conservan
   los mismos campos que las entidades Java (tabla de arriba).
2. **Doctor embebido en Cita.** El backend guarda `doctorId` + nombre desnormalizado;
   el contrato móvil exige `doctor: Doctor`, así que la app embebe el objeto.
3. **Agenda por doctor.** El backend calcula disponibilidad global por fecha; el
   contrato móvil añade `Doctor.horariosDisponibles`, por lo que la app intersecta
   ambas restricciones.
4. **Domingos excluidos** en `HorariosService.diasSeleccionables()` — decisión de UI
   del prototipo móvil, no presente en el backend.
5. **Datos del paciente.** El backend pide cédula, dirección, tipo de documento y
   beneficiario al reservar. Los mocks móviles no incluyen ese formulario, así que
   el paso 3 es solo confirmación. Si se requiere paridad total, ese formulario
   sería un paso 4 en `ReservarScreen`.

---

## 5. Extensiones sobre el documento de entregables

Elementos **no presentes en el PDF ni en el backend**, añadidos deliberadamente.
Se listan aparte para que la trazabilidad contra el documento original siga
siendo exacta.

| Extensión | Archivo | Motivo | Impacto en los contratos |
|---|---|---|---|
| `OnboardingScreen` (3 pantallas animadas) | `screens/onboarding_screen.dart` | Presentar la app antes del login, siguiendo el patrón de onboarding habitual en apps móviles | Añade la ruta `/onboarding`; ningún contrato del PDF se modifica |
| Secuencia animada del splash | `screens/splash_screen.dart` | El PDF pide «logo animado» sin detallarlo; se desarrolló como secuencia de 6 tramos | Cumple *Garantiza* y *Falla si*; cambia solo el destino (ver arriba) |
| Arte vectorial animado | `widgets/arte_animado.dart` | Ilustraciones sin assets ni paquetes (Lottie/Rive) | Ninguno |
| `AppState.onboardingVisto` | `data/app_state.dart` | Decidir si el splash va a `/onboarding` o a `/login` | Ninguno |
| Perfil → *Ver introducción de nuevo* | `screens/perfil_screen.dart` | Permitir reproducir la bienvenida | Amplía el «menú de opciones» que el contrato ya exigía |
| `TrazabilidadScreen` | `screens/trazabilidad_screen.dart` | Hacer inspeccionable la traza desde la app | Amplía el «menú de opciones» |
| **API REST + base de datos** | `SaludCuidado-backend/` | El PDF describe un prototipo en memoria; se añadió un backend propio para que usuarios, doctores, servicios y citas **se guarden de verdad** | Ninguno: los contratos del PDF se cumplen igual, ahora contra datos persistidos |
| Capa de red | `data/api/api_cliente.dart`, `data/api/repositorio.dart` | Consumir la API con errores tipados, tiempo máximo y token de sesión | Ninguno |
| Modo demostración (respaldo sin conexión) | `Repositorio` + `sample_data.dart` | Que la app siga siendo usable y presentable si el servidor no está | Ninguno: los contratos se cumplen con datos en memoria, como antes |
| Isotipo animado | `widgets/marca.dart` | Sustituir el monograma «SC» por una marca con significado (escudo + cruz + electrocardiograma) | Ninguno |
| Avatares ilustrados animados | `widgets/avatar_ilustrado.dart` | El contrato pedía «avatar»; se implementa como ilustración determinista por semilla en lugar de iniciales | Cumple `DoctorCard.Garantiza` (avatar); `DoctorAvatar` mantiene su API |
| Estados de carga, error y vacío | `widgets/estados_ui.dart` | Esqueletos, banner de conexión y panel de reintento | Ninguno |
| `Doctor.avatarSemilla` / `fotoUrl`, `Usuario.avatarSemilla` / `roles` | `models/` | Soporte de avatares y de los roles que ya existían en `Usuario.java` | Campos opcionales con valor por defecto: los constructores del PDF siguen siendo válidos |
| **Panel de administración** | `screens/admin_screen.dart`, `screens/admin_catalogo.dart`, `data/admin_state.dart`, `lib/rutas/admin.dart` (backend) | El PDF describe solo el flujo del paciente; la plataforma web sí tiene `admin.html` + `AdminController`, así que la app móvil lo necesitaba para tener paridad | Añade la ruta `/admin`; ningún contrato del PDF se modifica |
| Gráficas propias | `widgets/graficas.dart` | Barras, dona y barras de proporción para el tablero, dibujadas con `CustomPainter` en lugar de `fl_chart` | Ninguno |
| `Doctor.titulo/nombrePila/apellido/correo/telefono`, `Cita.paciente*`, `UsuarioAdmin`, `ResumenAdmin` | `models/` | Campos que solo envía la API de administración: los datos sueltos para poder editar por partes y el paciente dueño de cada cita | Campos opcionales (`null` en la vista del paciente): los contratos del PDF siguen cumpliéndose |
| Lienzo teñido y tipografía empaquetada | `app/app_theme.dart`, `assets/fonts/` | El azul de marca de los mocks se conserva; lo que cambia es el fondo de pantalla, que deja de ser blanco (`#E8EEF7`), y la tipografía Plus Jakarta Sans (OFL) empaquetada | Ninguno: los contratos no fijan colores ni tipografía |

> La introducción se marca como vista **solo en memoria**, de modo que reaparece
> en cada arranque. Persistirla requeriría `shared_preferences`, que se evitó
> para mantener el proyecto sin dependencias externas.

---

## 6. Trazabilidad en ejecución

Todo evento registrado por `TraceLogger` lleva un campo `contrato` que apunta a la
cláusula de este documento. Ejemplos reales emitidos por la app:

| Evento | Contrato referenciado |
|---|---|
| `NAV SplashScreen :: Navegación automática -> /login` | `SplashScreen.Garantiza` |
| `VALIDACION LoginScreen :: Validación fallida: no se navega a /home` | `LoginScreen.Falla si` |
| `VALIDACION ReservarScreen :: Intento de avanzar bloqueado en paso 2` | `ReservarScreen.Falla si (botón deshabilitado)` |
| `DATOS HorariosService :: Horarios para Dr. … 12 disponibles, 1 ocupados` | `CitaService.obtenerHorariosDisponiblesString` |
| `DATOS AppState :: Cita creada cita-… (estado PROGRAMADA)` | `ReservarScreen.Garantiza` |
| `ACCION AppState :: Sesión cerrada: …` | `PerfilScreen.Garantiza (cerrar sesión -> /login)` |
| `DATOS ApiCliente :: POST /api/citas -> 201 (12ms)` | `ReservarScreen.Garantiza` (guardado en base de datos) |
| `ERROR ApiCliente :: POST /api/citas falló: El horario ya está ocupado` | `CitaService.crearCita (hora no disponible)` → índice `ix_citas_slot` |
| `DATOS Repositorio :: Backend disponible en http://localhost:8080` | arranque de `AppState.inicializar()` |
| `ERROR Repositorio :: Doctores servidos desde el respaldo local` | modo demostración (sin servidor) |

Se consultan en **Perfil → Trazabilidad del flujo**, o en consola durante `flutter run`.

El servidor lleva su propia traza simétrica, de modo que una misma acción se
puede seguir en los dos lados:

```
app      [16:04:18] DATOS ApiCliente :: POST /api/citas -> 201 (12ms)
servidor [16:04:18] POST /api/citas 201 9ms  usuario=brandon@saludcuidado.com
```
