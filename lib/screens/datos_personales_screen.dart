import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';
import '../data/api/api_cliente.dart';
import '../data/app_state.dart';
import '../widgets/app_text_field.dart';
import '../widgets/avatar_ilustrado.dart';

/// Datos de la cuenta: nombre y contraseña.
///
/// CONTRATO: DatosPersonalesScreen
///   Requiere : sesión iniciada
///   Garantiza: guarda solo lo que el usuario cambió, y deja el nombre
///              actualizado en toda la app sin tener que volver a entrar
///   Falla si : sin servidor -> se avisa y no se guarda nada, porque
///              cambiarlo solo en el teléfono dejaría al dispositivo
///              diciendo una cosa y al servidor otra
///
/// Trazabilidad backend: `PATCH /api/auth/yo`.
///
/// El correo se muestra pero no se edita: es la identidad de la cuenta, y
/// cambiarlo invalidaría las sesiones y las citas asociadas.
class DatosPersonalesScreen extends StatefulWidget {
  const DatosPersonalesScreen({super.key});

  static const String ruta = '/datos-personales';

  @override
  State<DatosPersonalesScreen> createState() => _DatosPersonalesScreenState();
}

class _DatosPersonalesScreenState extends State<DatosPersonalesScreen> {
  static const String _origen = 'DatosPersonalesScreen';

  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  /// El bloque de contraseña está plegado: la mayoría entra solo a
  /// corregir el nombre, y tres campos de contraseña abiertos dan a
  /// entender que hay que rellenarlos.
  bool _cambiarClave = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    traza.navegacion(_origen, 'Datos personales',
        contrato: 'DatosPersonalesScreen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nombre.text = AppStateScope.leer(context).usuarioActual.nombre;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  /// CONTRATO: _guardar
  ///   Requiere : el formulario válido
  ///   Garantiza: envía únicamente los campos que cambiaron; si no cambió
  ///              nada, lo dice en vez de hacer una petición inútil
  Future<void> _guardar() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    final estado = AppStateScope.leer(context);
    final nombreNuevo = _nombre.text.trim();
    final cambiaNombre = nombreNuevo != estado.usuarioActual.nombre;
    final cambiaClave = _cambiarClave && _nueva.text.isNotEmpty;

    if (!cambiaNombre && !cambiaClave) {
      setState(() => _error = 'No has cambiado nada todavía.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await estado.actualizarCuenta(
        nombre: cambiaNombre ? nombreNuevo : null,
        passwordActual: cambiaClave ? _actual.text : null,
        passwordNueva: cambiaClave ? _nueva.text : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cambiaClave
                ? 'Datos guardados. Se cerraron tus otras sesiones.'
                : 'Datos guardados.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on SinConexion {
      if (mounted) {
        setState(() => _error =
            'Sin conexión con el servidor. Tus datos no se han cambiado.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AppStateScope.of(context).usuarioActual;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: AvatarUsuario(
                semilla: usuario.avatarSemilla == 0
                    ? usuario.email.hashCode.abs()
                    : usuario.avatarSemilla,
                tamano: 84,
              ),
            ),
            const SizedBox(height: 22),

            AppTextField(
              label: 'Nombre',
              controller: _nombre,
              prefixIcon: Icons.person_outline_rounded,
              hint: 'Cómo quieres que te llamemos',
              accionTeclado: TextInputAction.done,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe tu nombre'
                  : null,
            ),
            const SizedBox(height: 14),

            // El correo se ve pero no se toca.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSuave,
                borderRadius: BorderRadius.circular(AppTheme.radio),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 19, color: AppColors.textHint),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tu correo identifica la cuenta y no se puede '
                          'cambiar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ------------------------------------------- contraseña
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radio),
              onTap: () => setState(() => _cambiarClave = !_cambiarClave),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 19, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Cambiar contraseña',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _cambiarClave ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ),

            if (_cambiarClave) ...[
              const SizedBox(height: 12),
              // Las tres validaciones solo actúan si hay una contraseña
              // nueva escrita. Si no, desplegar este bloque por curiosidad
              // impediría guardar un simple cambio de nombre.
              AppTextField(
                label: 'Contraseña actual',
                controller: _actual,
                prefixIcon: Icons.lock_clock_outlined,
                esPassword: true,
                validator: (v) => _nueva.text.isNotEmpty && (v == null || v.isEmpty)
                    ? 'Escribe tu contraseña actual'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Contraseña nueva',
                controller: _nueva,
                prefixIcon: Icons.lock_outline_rounded,
                esPassword: true,
                validator: (v) => (v != null && v.isNotEmpty && v.length < 6)
                    ? 'Mínimo 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Repite la nueva',
                controller: _repetir,
                prefixIcon: Icons.lock_reset_rounded,
                esPassword: true,
                accionTeclado: TextInputAction.done,
                validator: (v) => _nueva.text.isNotEmpty && v != _nueva.text
                    ? 'Las contraseñas no coinciden'
                    : null,
              ),
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.textHint),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Al cambiarla se cerrará tu sesión en los demás '
                      'dispositivos.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.peligro.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppTheme.radio),
                  border: Border.all(
                    color: AppColors.peligro.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: AppColors.peligro),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.peligro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
