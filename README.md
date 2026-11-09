# SaludCuidado — App móvil Flutter

Aplicación móvil de gestión de citas médicas, reconstruida en Flutter a partir de:

- **`entregables-mocks-movil2.pdf`** — contratos de modelos, pantallas y widgets + mocks de Penpot.
- **`ejemplo_99` (Spring Boot)** — proyecto web del que se heredan el dominio y las reglas de negocio.

El sistema son **dos proyectos**:

| Proyecto | Carpeta | Qué es |
|---|---|---|
| App móvil | `SaludCuidado-flutter` | Flutter (este repositorio) |
| API + base de datos | `SaludCuidado-backend` | Dart + shelf + **SQLite** |

Los registros de usuarios, doctores, servicios y citas **se guardan en la base
de datos** (`SaludCuidado-backend/datos/saludcuidado.db`) y sobreviven al cierre
de la app y del servidor. Si el servidor no está disponible, la app no se rompe:
sigue funcionando en *modo demostración* con datos en memoria y lo avisa en
pantalla.

> Fundación Tecnológico Comfenalco — Computación Móvil
> Brandon Llamas · Carlos Gomez · Camilo Mackensie · Aurelio Guzman

---

## 1. Puesta en marcha

El proyecto está listo para ejecutarse. Las carpetas de plataforma `android/` y
`web/` ya fueron generadas.

**Paso 1 — levantar la API** (en una terminal aparte):

```bash
cd SaludCuidado-backend
dart pub get
dart run bin/server.dart --puerto 8080
# comprobación: http://localhost:8080/api/salud
```

**Paso 2 — ejecutar la app**:

```bash
cd SaludCuidado-flutter

flutter pub get
flutter run -d chrome     # web (no requiere Android SDK)
flutter test              # 42 pruebas automatizadas
flutter analyze           # debe reportar "No issues found!"
```

Cuentas sembradas en la base de datos (el login tiene además un botón
**«Usar cuenta de demostración»**):

| Correo | Contraseña | Rol |
|---|---|---|
| `brandon@saludcuidado.com` | `demo1234` | usuario |
| `admin@saludcuidado.com` | `admin123` | administrador |

Para añadir iOS, Windows, macOS o Linux más adelante:

```bash
flutter create --platforms=ios,windows .
```

### Entorno verificado

| | |
|---|---|
| Flutter | 3.47.9 · canal stable |
| Dart | 3.13.7 |
| SDK | `C:\src\flutter` |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ 42/42 |
| `flutter build web --release` | ✅ compila |

**Una sola dependencia.** El proyecto usa el SDK de Flutter más `http` (para
consumir la API). No usa `provider` (el estado es `ChangeNotifier` +
`InheritedNotifier`), ni `intl` (las fechas en español se formatean en
`core/fechas.dart`), ni Lottie/Rive/SVG (todas las animaciones e ilustraciones
son `CustomPainter`).

### Dónde busca la API la app

`ApiConfig` (`lib/data/api/api_cliente.dart`) elige la URL según la plataforma:

| Plataforma | URL base |
|---|---|
| Flutter Web / escritorio | `http://localhost:8080` |
| Emulador de Android | `http://10.0.2.2:8080` (alias del PC) |
| Teléfono físico | hay que poner la IP del PC en la red local |

> **Nota sobre Android.** Para `flutter run -d android` hace falta instalar Android
> Studio (o los command-line tools) y luego `flutter doctor --android-licenses`.
> Para Windows desktop se requiere Visual Studio con el workload
> *Desktop development with C++* y el Modo desarrollador de Windows activado.

---

## 2. Flujo de la aplicación

