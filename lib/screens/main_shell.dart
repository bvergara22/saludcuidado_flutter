import 'package:flutter/material.dart';

import '../core/trace/trace_logger.dart';
import 'doctores_screen.dart';
import 'home_screen.dart';
import 'mis_citas_screen.dart';
import 'perfil_screen.dart';

/// Contenedor con la barra de navegacion inferior (Inicio, Doctores,
/// Mis Citas, Perfil) tal como aparece en los mocks de Penpot.
///
/// Las rutas /home, /doctores, /mis-citas y /perfil abren este shell en la
/// pestana correspondiente, de modo que los nombres de ruta del contrato se
/// conservan sin duplicar pantallas.
class MainShell extends StatefulWidget {
  final int indiceInicial;

  const MainShell({super.key, this.indiceInicial = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const String _origen = 'MainShell';
  static const List<String> _nombres = [
    'Inicio',
    'Doctores',
    'Mis Citas',
    'Perfil',
  ];

  late int _indice = widget.indiceInicial;

  void _cambiar(int i) {
    if (i == _indice) return;
    setState(() => _indice = i);
    traza.navegacion(_origen, 'Pestaña ${_nombres[i]} (índice $i)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          HomeScreen(onCambiarPestana: _cambiar),
          const DoctoresScreen(),
          const MisCitasScreen(),
          const PerfilScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: _cambiar,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Doctores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Mis Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
