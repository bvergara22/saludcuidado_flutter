import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// CONTRATO: AppTextField (PDF 1.3)
///   Requiere : label: String, controller: TextEditingController,
///              prefixIcon: IconData
///   Garantiza: campo de texto estilizado con label e icono.
///              Retorna el texto ingresado via controller
///   Falla si : controller es null -> error de compilacion
class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final String? hint;
  final bool esPassword;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validator;
  final TextInputAction accionTeclado;
  final void Function(String)? onSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.hint,
    this.esPassword = false,
    this.tipoTeclado = TextInputType.text,
    this.validator,
    this.accionTeclado = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _oculto = widget.esPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          obscureText: _oculto,
          keyboardType: widget.tipoTeclado,
          validator: widget.validator,
          textInputAction: widget.accionTeclado,
          onFieldSubmitted: widget.onSubmitted,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(
              widget.prefixIcon,
              size: 20,
              color: AppColors.textHint,
            ),
            suffixIcon: widget.esPassword
                ? IconButton(
                    icon: Icon(
                      _oculto
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                    tooltip: _oculto ? 'Mostrar' : 'Ocultar',
                    onPressed: () => setState(() => _oculto = !_oculto),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