```
                    ┌─────────────┐
                    │   /  Splash │  secuencia animada, ~2.3 s
                    └──────┬──────┘
                           │ pushReplacement
                    ┌──────▼──────────┐
                    │  /onboarding    │  3 pantallas animadas
                    │  (si no vista)  │  Omitir / Comenzar
                    └──────┬──────────┘
                           │ pushReplacement
                    ┌──────▼──────┐
          ┌─────────│   /login    │◄──────────── cerrar sesión
          │         └──────┬──────┘
          │ push           │ pushReplacement (credenciales válidas)
   ┌──────▼──────┐  ┌──────▼──────────────────────────────────┐
   │  /registro  │─►│              /home                      │
   └─────────────┘  │   MainShell · BottomNavigationBar       │
     (registro OK)  │                                         │
                    │  [0] Inicio   [1] Doctores              │
                    │  [2] Mis Citas [3] Perfil               │
                    └───┬─────────────┬──────────┬────────────┘
                        │             │          │
              doctor    │       FAB   │          │ "Trazabilidad"
              tocado    │             │          │
                 ┌──────▼─────────────▼──┐  ┌────▼──────────────┐
                 │      /reservar        │  │  /trazabilidad    │
                 │  paso 1 → 2 → 3       │  │  visor de eventos │
                 └──────────┬────────────┘  └───────────────────┘
                            │ confirmar (diálogo de éxito)
                      ┌─────▼──────┐
                      │ /mis-citas │
                      └────────────┘
```

### Rutas

| Ruta             | Pantalla                   | Entra desde              | Sale hacia                     |
|------------------|----------------------------|--------------------------|--------------------------------|
| `/`              | `SplashScreen`             | arranque                 | `/onboarding` o `/login` (2.3 s) |
| `/onboarding`    | `OnboardingScreen`         | splash, Perfil           | `/login`, o vuelve a Perfil    |
| `/login`         | `LoginScreen`              | splash, cerrar sesión    | `/home`, `/registro`           |
| `/registro`      | `RegistroScreen`           | `/login`                 | `/home`                        |
| `/home`          | `MainShell(0)`             | login / registro         | pestañas, `/reservar`          |
| `/doctores`      | `MainShell(1)`             | pestaña o push           | `/reservar` (con `Doctor`)     |
| `/mis-citas`     | `MainShell(2)`             | pestaña o push           | `/reservar` (FAB)              |
| `/perfil`        | `MainShell(3)`             | pestaña o push           | `/login`, `/trazabilidad`      |
| `/reservar`      | `ReservarScreen`           | home / doctores / citas  | `/mis-citas`                   |
| `/trazabilidad`  | `TrazabilidadScreen`       | `/perfil`                | —                              |
| `/admin`         | `AdminScreen`              | `/perfil` (solo admin)   | —                              |

Las rutas se resuelven en un único punto: `AppRoutes.generar()` (`lib/app/app_routes.dart`),
que además registra cada resolución en la traza y valida de forma tipada el
argumento `Doctor?` de `/reservar`.

---

## 2.bis Roles: usuario y administrador

Hay dos roles, los mismos que en la plataforma web: `ROLE_USER` y `ROLE_ADMIN`.
Se guardan en la tabla `usuario_roles` (1 fila por rol), viajan en el JSON del
login (`usuario.roles`) y la app los lee en `Usuario.esAdmin`.

**La autorización se decide en el servidor, no en la app.** La app solo decide
qué enseñar:

| Capa | Qué hace | Dónde |
|------|----------|-------|
| Backend | Rechaza toda petición a `/api/admin/**` sin sesión (**401**) o sin `ROLE_ADMIN` (**403**), antes de tocar la base de datos | `_exigirAdmin()` en `lib/rutas/admin.dart` |
| Router | Resuelve `/admin`, pero **no** comprueba permisos | `AppRoutes.generar()` |
| Pantalla | Si el usuario no es admin, muestra «Acceso restringido» y registra la denegación en la traza | `AdminScreen._preparar()` |
| Perfil | La entrada «Panel de administración» solo se dibuja si `usuario.esAdmin` | `perfil_screen.dart` |

Ocultar el botón es comodidad; quien llame a la API a mano recibe igualmente un
403.

