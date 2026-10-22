import 'package:flutter/material.dart';
import 'package:forms_app/theme/app_theme.dart';

/// Contenido centrado con ancho máximo y márgenes que se adaptan al tamaño de
/// la pantalla. Reemplaza los márgenes fijos de 350 px de las pantallas viejas.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool scroll;

  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1000,
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final horizontal = ancho < 600 ? 16.0 : 24.0;
    final contenido = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
          child: child,
        ),
      ),
    );
    return scroll ? SingleChildScrollView(child: contenido) : contenido;
  }
}

/// Estado vacío o de error: icono sobrio, mensaje claro y, si aplica, una acción.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: Marca.c50, shape: BoxShape.circle),
                child: Icon(icon, color: Marca.c600),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (actionLabel != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
