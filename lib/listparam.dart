// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';

class ListParameterScreen extends StatefulWidget {
  final String param;

  const ListParameterScreen({super.key, required this.param});

  @override
  // ignore: library_private_types_in_public_api
  _ListParameterScreenState createState() => _ListParameterScreenState();
}

class _ListParameterScreenState extends State<ListParameterScreen> {
  late Future<List<Map<String, dynamic>>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = getParametro(widget.param);
  }

  void _reloadList() {
    setState(() {
      _futuro = getParametro(widget.param);
    });
  }

  bool _dialogoAbierto = false;

  Future<void> _abrir({Map<String, dynamic>? item}) async {
    if (_dialogoAbierto) return; // evita abrir dos diálogos con un doble toque
    _dialogoAbierto = true;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEditParam(
          param: widget.param,
          reloadList: _reloadList,
          id: item?['id'],
          name: item?['data']['name'],
          status: item?['data']['status'],
        );
      },
    );
    _dialogoAbierto = false;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final titulo = widget.param[0].toUpperCase() +
        widget.param.substring(1).toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos cargar la lista',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _reloadList,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final pendientes =
              items.where((e) => e['data']['status'] == 'PENDIENTE').length;
          return PageBody(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.headlineSmall),
                const SizedBox(height: 4),
                Text('${items.length} registros. Toca uno para editarlo.',
                    style: tema.bodyMedium),
                if (pendientes > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Tinta.avisoFondo,
                      borderRadius: BorderRadius.circular(AppTheme.radioCampo),
                    ),
                    child: Text(
                      pendientes == 1
                          ? 'Hay 1 registro pendiente de revisión. Ábrelo para activarlo o inactivarlo.'
                          : 'Hay $pendientes registros pendientes de revisión. Ábrelos para activarlos o inactivarlos.',
                      style: const TextStyle(color: Tinta.aviso),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Todavía no hay registros.')),
                  ),
                for (final item in items) ...[
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
                      onTap: () => _abrir(item: item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item['data']['name'] ?? '',
                                  style: tema.titleMedium),
                            ),
                            const SizedBox(width: 12),
                            statusChip(item['data']['status'] ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ),
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


// ignore: must_be_immutable
class AddEditParam extends StatefulWidget {
  final String param;
  final String? name; // Nullable to differentiate between adding and editing
  final String? status; // Nullable to differentiate between adding and editing
  final String? id;
  final VoidCallback reloadList;

  AddEditParam({required this.param, this.id, this.name, this.status, required this.reloadList});

  @override
  // ignore: library_private_types_in_public_api
  _AddEditParamState createState() => _AddEditParamState();
}

class _AddEditParamState extends State<AddEditParam> {
  late String id;
  late TextEditingController nameController;
  late String selectedEstado;
  late bool isEditing; // Indicates whether it's an edit operation
  bool isLoading = false; // Loading state

  @override
  void initState() {
    super.initState();
    id = widget.id ?? '';
    nameController = TextEditingController(text: widget.name ?? '');
    if(widget.status == 'PENDIENTE'){
      selectedEstado = 'ACTIVO';
    } else {
      selectedEstado = widget.status ?? 'ACTIVO';
    }
    isEditing = widget.id != null; // If name and status are not null, it's an edit operation
  }

  @override
  Widget build(BuildContext context) {
    final List<String> estados = ['ACTIVO', 'INACTIVO'];

    final nombreParam = widget.param.toLowerCase();
    return AlertDialog(
      title: Text(isEditing ? 'Editar $nombreParam' : 'Agregar a $nombreParam'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTextField('NOMBRE', nameController, false),
            const SizedBox(height: 16),
            buildDropdownField('ESTADO', estados, (value) {
              setState(() {
                selectedEstado = value ?? 'ACTIVO';
              });
            }, initialValue: selectedEstado, allowChange: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Escribe un nombre.')),
                    );
                    return;
                  }
                  setState(() {
                    isLoading = true;
                  });
                  if (isEditing) {
                    _updateParameter(context);
                  } else {
                    _saveParameter(context);
                  }
                },
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }

  void _saveParameter(BuildContext context) async {
    String nombre = nameController.text;
    String estado = selectedEstado;
    String param = widget.param;
    try {
      await saveParameter(param, nombre, estado);
      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardado.'),
          duration: Duration(seconds: 4),
        ),
      );
      // Clear the name field after saving
      nameController.clear();
      // Trigger a refresh of the list by calling setState
      widget.reloadList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      Navigator.of(context).pop();
      setState(() {
        isLoading = false; // Reset loading state
      });
    }
  }

  void _updateParameter(BuildContext context) async {
    String id = widget.id ?? '';
    String nombre = nameController.text;
    String estado = selectedEstado;
    String param = widget.param;

    try {
      await updateParameter(id, param, nombre, estado);

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cambios guardados.'),
          duration: Duration(seconds: 4),
        ),
      );

      // Clear the name field after saving
      nameController.clear();

      // Trigger a refresh of the list by calling setState
      widget.reloadList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $e'),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      Navigator.of(context).pop();
      setState(() {
        isLoading = false; // Reset loading state
      });
    }
  }
}