Es el mismo reparto que en la plataforma web: `SecurityConfig` declara
`.requestMatchers("/admin/**").hasAuthority("ROLE_ADMIN")` y `AdminController`
(`@RequestMapping("/admin")`) sirve el panel `admin.html`. La diferencia es de
forma, no de fondo: Spring devuelve páginas HTML y aquí los mismos datos salen
como JSON bajo `/api/admin/**`, porque el cliente es una app móvil.

### Qué ve cada rol

| | `ROLE_USER` | `ROLE_ADMIN` |
|---|---|---|
| Inicio, Doctores, Reservar | sí | sí |
| Mis Citas | **solo las suyas** | solo las suyas (su vista de paciente no cambia) |
| Panel `/admin` | no | sí |
| Citas de todos los pacientes | no | ver, cambiar estado, eliminar |
| Doctores y servicios | solo consultar | crear, editar, eliminar |
| Usuarios | no | activar/desactivar y dar/quitar admin |

### Panel de administración (`/admin`)

Cinco pestañas (`admin_screen.dart` + `admin_catalogo.dart`), con su estado en
`AdminState` (`lib/data/admin_state.dart`), que es un `ChangeNotifier` separado
de `AppState` para que la vista del paciente no cargue nunca datos ajenos:

1. **Tablero** — cifras con animación de conteo (citas totales, programadas,
   completadas, canceladas), barras de citas por mes (6 meses), dona de citas
   por doctor y tasa de cumplimiento. Todas las gráficas son `CustomPainter`
   propios (`widgets/graficas.dart`): sin dependencias de terceros.
2. **Citas** — todas las del sistema, con buscador (paciente, doctor, servicio),
   filtro de rango (hoy / semana / mes) y de estado; se puede marcar como
   completada, cancelar o eliminar (con confirmación).
3. **Doctores** — CRUD completo, incluida la rejilla de horarios de atención
   (07:00–19:00 cada 30 min, la misma que valida el backend).
4. **Servicios** — CRUD completo: nombre, duración, descripción e icono.
5. **Usuarios** — lista con número de citas; interruptores de *activa* y
   *admin*.

Dos reglas del backend que el panel respeta y explica en pantalla:

- **Eliminar un doctor o un servicio con citas asociadas no borra la fila: la
  desactiva.** Así ninguna cita queda huérfana y el historial se conserva.
- **Desactivar un usuario borra sus sesiones**, de modo que su token deja de
  valer inmediatamente; y un administrador **no puede desactivarse a sí mismo**
  (el backend responde `409`, y la app además deshabilita su propia fila).

---

## 3. Trazabilidad

El proyecto implementa trazabilidad en **tres niveles**:

### a) Trazabilidad de requisitos → código
Cada clase lleva en su docstring el contrato literal del PDF
(`Requiere` / `Garantiza` / `Falla si`) y la clase Java de la que hereda su lógica.
La matriz completa está en **[`TRAZABILIDAD.md`](TRAZABILIDAD.md)**.

### b) Trazabilidad en ejecución
`TraceLogger` (`lib/core/trace/trace_logger.dart`) registra cada evento con
marca de tiempo, origen, mensaje y el contrato que lo respalda:

```
[14:32:07] NAV       SplashScreen :: Navegación automática -> /login  <- SplashScreen.Garantiza
[14:32:11] VALIDACION LoginScreen :: Validación fallida: no se navega  <- LoginScreen.Falla si
[14:32:19] DATOS     AppState     :: Cita creada cita-17...: Dr. Carlos Mendoza 2026-11-09 10:00
```

`TraceNavigatorObserver` se engancha a `MaterialApp.navigatorObservers`, de modo
que **toda** transición de ruta queda registrada sin que las pantallas lo pidan.

La traza se consulta dentro de la app en **Perfil → Trazabilidad del flujo**,
con filtros por tipo (NAV / ACCIÓN / VALIDACIÓN / DATOS / ERROR) y botón para
copiarla al portapapeles.

