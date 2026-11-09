import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../core/trace/trace_logger.dart';

/// Visor en vivo de la traza de la aplicacion.
///
/// Permite demostrar la trazabilidad del flujo sin depender de la consola:
/// cada navegacion, accion, validacion y cambio de datos queda listado con
/// su origen, su marca de tiempo y el contrato del PDF que lo respalda.
class TrazabilidadScreen extends StatefulWidget {
  const TrazabilidadScreen({super.key});

  @override
  State<TrazabilidadScreen> createState() => _TrazabilidadScreenState();
}

class _TrazabilidadScreenState extends State<TrazabilidadScreen> {
  TipoEvento? _filtro;

  Color _color(TipoEvento tipo) {
    switch (tipo) {
      case TipoEvento.navegacion:
        return AppColors.primary;
      case TipoEvento.accion:
        return AppColors.odontologia;
      case TipoEvento.validacion:
        return AppColors.neurologia;
      case TipoEvento.datos:
        return AppColors.exito;
      case TipoEvento.error:
        return AppColors.peligro;
    }
  }

  IconData _icono(TipoEvento tipo) {
    switch (tipo) {
      case TipoEvento.navegacion:
        return Icons.alt_route_rounded;
      case TipoEvento.accion:
        return Icons.touch_app_outlined;
      case TipoEvento.validacion:
        return Icons.rule_rounded;
      case TipoEvento.datos:
        return Icons.storage_rounded;
      case TipoEvento.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trazabilidad del flujo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copiar traza',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: traza.exportarTexto()),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Traza copiada al portapapeles')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Limpiar',
            onPressed: () => traza.limpiar(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: traza,
        builder: (context, _) {
          final todos = traza.eventosRecientes;
          final eventos = _filtro == null
              ? todos
              : todos.where((e) => e.tipo == _filtro).toList();

          return Column(
            children: [
              _filtros(todos),
              Expanded(
                child: eventos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Aún no hay eventos registrados.\n'
                            'Navega por la aplicación y vuelve aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                        itemCount: eventos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _tarjeta(eventos[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filtros(List<EventoTraza> todos) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _chip('Todos (${todos.length})', _filtro == null,
              AppColors.textPrimary, () => setState(() => _filtro = null)),
          for (final t in TipoEvento.values) ...[
            const SizedBox(width: 8),
            _chip(
              '${t.etiqueta} (${todos.where((e) => e.tipo == t).length})',
              _filtro == t,
              _color(t),
              () => setState(() => _filtro = t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String texto, bool activo, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? color : AppColors.border),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            color: activo ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(EventoTraza e) {
    final color = _color(e.tipo);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_icono(e.tipo), size: 17, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.origen,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      e.horaTexto,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  e.mensaje,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (e.contrato != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.contrato!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
