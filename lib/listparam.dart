// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/limpieza_catalogo.dart';
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

/// Nombre sin tildes, mayúsculas ni signos, para detectar repetidos.
String _clave(String nombre) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const a = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final sb = StringBuffer();
  for (final r in nombre.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    sb.write(i >= 0 ? a[i] : c);
  }
  return sb.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _ListParameterScreenState extends State<ListParameterScreen> {
  late Future<List<Map<String, dynamic>>> _futuro;
  bool _verInactivos = false;
  final TextEditingController _busqueda = TextEditingController();
  String _filtro = '';

  /// La limpieza solo aplica a proyectos y actividades: son lo que las
  /// respuestas guardan por código y lo que antes se podía crear libremente.
  bool get _permiteLimpieza =>
      widget.param == 'Proyectos' || widget.param == 'Actividades';

  @override
  void initState() {
    super.initState();
    _futuro = getParametro(widget.param);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _reloadList() {
    setState(() {
      _futuro = getParametro(widget.param);
    });
  }

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

  bool _dialogoAbierto = false;

  Future<void> _limpiar(List<Map<String, dynamic>> items) async {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar sin uso'),
        content: const SizedBox(
          width: 420,
          child: Text(
              'Se revisan todas las respuestas, una sola vez (puede tardar un minuto), para saber qué registros inactivos o pendientes nunca se usaron.\n\n'
              'Los que alguien usó en una respuesta se conservan, solo ocultos, para no dejar encuestas sin nombre. No se borra nada hasta que lo confirmes.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revisar')),
        ],
      ),
    );
    if (seguir != true || !mounted) return;

    final mensaje = ValueNotifier<String>('Preparando…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 360,
          child: Row(children: [
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: mensaje,
                builder: (context, m, _) => Text(m),
              ),
            ),
          ]),
        ),
      ),
    );

    ResultadoLimpieza? r;
    try {
      r = await analizarCatalogo(
          widget.param, items, (m) => mensaje.value = m);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // cierra el progreso

    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo revisar. Inténtalo de nuevo.')));
      return;
    }
    final resultado = r;
    if (resultado.sinUso.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultado.enUso.isEmpty
            ? 'No hay registros inactivos ni pendientes.'
            : 'Los ${resultado.enUso.length} registros inactivos aparecen en respuestas y se conservan.'),
        duration: const Duration(seconds: 6),
      ));
      return;
    }

    final borrar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Se pueden eliminar ${resultado.sinUso.length}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Nadie los usó en ninguna respuesta.${resultado.enUso.isEmpty ? '' : ' Otros ${resultado.enUso.length} se conservan porque sí aparecen en respuestas.'}'),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    resultado.sinUso
                        .map((e) =>
                            '• ${e['data']['name']}  (${e['id']}, ${(e['data']['status'] ?? '').toString().toLowerCase()})')
                        .join('\n'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No borrar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Tinta.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar ${resultado.sinUso.length}'),
          ),
        ],
      ),
    );
    if (borrar != true || !mounted) return;

    try {
      await eliminarDelCatalogo(widget.param,
          [for (final e in resultado.sinUso) e['id'] as String]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Se eliminaron ${resultado.sinUso.length} registros.')));
      _reloadList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')));
    }
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
          final todos = snapshot.data!;
          final inactivos =
              todos.where((e) => e['data']['status'] == 'INACTIVO').length;
          // La búsqueda ignora tildes, mayúsculas y signos: "ica seco" encuentra "ICÁ SECO".
          final buscado = _clave(_filtro);
          final items = todos.where((e) {
            if (!_verInactivos && e['data']['status'] == 'INACTIVO') {
              return false;
            }
            if (buscado.isEmpty) return true;
            return _clave((e['data']['name'] ?? '').toString())
                    .contains(buscado) ||
                e['id'].toString().toLowerCase().contains(_filtro.trim().toLowerCase());
          }).toList();
          final pendientes =
              todos.where((e) => e['data']['status'] == 'PENDIENTE').length;

          // Nombres que se repiten (sin contar tildes ni mayúsculas)
          final cuenta = <String, int>{};
          for (final e in todos) {
            final k = _clave((e['data']['name'] ?? '').toString());
            cuenta[k] = (cuenta[k] ?? 0) + 1;
          }

          return PageBody(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.headlineSmall),
                const SizedBox(height: 4),
                Text(
                    '${todos.where((e) => e['data']['status'] == 'ACTIVO').length} registros activos. Toca uno para editarlo.',
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
                TextField(
                  controller: _busqueda,
                  onChanged: (v) => setState(() => _filtro = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtro.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _busqueda.clear();
                              _filtro = '';
                            }),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (inactivos > 0)
                      FilterChip(
                        label: Text(_verInactivos
                            ? 'Ocultar inactivos ($inactivos)'
                            : 'Mostrar inactivos ($inactivos)'),
                        selected: _verInactivos,
                        onSelected: (v) => setState(() => _verInactivos = v),
                      ),
                    if (_permiteLimpieza &&
                        todos.any((e) => e['data']['status'] != 'ACTIVO'))
                      OutlinedButton.icon(
                        onPressed: () => _limpiar(todos),
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Limpiar sin uso'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_filtro.trim().isNotEmpty && items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        '${items.length} ${items.length == 1 ? 'resultado' : 'resultados'}',
                        style: tema.bodySmall),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text(_filtro.trim().isEmpty
                            ? 'Todavía no hay registros.'
                            : _verInactivos
                                ? 'Nada coincide con la búsqueda.'
                                : 'Nada coincide con la búsqueda. Prueba con "Mostrar inactivos".')),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['data']['name'] ?? '',
                                      style: tema.titleMedium),
                                  if ((cuenta[_clave((item['data']['name'] ?? '')
                                              .toString())] ??
                                          0) >
                                      1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Posible repetido',
                                          style: tema.bodySmall?.copyWith(
                                              color: Tinta.aviso)),
                                    ),
                                ],
                              ),
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

