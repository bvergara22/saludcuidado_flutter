import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/api/api_cliente.dart';
import '../data/app_state.dart';
import '../widgets/app_text_field.dart';
import '../widgets/marca.dart';

/// CONTRATO: LoginScreen (PDF 1.2)
///   Requiere : ningun parametro externo
///   Garantiza: formulario con email y contrasena. Al enviar navega a /home
///   Falla si : email vacio o contrasena < 6 caracteres
///              -> muestra mensaje de validacion, NO navega
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// Longitud minima de contrasena exigida por el contrato del PDF.
  static const int minPassword = 6;

  // Las validaciones son estaticas y publicas para poder verificarlas
  // directamente desde las pruebas de contrato (test/contratos_test.dart).

  /// CONTRATO "Falla si": email vacio.
  static String? validarEmail(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'El correo es obligatorio';
    if (!v.contains('@') || !v.contains('.')) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// CONTRATO "Falla si": contrasena < 6 caracteres.
  static String? validarPassword(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria';
    if (v.length < minPassword) {
      return 'La contraseña debe tener al menos $minPassword caracteres';
    }
    return null;
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _origen = 'LoginScreen';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _enviando = false;

  /// Mensaje devuelto por el backend (credenciales incorrectas, etc.).
  String? _errorServidor;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- acciones

  Future<void> _ingresar() async {
    final valido = _formKey.currentState?.validate() ?? false;

    if (!valido) {
      // CONTRATO: muestra mensaje de validacion y NO navega.
      traza.validacion(
        _origen,
        'Validación fallida: no se navega a ${AppRoutes.home}',
        contrato: 'LoginScreen.Falla si',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _errorServidor = null;
    });
    traza.accion(_origen, 'Credenciales válidas, autenticando...');

    final estado = AppStateScope.leer(context);
    final email = _emailCtrl.text.trim();

    try {
      // Autenticación real contra POST /api/auth/login.
      await estado.autenticar(email, _passCtrl.text);
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorServidor = e.esNoAutorizado
            ? 'Correo o contraseña incorrectos.'
            : e.mensaje;
      });
      traza.error(_origen, 'Login rechazado: ${e.mensaje}',
          contrato: 'LoginScreen.Falla si');
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorServidor = 'No se pudo iniciar sesión. Intenta de nuevo.';
      });
      traza.error(_origen, 'Login con error inesperado: $e');
      return;
    }

    if (!mounted) return;
    traza.navegacion(_origen, 'Login exitoso -> ${AppRoutes.home}',
        contrato: 'LoginScreen.Garantiza');
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  /// Rellena el formulario con la cuenta sembrada en la base de datos.
  void _usarCuentaDemo() {
    setState(() {
      _emailCtrl.text = 'brandon@saludcuidado.com';
      _passCtrl.text = 'demo1234';
      _errorServidor = null;
    });
    traza.accion(_origen, 'Credenciales de demostración cargadas');
  }

  void _irARegistro() {
    traza.navegacion(_origen, 'Navegando a ${AppRoutes.registro}');
    Navigator.of(context).pushNamed(AppRoutes.registro);
  }

  /// Aviso de error del servidor sobre el botón de ingreso.
  Widget _bannerError(String mensaje) => Container(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.peligro.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.peligro.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 19, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.avisoRojoTexto,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                const Center(child: MarcaSaludCuidado(tamano: 84)),
                const SizedBox(height: 26),
                const Text(
                  'Bienvenido de nuevo',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inicia sesión para gestionar tus citas médicas',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Correo electrónico',
                  controller: _emailCtrl,
                  prefixIcon: Icons.mail_outline_rounded,
                  hint: 'usuario@email.com',
                  tipoTeclado: TextInputType.emailAddress,
                  validator: LoginScreen.validarEmail,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Contraseña',
                  controller: _passCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  hint: 'Mínimo ${LoginScreen.minPassword} caracteres',
                  esPassword: true,
                  validator: LoginScreen.validarPassword,
                  accionTeclado: TextInputAction.done,
                  onSubmitted: (_) => _ingresar(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      traza.accion(_origen, 'Recuperar contraseña (demo)');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Función de recuperación no incluida en el prototipo',
                          ),
                        ),
                      );
                    },
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                if (_errorServidor != null) _bannerError(_errorServidor!),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: _enviando ? null : _ingresar,
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta?',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _irARegistro,
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _enviando ? null : _usarCuentaDemo,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Usar cuenta de demostración'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
