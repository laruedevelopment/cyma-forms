// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Muestra el informe de Power BI dentro de la app. El enlace no vive en el
/// código: se lee de Firestore (Configuracion/dashboard, campo `link`), donde
/// solo lo pueden leer MASTER, ADMINISTRADOR y CONSULTOR.
class ConsultasPage extends StatefulWidget {
  const ConsultasPage({super.key});

  @override
  State<ConsultasPage> createState() => _ConsultasPageState();
}

/// Alto de la barra inferior de Power BI que se recorta.
const String _barraInferior = '48px';

class _ConsultasPageState extends State<ConsultasPage> {
  String? _viewType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Configuracion')
          .doc('dashboard')
          .get();
      final link = doc.data()?['link'];
      // Solo se acepta un enlace de Power BI, por si el dato se alterara.
      if (link is String && link.startsWith('https://app.powerbi.com/')) {
        final viewType = 'consultas-powerbi-${link.hashCode}';
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) {
            // La barra inferior de Power BI (compartir, páginas) queda fuera del
            // recuadro: el iframe es más alto y el contenedor recorta el exceso.
            final marco = html.IFrameElement()
              ..src = link
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = 'calc(100% + $_barraInferior)'
              ..setAttribute('referrerpolicy', 'no-referrer')
              ..setAttribute('allowfullscreen', 'true');
            return html.DivElement()
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.overflow = 'hidden'
              ..append(marco);
          },
        );
        _viewType = viewType;
      }
    } catch (_) {
      // Se muestra el mensaje de "no disponible".
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _viewType == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'El informe no está disponible por ahora. Contacta al administrador.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SizedBox.expand(child: HtmlElementView(viewType: _viewType!)),
    );
  }
}
