import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/api/api_cliente.dart';
import '../data/app_state.dart';
import '../widgets/app_text_field.dart';

/// CONTRATO: RegistroScreen (PDF 1.2)
///   Requiere : ningun parametro externo
///   Garantiza: formulario de registro con nombre, email, contrasena,
///              confirmacion y terminos. Al registrar navega a /home
///   Falla si : campos vacios, contrasenas no coinciden o terminos no
///              aceptados -> muestra validacion
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  /// El mock de Penpot indica "Minimo 8 caracteres" en este formulario.
  static const int minPassword = 8;

  // Validaciones estaticas y publicas, verificadas desde las pruebas
  // de contrato (test/contratos_test.dart).

  static String? validarNombre(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'El nombre es obligatorio';
    if (v.length < 3) return 'Ingresa tu nombre completo';
    return null;
  }

  static String? validarEmail(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'El correo es obligatorio';
    if (!v.contains('@') || !v.contains('.')) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  static String? validarPassword(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria';
    if (v.length < minPassword) {
      return 'La contraseña debe tener al menos $minPassword caracteres';
    }
    return null;
  }

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const String _origen = 'RegistroScreen';

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _terminosAceptados = false;
  bool _mostrarErrorTerminos = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------- validaciones

  /// CONTRATO "Falla si": contrasenas no coinciden.
  String? _validarConfirmacion(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Confirma tu contraseña';
    if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  // ------------------------------------------------------------- acciones

  Future<void> _registrar() async {
    final formOk = _formKey.currentState?.validate() ?? false;

    // CONTRATO "Falla si": terminos no aceptados.
    setState(() => _mostrarErrorTerminos = !_terminosAceptados);

    if (!formOk || !_terminosAceptados) {
      traza.validacion(
        _origen,
        'Validación fallida (formulario: $formOk, '
        'términos: $_terminosAceptados): no se navega a ${AppRoutes.home}',
        contrato: 'RegistroScreen.Falla si',
      );
      return;
    }

    setState(() => _enviando = true);
    traza.accion(_origen, 'Datos válidos, creando cuenta...');

    final estado = AppStateScope.leer(context);
    try {
      // Crea el usuario en la base de datos (POST /api/auth/registro).
      await estado.registrarUsuario(
        _nombreCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      traza.error(_origen, 'Registro rechazado: ${e.mensaje}',
          contrato: 'RegistroScreen.Falla si');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.esConflicto
              ? 'Ese correo ya tiene una cuenta registrada.'
              : e.mensaje),
          backgroundColor: AppColors.peligro,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      traza.error(_origen, 'Registro con error inesperado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear la cuenta. Intenta de nuevo.'),
          backgroundColor: AppColors.peligro,
        ),
      );
      return;
    }

    if (!mounted) return;
    traza.navegacion(_origen, 'Registro exitoso -> ${AppRoutes.home}',
        contrato: 'RegistroScreen.Garantiza');
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (ruta) => false);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          tooltip: 'Volver',
          onPressed: () {
            traza.navegacion(_origen, 'Volver a ${AppRoutes.login}');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Únete a SaludCuidado',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crea tu cuenta para gestionar tus citas médicas',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Nombre completo',
                  controller: _nombreCtrl,
                  prefixIcon: Icons.person_outline_rounded,
                  hint: 'Juan Pérez',
                  tipoTeclado: TextInputType.name,
                  validator: RegistroScreen.validarNombre,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Correo electrónico',
                  controller: _emailCtrl,
                  prefixIcon: Icons.mail_outline_rounded,
                  hint: 'usuario@email.com',
                  tipoTeclado: TextInputType.emailAddress,
                  validator: RegistroScreen.validarEmail,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Contraseña',
                  controller: _passCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  hint: 'Mínimo ${RegistroScreen.minPassword} caracteres',
                  esPassword: true,
                  validator: RegistroScreen.validarPassword,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirmar contraseña',
                  controller: _confirmCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  hint: 'Repite tu contraseña',
                  esPassword: true,
                  validator: _validarConfirmacion,
                  accionTeclado: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                _construirTerminos(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _enviando ? null : _registrar,
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
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Ya tienes cuenta?',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Inicia sesión',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirTerminos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Checkbox(
                value: _terminosAceptados,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                onChanged: (v) {
                  setState(() {
                    _terminosAceptados = v ?? false;
                    if (_terminosAceptados) _mostrarErrorTerminos = false;
                  });
                  traza.accion(
                    _origen,
                    'Términos ${_terminosAceptados ? 'aceptados' : 'rechazados'}',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(text: 'Acepto los '),
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_mostrarErrorTerminos)
          const Padding(
            padding: EdgeInsets.only(left: 36, top: 4),
            child: Text(
              'Debes aceptar los términos para continuar',
              style: TextStyle(fontSize: 12, color: AppColors.peligro),
            ),
          ),
      ],
    );
  }
}
