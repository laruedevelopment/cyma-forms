// ignore_for_file: library_private_types_in_public_api

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/consultas.dart';
import 'package:forms_app/listforms.dart';
import 'package:forms_app/listparam.dart';
import 'package:forms_app/listusers.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/signinpage.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/userforms.dart';
import 'package:forms_app/widgets/page_body.dart';

class MainMenu extends StatefulWidget {
  final String? role;
  final String? uid;
  const MainMenu({super.key, required this.role, required this.uid});
  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  String role = 'ANON';
  String uid = '';
  late final Future<Map<String, dynamic>?> _usuario;

  @override
  void initState() {
    super.initState();
    role = widget.role ?? role;
    uid = widget.uid ?? uid;
    _usuario = uid.isEmpty ? Future.value(null) : fetchUserData(uid);
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (_) => false,
    );
  }

  String _primerNombre(Map<String, dynamic>? datos) {
    final nombre = (datos?['name'] as String?)?.trim() ?? '';
    if (nombre.isEmpty) return '';
    final primero = nombre.split(' ').first;
    return primero[0].toUpperCase() + primero.substring(1).toLowerCase();
  }

  String get _rolVisible {
    switch (role) {
      case 'MASTER':
        return 'Master';
      case 'ADMINISTRADOR':
        return 'Administrador';
      case 'CONSULTOR':
        return 'Consultor';
      default:
        return '';
    }
  }

  void _ir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final esAdmin = role != 'USUARIO';
    final puedeResponder = role != 'ADMINISTRADOR';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_outlined,
                color: Dorado.c500, size: 24),
            SizedBox(width: 10),
            Text('Encuestas MOP'),
          ],
        ),
        actions: [
          if (_rolVisible.isNotEmpty && MediaQuery.of(context).size.width > 600)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(_rolVisible,
                    style: const TextStyle(color: Marca.c100, fontSize: 13)),
              ),
            ),
          TextButton.icon(
            onPressed: _cerrarSesion,
            style: TextButton.styleFrom(foregroundColor: Marca.c100),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Salir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageBody(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _usuario,
              builder: (context, snap) {
                final nombre = _primerNombre(snap.data);
                return Text(nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                    style: tema.headlineSmall);
              },
            ),
            const SizedBox(height: 4),
            Text('¿Qué quieres hacer hoy?', style: tema.bodyMedium),
            if (puedeResponder)
              _Seccion(
                titulo: 'Mis encuestas',
                tiles: [
                  _Opcion(
                    icono: Icons.edit_note,
                    titulo: 'Responder encuesta',
                    detalle: 'Registra tus horas por proyecto y actividad.',
                    onTap: () => _ir(ListUserForms(uid: uid)),
                  ),
                ],
              ),
            if (esAdmin) ...[
              _Seccion(
                titulo: 'Seguimiento',
                tiles: [
                  _Opcion(
                    icono: Icons.assignment_outlined,
                    titulo: 'Administrar encuestas',
                    detalle:
                        'Crea, activa y cierra encuestas, y revisa quién ha respondido.',
                    onTap: () => _ir(ListFormsScreen()),
                  ),
                  _Opcion(
                    icono: Icons.analytics_outlined,
                    titulo: 'Consultas',
                    detalle: 'Informes de horas y dedicación.',
                    onTap: () => _ir(const ConsultasPage()),
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Personas y catálogos',
                tiles: [
                  _Opcion(
                    icono: Icons.people_outline,
                    titulo: 'Usuarios',
                    detalle: 'Altas, roles y estado de las personas.',
                    onTap: () => _ir(ListUsersScreen()),
                  ),
                  _Opcion(
                    icono: Icons.business_center_outlined,
                    titulo: 'Proyectos',
                    detalle: 'Proyectos en los que se registran horas.',
                    onTap: () => _ir(ListParameterScreen(param: 'Proyectos')),
                  ),
                  _Opcion(
                    icono: Icons.task_outlined,
                    titulo: 'Actividades',
                    detalle: 'Tipos de actividad que se pueden reportar.',
                    onTap: () => _ir(ListParameterScreen(param: 'Actividades')),
                  ),
                  _Opcion(
                    icono: Icons.work_outline,
                    titulo: 'Cargos',
                    detalle: 'Cargos disponibles para las personas.',
                    onTap: () => _ir(ListParameterScreen(param: 'Cargos')),
                  ),
                  _Opcion(
                    icono: Icons.school_outlined,
                    titulo: 'Profesiones',
                    detalle: 'Profesiones disponibles para las personas.',
                    onTap: () => _ir(ListParameterScreen(param: 'Profesiones')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Opcion {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final List<_Opcion> tiles;
  const _Seccion({required this.titulo, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Tinta.textoSuave)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final columnas = c.maxWidth >= 640 ? 2 : 1;
            const espacio = 12.0;
            final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              children: [
                for (final o in tiles)
                  SizedBox(width: ancho, child: _Tile(opcion: o)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  final _Opcion opcion;
  const _Tile({required this.opcion});

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.opcion;
    final tema = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _encima ? Marca.c50 : Tinta.superficie,
          borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
          border: Border.all(color: _encima ? Marca.c200 : Tinta.borde),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
            onTap: o.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _encima ? Colors.white : Marca.c50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(o.icono, color: Marca.c600, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.titulo, style: tema.titleSmall),
                        const SizedBox(height: 2),
                        Text(o.detalle, style: tema.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Tinta.deshabilitado, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
