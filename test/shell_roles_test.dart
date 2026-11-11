import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcuidado/app/app_theme.dart';
import 'package:saludcuidado/data/app_state.dart';
import 'package:saludcuidado/models/usuario.dart';
import 'package:saludcuidado/screens/main_shell.dart';

/// Pruebas de interfaz de la barra inferior según el rol.
///
/// TRAZABILIDAD: `navbar.html` del proyecto web muestra el enlace
/// «Panel Admin» solo cuando `hasRole('ADMIN')`, y
/// `RoleBasedAuthenticationSuccessHandler` manda al administrador a `/admin`
/// nada más iniciar sesión. Aquí eso se traduce en una quinta pestaña.
void main() {
  /// Monta MainShell con una sesión ya iniciada, sin tocar la red.
  Future<void> montar(
    WidgetTester tester, {
    required Usuario usuario,
    int indiceInicial = 0,
  }) async {
    // El lienzo por defecto de las pruebas es 800x600 (apaisado) y la fuente
    // de prueba (Ahem) dibuja cada letra como un cuadrado, bastante más ancha
    // que la real; se usa un teléfono generoso para que eso no provoque
    // desbordes falsos que no se dan con la tipografía real.
    tester.view.physicalSize = const Size(1500, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final estado = AppState.local();
    estado.iniciarSesion(usuario);
    await tester.pumpWidget(
      AppStateScope(
        estado: estado,
        child: MaterialApp(
          theme: AppTheme.tema,
          home: MainShell(indiceInicial: indiceInicial),
        ),
      ),
    );
    await tester.pump();
  }

  const paciente = Usuario(
    nombre: 'Brandon Llamas',
    email: 'brandon@saludcuidado.com',
    iniciales: 'BL',
  );

  const administrador = Usuario(
    nombre: 'Administrador',
    email: 'admin@saludcuidado.com',
    iniciales: 'AD',
    roles: ['ROLE_USER', 'ROLE_ADMIN'],
  );

  group('Barra inferior según el rol', () {
    testWidgets('Garantiza: el paciente ve cuatro pestañas y ninguna de admin',
        (tester) async {
      await montar(tester, usuario: paciente);

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Doctores'), findsWidgets);
      expect(find.text('Mis Citas'), findsWidgets);
      expect(find.text('Perfil'), findsWidgets);
      // La pestaña de administración no existe para él.
      expect(find.text('Admin'), findsNothing);

      final barra = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(barra.items.length, 4);
    });

    testWidgets('Garantiza: el administrador ve una quinta pestaña',
        (tester) async {
      await montar(tester, usuario: administrador);

      expect(find.text('Admin'), findsWidgets);
      final barra = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(barra.items.length, 5);
    });

    testWidgets(
        'Garantiza: el administrador entra directo al panel y puede salir',
        (tester) async {
      await montar(
        tester,
        usuario: administrador,
        indiceInicial: MainShell.indiceAdmin,
      );

      // Arranca en la pestaña de administración...
      var barra = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(barra.currentIndex, MainShell.indiceAdmin);

      // ...y la barra sigue siendo utilizable para volver al flujo normal.
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pump();

      barra = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(barra.currentIndex, 0);
    });
  });
}