### c) Trazabilidad verificada
- `test/contratos_test.dart` (21 pruebas) comprueba cláusula por cláusula las
  garantías y los fallos declarados en el PDF (validaciones de login/registro,
  filtrado por `EstadoCita`, reglas de horarios, doble reserva, estadísticas en 0).
- `test/api_test.dart` (15 pruebas) comprueba los contratos de la capa de red:
  cada `desdeJson`, el mapeo de los tres estados del backend, los fallos
  controlados (`FormatException` si una cita llega sin doctor o con fecha
  ilegible), el determinismo de los avatares y el modo de respaldo del `AppState`.

Además, cada llamada HTTP queda en la traza con su método, ruta, código de
estado y duración:

```
[16:04:12] DATOS ApiCliente :: GET /api/doctores -> 200 (31ms)
[16:04:18] DATOS ApiCliente :: POST /api/citas -> 201 (12ms)
[16:04:25] ERROR ApiCliente :: POST /api/citas falló: El horario ya está ocupado
```

---

## 3.bis Arquitectura cliente–servidor

```
   Flutter (SaludCuidado-flutter)            API (SaludCuidado-backend)
  ┌──────────────────────────────┐          ┌──────────────────────────┐
  │ screens/   (UI)              │          │  shelf_router            │
  │     ▼                        │          │    ▼                     │
  │ AppState  (ChangeNotifier)   │   HTTP   │  middleware:             │
  │     ▼                        │  JSON    │   errores → traza →      │
  │ Repositorio ─────────────────┼─────────►│   CORS → autenticación   │
  │     ▼            ▲           │          │    ▼                     │
  │ ApiCliente       │ respaldo  │          │  SQLite (saludcuidado.db)│
  │                  │           │          │   usuarios  sesiones     │
  │             sample_data.dart │          │   doctores  doctor_horarios│
  └──────────────────────────────┘          │   servicios citas        │
                                            └──────────────────────────┘
```

**Contrato de la API** (todas las respuestas son JSON):

| Método | Ruta | Qué hace |
|---|---|---|
| `GET` | `/api/salud` | comprobación de vida (motor y nº de doctores) |
| `POST` | `/api/auth/registro` | crea usuario (PBKDF2) y devuelve token |
| `POST` | `/api/auth/login` | valida credenciales y devuelve token |
| `POST` | `/api/auth/logout` | invalida la sesión |
| `GET` | `/api/auth/yo` | usuario de la sesión actual |
| `GET` | `/api/doctores?especialidad=&q=` | catálogo filtrable |
| `GET` | `/api/doctores/<id>` | un doctor |
| `GET` | `/api/doctores/<id>/horarios?fecha=` | horas libres de ese día |
| `GET` | `/api/servicios` | catálogo de servicios |
| `GET` | `/api/citas` | citas del usuario autenticado |
| `POST` | `/api/citas` | **reserva** una cita |
| `PATCH` | `/api/citas/<id>` | cambia el estado (cancelar / completar) |
| `DELETE` | `/api/citas/<id>` | elimina una cita |
| `GET` | `/api/estadisticas` | totales por estado |

Los errores llegan siempre con la misma forma, y `ApiCliente` los convierte en
excepciones tipadas (`ApiExcepcion` con código HTTP, o `SinConexion`):

```json
{ "error": { "codigo": "horario_ocupado", "mensaje": "El horario ya está ocupado" } }
```

**La regla de negocio vive en la base de datos.** El antidoble-reserva no es
una comprobación de la app, es un índice de SQLite:

```sql
CREATE UNIQUE INDEX ix_citas_slot
  ON citas (doctor_id, fecha, hora)
  WHERE estado <> 'CANCELADA';
```

Así, dos usuarios que pulsen «Confirmar» en el mismo segundo no pueden ocupar
la misma hora (el segundo recibe `409`), y al cancelar una cita el horario
vuelve a quedar libre automáticamente.

### Modo demostración (sin servidor)

