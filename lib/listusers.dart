import 'package:flutter/material.dart';
import 'package:forms_app/newuser.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';

class ListUsersScreen extends StatefulWidget {
  const ListUsersScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListUsersScreenState createState() => _ListUsersScreenState();
}

class _ListUsersScreenState extends State<ListUsersScreen> {
  late Future<List<dynamic>> _futuro;
  final TextEditingController _busqueda = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _futuro = getUsuarios();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _reloadList() {
    setState(() {
      _futuro = getUsuarios();
    });
  }

  void _abrir({dynamic item}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (item == null) {
          return AddEditUser(reloadList: _reloadList, admin: true);
        }
        return AddEditUser(
          reloadList: _reloadList,
          id: item['id'],
          status: item['status'],
          gender: item['gender'],
          typeId: item['idType'],
          role: item['role'],
          sede: item['sede'],
          admin: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nuevo usuario'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos cargar los usuarios',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _reloadList,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = snapshot.data!;
          final q = _filtro.trim().toLowerCase();
          final usuarios = q.isEmpty
              ? todos
              : todos.where((u) {
                  final texto =
                      '${u['name'] ?? ''} ${u['position'] ?? ''} ${u['sede'] ?? ''} ${u['role'] ?? ''}'
                          .toLowerCase();
                  return texto.contains(q);
                }).toList();

          return PageBody(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personas con acceso', style: tema.headlineSmall),
                const SizedBox(height: 4),
                Text('${todos.length} usuarios. Toca uno para editarlo.',
                    style: tema.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _busqueda,
                  onChanged: (v) => setState(() => _filtro = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, rol, cargo o sede',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                if (usuarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child:
                            Text('Ningún usuario coincide con la búsqueda.')),
                  ),
                for (final u in usuarios) ...[
                  _FilaUsuario(item: u, onTap: () => _abrir(item: u)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 72),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;

  const _FilaUsuario({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final detalle = [item['role'], item['position'], item['sede']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .join('  ·  ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? '', style: tema.titleMedium),
                    const SizedBox(height: 2),
                    Text(detalle, style: tema.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              statusChip(item['status'] ?? ''),
            ],
          ),
        ),
      ),
    );
  }
}
