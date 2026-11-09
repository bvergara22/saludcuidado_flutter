import 'package:flutter/material.dart';

/// Identidad visual de SaludCuidado.
///
/// El color de marca es el **azul de los mocks de Penpot**, que es el que
/// identifica al proyecto desde el principio. Lo que cambió en esta revisión
/// es el **lienzo**: el fondo de las pantallas ya no es blanco (ni un gris
/// casi blanco), sino un azul grisáceo claro. Así las tarjetas blancas se
/// recortan de verdad sobre el fondo, en lugar de fundirse con él, y la
/// jerarquía se lee sin necesidad de sombras fuertes.
///
/// Todos los colores de marca viven aquí: ninguna pantalla debe escribir un
/// `Color(0xFF...)` de marca a mano, para que un cambio de identidad sea un
/// cambio en un solo archivo.
class AppColors {
  AppColors._();

  // --------------------------------------------------------------- marca
  /// Azul de los mocks: botones, barra superior, estado "próxima".
  static const Color primary = Color(0xFF1A5FBF);
  static const Color primaryDark = Color(0xFF14499A);

  /// Azul profundo para degradados y fondos de cabecera.
  static const Color primaryDeep = Color(0xFF0D3573);
  static const Color primaryLight = Color(0xFF5B90E0);

  /// Azul muy claro: fondos de chip, tarjetas destacadas, rellenos suaves.
  static const Color azulSuave = Color(0xFFDCE7F8);

  /// Acento complementario (ámbar cálido) para rating y llamadas de atención.
  static const Color acento = Color(0xFFF5A623);

  // ----------------------------------------------------------- superficies
  /// Lienzo de las pantallas: azul grisáceo claro, **no** blanco.
  static const Color background = Color(0xFFE8EEF7);

  /// Tarjetas, campos y hojas: blanco, para que destaquen sobre el lienzo.
  static const Color surface = Colors.white;

  /// Superficie intermedia, para secciones alternas dentro de una tarjeta.
  static const Color surfaceSuave = Color(0xFFF2F6FC);
  static const Color border = Color(0xFFD5DEEC);

  // ---------------------------------------------------------------- texto
  static const Color textPrimary = Color(0xFF16202E);
  static const Color textSecondary = Color(0xFF5B6B80);
  static const Color textHint = Color(0xFF93A1B3);

  // ------------------------------------------------------------ semánticos
  static const Color estrella = acento;
  static const Color exito = Color(0xFF16A34A);
  static const Color peligro = Color(0xFFDC2626);
  static const Color aviso = Color(0xFFB45309);

  /// Fondo y texto del banner de aviso (sin conexión).
  static const Color avisoFondo = Color(0xFFFEF3C7);
  static const Color avisoTexto = Color(0xFF92400E);

  /// Texto sobre el fondo rojo claro de los errores de formulario.
  static const Color avisoRojoTexto = Color(0xFF991B1B);

  // ---------------------------------------- colores por especialidad
  // Saturación media parecida en todos, para que ninguna tarjeta grite
  // más que otra, y "Medicina General" en el azul de la marca.
  static const Color cardiologia = Color(0xFFE11D48);
  static const Color pediatria = Color(0xFF7C3AED);
  static const Color dermatologia = Color(0xFF10B981);
  static const Color neurologia = Color(0xFFEA580C);
  static const Color traumatologia = Color(0xFF0369A1);
  static const Color ginecologia = Color(0xFFDB2777);
  static const Color medicinaGeneral = Color(0xFF1A5FBF);
  static const Color odontologia = Color(0xFF4F46E5);

  /// Degradado del SplashScreen.
  static const LinearGradient gradienteSplash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A5FBF), Color(0xFF0D3573)],
  );

  /// Degradado de cabeceras y tarjetas destacadas.
  static const LinearGradient gradienteTarjeta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E6FD0), Color(0xFF14499A)],
  );
}

/// Tipografía, formas y tema de la aplicación.
class AppTheme {
  AppTheme._();

  /// Plus Jakarta Sans: geométrica y ligeramente redondeada, va con los
  /// avatares ilustrados sin perder el aire clínico. Se empaqueta en
  /// `assets/fonts/`, así que no necesita internet en el celular.
  static const String fuente = 'PlusJakartaSans';

  static const double radio = 16;
  static const double radioGrande = 22;
  static const EdgeInsets padPantalla = EdgeInsets.symmetric(horizontal: 16);

  static List<BoxShadow> get sombraTarjeta => [
        BoxShadow(
          color: AppColors.primaryDeep.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Sombra más marcada para elementos elevados (FAB, tarjeta de cita).
  static List<BoxShadow> get sombraElevada => [
        BoxShadow(
          color: AppColors.primaryDeep.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Escala tipográfica de la app.
  ///
  /// Pesos disponibles de la fuente empaquetada: 400, 500, 600, 700 y 800.
  /// Los titulares usan 800 con `letterSpacing` negativo (así se ven
  /// compactos y modernos) y el cuerpo usa 400/500 con altura 1.45 para que
  /// se lea cómodo en pantalla de celular.
  static TextTheme get textos => const TextTheme(
        displaySmall: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
        bodySmall: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      );

  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fuente,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.acento,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fuente,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textHint,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
          textStyle: const TextStyle(
            fontFamily: fuente,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
          textStyle: const TextStyle(
            fontFamily: fuente,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: fuente,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        hintStyle: const TextStyle(
          fontFamily: fuente,
          color: AppColors.textHint,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: AppColors.peligro),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: AppColors.peligro, width: 1.7),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(
          fontFamily: fuente,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fuente,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        showUnselectedLabels: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontFamily: fuente,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioGrande),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fuente,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: fuente,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      textTheme: textos.apply(
        fontFamily: fuente,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