`Repositorio` captura `SinConexion` y devuelve los datos de `sample_data.dart`.
En ese caso el `AppState` marca `enLinea = false`, la app muestra un banner
ámbar con botón **Reintentar**, Perfil muestra la insignia *Modo demostración*
y los horarios se calculan en el dispositivo con `HorariosService`. Esto hace
que la app sea presentable incluso si el servidor no arranca.

---

## 4. Estructura

```
lib/
├── main.dart                     punto de entrada
├── app/
│   ├── app.dart                  MaterialApp + AppStateScope + observer
│   ├── app_routes.dart           rutas con nombre y resolución de argumentos
│   └── app_theme.dart            paleta y tema extraídos de los mocks
├── core/
│   ├── fechas.dart               formato de fechas en español (sin `intl`)
│   └── trace/
│       ├── trace_logger.dart     registro central de trazabilidad
│       └── trace_observer.dart   NavigatorObserver → traza
├── models/                       contratos de datos del PDF §1.1
│   ├── doctor.dart  cita.dart  estado_cita.dart  servicio.dart  usuario.dart
│   ├── resumen_admin.dart        cifras y series del tablero de admin
│   └── usuario_admin.dart        usuario con roles, estado y nº de citas
│                                 (cada uno con su fábrica `desdeJson`)
├── data/
│   ├── api/
│   │   ├── api_cliente.dart      cliente HTTP, token, errores tipados
│   │   └── repositorio.dart      API + política de respaldo sin conexión
│   ├── sample_data.dart          datos de respaldo (modo demostración)
│   ├── horarios_service.dart     reglas de disponibilidad (del backend)
│   ├── admin_state.dart          estado del panel de administración
│   └── app_state.dart            estado compartido (ChangeNotifier)
├── widgets/
│   ├── app_text_field.dart  doctor_card.dart  cita_card.dart   (PDF §1.3)
│   ├── avatar_ilustrado.dart     avatares ilustrados y animados
│   ├── marca.dart                isotipo animado de la marca
│   ├── estados_ui.dart           banner de conexión, esqueletos, error
│   ├── graficas.dart             barras, dona y barras de proporción
│   └── arte_animado.dart         ilustraciones vectoriales animadas
└── screens/                      pantallas del PDF §1.2
    ├── splash_screen.dart  onboarding_screen.dart
    ├── login_screen.dart   registro_screen.dart
    ├── main_shell.dart     home_screen.dart   doctores_screen.dart
    ├── mis_citas_screen.dart  reservar_screen.dart  perfil_screen.dart
    ├── admin_screen.dart         panel de admin: tablero y citas
    ├── admin_catalogo.dart       panel de admin: doctores, servicios, usuarios
    └── trazabilidad_screen.dart
```

---

## 5. Bienvenida animada

La introducción se construyó **sin paquetes externos** (nada de Lottie, Rive o
SVG): todo el arte es geometría calculada en `CustomPainter`, así que escala a
cualquier densidad sin assets y no añade peso al binario.

### Splash (`splash_screen.dart`)

Una sola línea de tiempo de 2.3 s con tramos encadenados:

| Tramo | Qué ocurre |
|---|---|
| `0.00 – 0.42` | el logo entra con rebote elástico (`Curves.elasticOut`) |
| `0.10 – 0.70` | tres anillos de pulso se expanden escalonados y se desvanecen |
| `0.26 – 0.68` | se **traza** la línea de electrocardiograma, con un punto guía luminoso en la punta |
| `0.44 – 0.76` | el título aparece **letra por letra**, cada una con su retardo |
| `0.62 – 0.84` | el lema se desliza hacia arriba |
| `0.88 – 1.00` | todo se desvanece y se acerca hacia la siguiente pantalla |

Un segundo controlador en bucle mueve los halos del fondo, hace «respirar» el
logo y late los tres puntos de carga.

### Onboarding (`onboarding_screen.dart`)

Tres pantallas con ilustración propia, cada una con su paleta:

