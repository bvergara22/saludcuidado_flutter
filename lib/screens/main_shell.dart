import 'package:flutter/material.dart';

import '../core/trace/trace_logger.dart';
import '../core/tour_app.dart';
import '../data/app_state.dart';
import '../widgets/boton_asistente.dart';
import '../widgets/tour_guiado.dart';
import 'admin_screen.dart';
import 'doctores_screen.dart';
import 'home_screen.dart';
import 'mis_citas_screen.dart';
import 'perfil_screen.dart';

/// Contenedor con la barra de navegación inferior (Inicio, Doctores,
/// Mis Citas, Perfil) tal como aparece en los mocks de Penpot.
///
/// Las rutas /home, /doctores, /mis-citas y /perfil abren este shell en la
/// pestaña correspondiente, de modo que los nombres de ruta del contrato se
/// conservan sin duplicar pantallas.
///
/// **La barra cambia según el rol.** Si el usuario tiene `ROLE_ADMIN` se
/// añade una quinta pestaña, *Admin*, con el panel de administración dentro
/// del propio shell. Es la traducción a móvil de lo que hace la plataforma
/// web: `navbar.html` muestra el enlace «Panel Admin» solo cuando
/// `hasRole('ADMIN')`, y el administrador conserva el resto de la navegación.
///
/// Ocultar la pestaña es comodidad, no seguridad: `AdminScreen` comprueba el
/// rol y cada endpoint `/api/admin/**` lo vuelve a exigir (401/403).
class MainShell extends StatefulWidget {
  final int indiceInicial;

  const MainShell({super.key, this.indiceInicial = 0});

  /// Índice de la pestaña de administración. Solo existe para administradores.
  /// `LoginScreen` lo usa para llevar al admin directamente al panel, igual
  /// que `RoleBasedAuthenticationSuccessHandler` redirige a `/admin` en la web.
  static const int indiceAdmin = 4;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const String _origen = 'MainShell';

  /// El recorrido guiado se lanza desde aquí, y no desde LoginScreen,
  /// porque necesita que la barra de navegación esté ya en pantalla: sus
  /// pasos iluminan las pestañas reales.
  bool _tourPedido = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _quizasTour());
  }

  Future<void> _quizasTour() async {
    if (_tourPedido || !mounted) return;
    _tourPedido = true;
    await TourApp.mostrarSiToca(
      context,
      esAdmin: AppStateScope.leer(context).usuarioActual.esAdmin,
    );
  }
  static const List<String> _nombresBase = [
    'Inicio',
    'Doctores',
    'Mis Citas',
    'Perfil',
  ];

  late int _indice = widget.indiceInicial;

  void _cambiar(int i) {
    if (i == _indice) return;
    setState(() => _indice = i);
    final nombres = [..._nombresBase, 'Admin'];
    traza.navegacion(_origen, 'Pestaña ${nombres[i]} (índice $i)');
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = AppStateScope.of(context).usuarioActual.esAdmin;

    // Si el usuario deja de ser admin (cierra sesión y entra otro) el índice
    // guardado puede apuntar a una pestaña que ya no existe.
    final maximo = esAdmin ? MainShell.indiceAdmin : _nombresBase.length - 1;
    final indice = _indice > maximo ? 0 : _indice;

    return Scaffold(
      body: IndexedStack(
        index: indice,
        children: [
          HomeScreen(onCambiarPestana: _cambiar),
          const DoctoresScreen(),
          const MisCitasScreen(),
          PerfilScreen(onCambiarPestana: _cambiar),
          // El panel vive dentro del shell, así que no lleva flecha de
          // retroceso: se sale de él cambiando de pestaña.
          if (esAdmin) const AdminScreen(mostrarAtras: false),
        ],
      ),
      // El asistente acompaña a todas las pestañas: es el atajo para
      // cuando alguien no sabe dónde está lo que busca, así que esconderlo
      // dentro de una pantalla concreta sería justo lo contrario.
      // El panel de administración es otra tarea, y ahí estorba.
      floatingActionButton: indice == MainShell.indiceAdmin
          ? null
          : BotonAsistente(key: AnclasTour.asistente),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indice,
        onTap: _cambiar,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: AnclasTour.doctores,
              child: const Icon(Icons.people_outline_rounded),
            ),
            activeIcon: const Icon(Icons.people_rounded),
            label: 'Doctores',
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: AnclasTour.misCitas,
              child: const Icon(Icons.calendar_today_outlined),
            ),
            activeIcon: const Icon(Icons.calendar_today_rounded),
            label: 'Mis Citas',
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: AnclasTour.perfil,
              child: const Icon(Icons.person_outline_rounded),
            ),
            activeIcon: const Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
          if (esAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