1. **Encuentra a tu especialista** — azul · avatares orbitando un núcleo, con un arco de búsqueda barriendo el círculo
2. **Reserva tu cita en segundos** — turquesa · calendario cuyos días aparecen escalonados, un día se selecciona con *check* y un reloj completa su anillo
3. **Lleva el control de tu salud** — púrpura · aro de progreso, corazón latiendo y electrocardiograma trazándose

Técnicas aplicadas:

- **Degradado interpolado**: el fondo se calcula con `Color.lerp` sobre la posición *continua* del `PageController`, así que la transición de color sigue al dedo.
- **Parallax**: la ilustración se desplaza a ~2.7× la velocidad del texto.
- **Entrada escalonada**: al activarse una pantalla, título y cuerpo entran con retardos distintos.
- **Indicador de píldora**: el punto activo se alarga con `AnimatedContainer`.
- **Botón que se transforma**: círculo con flecha → pastilla «Comenzar» en la última pantalla; «Omitir» se desvanece.

El arte vive en `widgets/arte_animado.dart`, con utilidades reutilizables
(`caminoLatido`, `caminoCorazon`, `dibujarCaminoProgresivo`, `tramo`).

> **Nota.** `AppState.onboardingVisto` se guarda **solo en memoria**, así que la
> introducción reaparece en cada arranque — práctico para demostrarla. Para
> mostrarla una única vez por instalación habría que persistir ese booleano
> (p. ej. con `shared_preferences`). Mientras tanto, se puede reproducir desde
> **Perfil → Ver introducción de nuevo**.

---

## 6. Diseño

El color de marca es el **azul de los mocks de Penpot**. Lo que cambió en esta
revisión es el **lienzo**: el fondo de las pantallas ya no es blanco ni un gris
casi blanco, sino un azul grisáceo claro (`#E8EEF7`), de modo que las tarjetas
blancas se recortan sobre él en lugar de fundirse. Todo vive en
`lib/app/app_theme.dart`:

| Token          | Valor     | Uso                                        |
|----------------|-----------|--------------------------------------------|
| `primary`      | `#1A5FBF` | AppBar, botones, estado "próxima"          |
| `primaryDark`  | `#14499A` | pulsado, `SnackBar` de éxito               |
| `primaryDeep`  | `#0D3573` | cierre del degradado, estado "completada"  |
| `primaryLight` | `#5B90E0` | realces y degradado de tarjeta             |
| `azulSuave`    | `#DCE7F8` | fondos suaves, chips seleccionados         |
| `acento`       | `#F5A623` | rating, avisos, insignia «TÚ»              |
| **`background`** | **`#E8EEF7`** | **lienzo de las pantallas: ya no es blanco** |
| `surface`      | `#FFFFFF` | tarjetas, campos y hojas                   |
| `border`       | `#D5DEEC` | bordes de tarjeta                          |
| `peligro`      | `#DC2626` | estado "cancelada", eliminar, cerrar sesión|

El cambio alcanza también a **Login y Registro**, que antes eran pantallas
blancas de borde a borde y ahora usan el mismo lienzo, con la tarjeta del
formulario en blanco encima.

Cada especialidad tiene su color propio (`AppColors.cardiologia`, `.pediatria`, …),
que tiñe el avatar, el uniforme del avatar y la etiqueta de especialidad, igual
que en el mock de la pantalla *Doctores*.

> Las bases de datos creadas **antes** del ajuste de paleta se actualizan solas:
> al abrirse, el backend ejecuta `Db._sincronizarPaleta()`, que reasigna
> `doctores.color` por especialidad y `servicios.color` por nombre. Es
> idempotente y no toca las citas, así que no hace falta volver a sembrar.

### Tipografía (`assets/fonts/`)

La app usa **Plus Jakarta Sans** (licencia OFL, descargada del repositorio del
autor `tokotype/PlusJakartaSans`) en cinco pesos: 400, 500, 600, 700 y 800.
Es una geométrica humanista: los titulares en `w800` con `letterSpacing`
negativo se leen compactos y modernos, y a 11–13 px los textos de apoyo
siguen siendo legibles, que es casi todo lo que hay en una pantalla de citas.

Va **empaquetada** (≈645 KB), no servida desde internet: la app arranca con su
tipografía incluso sin red, que es justo el caso que el modo demostración debe
cubrir. Se declara en `pubspec.yaml` y se referencia con `AppTheme.fuente`,
de modo que los `CustomPainter` (gráficas, marca) pintan texto con la misma
familia que los widgets.

### Isotipo (`widgets/marca.dart`)

El monograma «SC» se sustituyó por una marca con significado: un **escudo**
(cuidado) que contiene una **cruz médica** (salud) atravesada por un trazo de
**electrocardiograma** (vida), con un punto ámbar que recorre el latido y dos
anillos de pulso que se expanden. Está dibujada con `CustomPainter`:

- `MarcaSaludCuidado(tamano:, conFondo:, colorTrazo:, animado:)` — isotipo; con
  fondo es una cápsula con el degradado de marca que late con ritmo de dos
  tiempos (sístole + réplica), y sin fondo es el símbolo suelto para usar sobre
  color (splash, barra del onboarding).
- `MarcaHorizontal` — isotipo + «Salud**Cuidado**» para barras superiores.

Aparece en splash, login y onboarding; escala a cualquier densidad y no añade
ni un byte de assets.

### Avatares ilustrados (`widgets/avatar_ilustrado.dart`)

Los círculos con iniciales se sustituyeron por **avatares ilustrados y animados**
al estilo de las apps de reparto, también en `CustomPainter`:

- **Deterministas.** `RasgosAvatar.desdeSemilla(n)` deriva tono de piel, color y
  peinado (corto, flequillo ondulado, moño, rizado, largo), gafas, barba, gorro
  quirúrgico y estetoscopio con un generador congruencial propio. La semilla
  viene del modelo (`Doctor.avatarSemilla`, `Usuario.avatarSemilla`), así que
  **cada persona tiene siempre la misma cara**, en todas las pantallas y en
  todos los arranques, sin guardar ni descargar imágenes.
- **Vivos.** Respiran (`sin` sobre un ciclo de 4.2 s) y parpadean dos veces por
  ciclo. Cada avatar arranca en un punto distinto del ciclo según su semilla,
  así que una lista de doctores **no parpadea toda a la vez**.
- **Integrados.** El uniforme y el fondo toman el color de la especialidad, de
  modo que el avatar y la etiqueta del doctor combinan.
- **Con foto real si la hay.** Si el backend envía `fotoUrl`, se muestra la foto
  y la ilustración queda como respaldo si la descarga falla.
- `AvatarUsuario` reutiliza el mismo pintor para el paciente (Home y Perfil).

---

## 7. Robustez de la app

| Situación | Qué ve el usuario |
|---|---|
| Cargando el catálogo | esqueletos que laten con la silueta de la tarjeta (`ListaEsqueleto`) |
| Consultando horarios | indicador «Consultando…» junto al contador de horas libres |
| Servidor caído | banner ámbar «datos de demostración» + botón **Reintentar** |
| Credenciales erróneas | aviso rojo en el propio formulario (no un diálogo) |
| Correo ya registrado | mensaje específico del `409` del backend |
| Hora tomada mientras confirmabas | vuelve al paso 2, recarga horarios y explica por qué |
| Lista o pestaña vacía | mensaje informativo con acción sugerida |
| Cita corrupta en la respuesta | se descarta esa cita y se traza; la pantalla sigue viva |
| Deslizar hacia abajo | recarga desde la base de datos (`RefreshIndicator`) |

También: tiempo máximo de 10 s por petición, respuestas viejas descartadas si
cambió la selección, y `mounted` comprobado tras cada `await` antes de tocar la
UI.

---

## 8. Estado conocido

- Verificado: `flutter analyze` limpio, **42/42 pruebas** en verde
  (21 de contrato + 15 de la capa de API y avatares + 6 de la API de
  administración) y `flutter build web --release` compila.
- La API de administración se ejercitó con 22 comprobaciones sobre una base de
  datos de usar y tirar, más una prueba dedicada de autorización: con
  `ROLE_USER`, `/api/admin/resumen|citas|doctores|usuarios` devuelven **403**
  mientras `/api/citas` sigue devolviendo **200** con las citas propias.
- La API fue ejercitada de extremo a extremo y la persistencia se comprobó con
  `dart run bin/inspeccionar_db.dart`, que lee el archivo `.db` por separado del
  servidor: los usuarios, las citas y los cambios de estado siguen ahí después
  de reiniciar.
- `AppState.onboardingVisto` sigue **solo en memoria** (la introducción reaparece
  en cada arranque; útil para la demostración). La sesión tampoco se persiste:
  al reabrir la app hay que iniciar sesión otra vez. Ambas cosas se resolverían
  con `shared_preferences`.
- Los avatares son ilustraciones generadas; `fotoUrl` está soportado en el
  modelo y en el widget, pero la semilla de doctores no trae fotos reales.

---

## 9. Paridad con la plataforma web

Comparación hecha contra el proyecto Spring Boot original
(`ejemplo_99999 (5)`): sus 34 clases Java y sus 11 plantillas Thymeleaf.

### Cubierto

| Plataforma web | App Flutter |
|---|---|
| `login.html` / `AuthController` | `LoginScreen` → `POST /api/auth/login` |
| `register.html` / `RegistroController` | `RegistroScreen` → `POST /api/auth/registro` |
| `inicio.html` / `MainController` | `HomeScreen` (saludo, servicios, próxima cita) |
| `doctores.html` / `DoctorController` | `DoctoresScreen` con filtro por especialidad y buscador |
| `reservar.html` / `CitaController` | `ReservarScreen` (3 pasos: doctor → fecha → hora) |
| `mis-citas.html` / `MisCitasController` | `MisCitasScreen` con cancelar y completar |
| `admin.html` / `AdminController` | `AdminScreen` + `AdminCatalogo` (5 pestañas) |
| `DashboardService` (estadísticas) | pestaña **Tablero**, con gráficas propias |
| `UsuarioController` (activar, roles) | pestaña **Usuarios** |
| `SecurityConfig` `/admin/**` | `_exigirAdmin()` → 401/403 |

### No cubierto (y por qué)

| Falta | Qué es en la web | Estado |
|---|---|---|
| Chatbot | `ChatController` (`/api/chat`) usa **Spring AI + OpenAI** con herramientas MCP; `ChatService` es, aparte, un intérprete de comandos por palabras clave («listar usuarios», «buscar usuario …») | **No portado.** Necesita una clave de OpenAI de pago y un servidor MCP; es una decisión de alcance, no una limitación técnica |
| Perfil de doctor | `doctor-perfil.html` — ficha con descripción larga y horarios | **No portado.** Los datos ya viajan en `Doctor`; falta la pantalla |
| Página de servicios | `servicios.html` / `ServicioController` — catálogo completo | **Parcial.** Los servicios se ven en Inicio y se eligen al reservar, pero no hay pantalla de catálogo |
| Datos del paciente al reservar | `reservar.html` pide nombre, apellido, cédula, tipo de documento, correo, teléfono, dirección, y si es beneficiario (con documento del titular y edad) | **No portado.** La app reserva con la sesión del usuario; no pide esos campos ni guarda beneficiarios |
| Compatibilidad servicio↔doctor | la web restringe qué servicio puede atender cada especialidad | **No portado.** Aquí cualquier doctor puede atender cualquier servicio |

> Dicho en corto: **el flujo principal y el panel de administración están
> completos y persisten en base de datos**; lo que falta es el chatbot con IA,
> dos pantallas de consulta y el formulario largo de datos del paciente.
