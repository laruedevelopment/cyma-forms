// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/hours_utils.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';

class AddEditForm extends StatefulWidget {
  final String? id; // Nullable to differentiate between adding and editing
  final String? name;
  final String? startDate;
  final String? endDate;
  final String? days;
  final String? status;
  final String? hours;
  final String tipo;
  final VoidCallback reloadList;

  const AddEditForm({
    super.key,
    this.id,
    this.name,
    this.startDate,
    this.endDate,
    this.days,
    this.status,
    this.hours,
    required this.tipo,
    required this.reloadList,
  });

  @override
  _AddEditFormState createState() => _AddEditFormState();
}

class _AddEditFormState extends State<AddEditForm> {
  late TextEditingController nameController;
  late TextEditingController startDateController;
  late TextEditingController endDateController;
  late TextEditingController daysController;
  final CollectionReference encuestas =
      FirebaseFirestore.instance.collection('Encuestas');

  List<Map<String, dynamic>> activeUsers = [];
  List<bool> userSelection = [];
  bool selectAll = false;
  bool activarEncuesta = false;
  String selectedStatus = 'CREADA';
  List<String> selectedUsers = [];
  List<bool> preloadedSelection = [];
  TextEditingController hoursController = TextEditingController();
  List<String> statuses = ['CREADA', 'ACTIVA', 'CERRADA'];
  late QuerySnapshot activeUsersSnapshot;
  // Al editar, el botón de guardar espera a que carguen las personas ya asignadas.
  late bool isLoading = widget.id != null;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    startDateController = TextEditingController();
    endDateController = TextEditingController();
    daysController = TextEditingController();
    hoursController.text = '0';
    _loadActiveUsers();

    if (widget.id != null) {
      setState(() {
        nameController.text = widget.name ?? '';
        startDateController.text = widget.startDate ?? '';
        endDateController.text = widget.endDate ?? '';
        daysController.text = widget.days ?? '';
        selectedStatus = widget.status ?? 'CREADA';
        statuses = widget.status == 'ACTIVA' || widget.status == 'CERRADA'
            ? ['ACTIVA', 'CERRADA']
            : ['CREADA', 'ACTIVA', 'CERRADA'];
        activarEncuesta =
            widget.status == 'ACTIVA' || widget.status == 'CERRADA'
                ? true
                : false;
        if (widget.hours != null && widget.hours!.isNotEmpty) {
          hoursController.text = widget.hours!;
        } else {
          hoursController.text =
              calcularHorasEsperadas(daysController.text).toString();
        }
      });
    } else {
      setState(() {
        selectAll = false;
      });
    }
  }

  Future<void> _loadActiveUsers() async {
    try {
      Query activeUsersQuery = FirebaseFirestore.instance
          .collection('Usuarios')
          .orderBy('name') // Order by 'name' field from A to Z
          .where('status', isEqualTo: 'ACTIVO')
          .where('role', isEqualTo: 'USUARIO');

      if (widget.tipo == 'T') {
        // No additional filters needed
      } else if (widget.tipo == 'U') {
        activeUsersQuery =
            activeUsersQuery.where('position', isNotEqualTo: 'CG0007');
      } else if (widget.tipo == 'G') {
        activeUsersQuery =
            activeUsersQuery.where('position', isEqualTo: 'CG0007');
      }

      try {
        activeUsersSnapshot = await activeUsersQuery.get();
      } catch (e) {
        print('Error getting active users: $e');
      }

      Map<String, String> positionNames = {};
      Map<String, String> professionNames = {};

      final results = await Future.wait([
        catalogo('Cargos'),
        catalogo('Profesiones'),
      ]);

      positionNames = {
        for (var d in results[0])
          d['id'] as String:
              d['data']['name'] as String? ?? 'Unknown Position'
      };
      professionNames = {
        for (var d in results[1])
          d['id'] as String:
              d['data']['name'] as String? ?? 'Unknown Profession'
      };

      setState(() {
        activeUsers = activeUsersSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>?;

          if (data == null || !data.containsKey('status')) {
            data ??= {};
            data['status'] = 'NO ASIGNADA';
          }

          String positionName =
              positionNames[data['position']] ?? 'Unknown Position';
          String professionName =
              professionNames[data['profession']] ?? 'Unknown Profession';

          data['positionName'] = positionName;
          data['professionName'] = professionName;
          data['userId'] = doc.id;

          return data;
        }).toList();

        userSelection = List<bool>.filled(activeUsers.length, false);
        preloadedSelection = List<bool>.filled(
            activeUsers.length, false); // Initialize preloadedSelection

      });
      if (widget.id != null) {
        await _loadSelectedUsers(widget.id!);
      }
    } catch (e) {
      print('Error loading active users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No pudimos cargar a las personas. Cierra y vuelve a abrir la encuesta.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadSelectedUsers(String id) async {
    var selectedUsersSnapshot = await FirebaseFirestore.instance
        .collection('Encuestas')
        .doc(id)
        .collection('Usuarios')
        .get();
    var selectedUsersIds =
        selectedUsersSnapshot.docs.map((doc) => doc.id).toList();
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < activeUsers.length; i++) {
        if (selectedUsersIds.contains(activeUsersSnapshot.docs[i].id)) {
          userSelection[i] = true;
          selectedUsers.add(activeUsersSnapshot.docs[i].id);
          preloadedSelection[i] = true; // Mark this item as preloaded selected
        } else {
          preloadedSelection[i] = false;
        }
      }
    });
    if (preloadedSelection.where((element) => element).length ==
        activeUsers.length) {
      selectAll = true;
    } else {
      selectAll = false;
    }
  }

  void _updateSelectAll() {
    setState(() {
      selectAll = userSelection.every((element) => element);
    });
  }

  String _filtro = '';

  String get _textoBoton {
    if (activarEncuesta && widget.status != 'CREADA') {
      if (selectedStatus == 'CERRADA') {
        return widget.status != selectedStatus
            ? 'Cerrar encuesta'
            : 'Guardar cambios';
      }
      return widget.status != selectedStatus
          ? 'Activar encuesta'
          : 'Guardar cambios';
    }
    return widget.id == null ? 'Crear encuesta' : 'Guardar cambios';
  }

  void _seleccionarTodos(bool value) {
    setState(() {
      selectAll = value;
      userSelection = List<bool>.filled(activeUsers.length, value);
      selectedUsers.clear();
      if (value) {
        selectedUsers.addAll(activeUsers
            .where((user) => user['userId'] != null)
            .map((user) => user['userId'] as String));
      }
    });
  }

  Widget _seccion(BuildContext context, String titulo, Widget hijo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            hijo,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final ancho = MediaQuery.of(context).size.width;
    final angosto = ancho < 640;
    final q = _filtro.trim().toLowerCase();
    final indices = <int>[
      for (int i = 0; i < activeUsers.length; i++)
        if (q.isEmpty ||
            '${activeUsers[i]['name'] ?? ''} ${activeUsers[i]['professionName']} ${activeUsers[i]['positionName']} ${activeUsers[i]['sede'] ?? ''}'
                .toLowerCase()
                .contains(q))
          i
    ];
    final puedeElegir = selectedStatus == 'CREADA';
    final totalElegidos = userSelection.where((e) => e).length;

    Widget campoDias = TextFormField(
      controller: daysController,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly
      ],
      decoration: const InputDecoration(labelText: 'DÍAS HÁBILES'),
      onChanged: (value) {
        hoursController.text = calcularHorasEsperadas(value).toString();
      },
    );

    Widget fila(List<Widget> hijos) => angosto
        ? Column(children: [
            for (final h in hijos) ...[h, const SizedBox(height: 14)]
          ])
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (int i = 0; i < hijos.length; i++) ...[
                Expanded(child: hijos[i]),
                if (i < hijos.length - 1) const SizedBox(width: 14),
              ]
            ]),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id != null ? 'Editar encuesta' : 'Nueva encuesta'),
      ),
      body: Stack(
        children: [
          PageBody(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _seccion(
                  context,
                  'Datos de la encuesta',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildTextField('NOMBRE', nameController, false),
                      const SizedBox(height: 14),
                      fila([
                        buildDateField(
                            'FECHA DE INICIO', startDateController, context),
                        buildDateField('FECHA DE FINALIZACIÓN',
                            endDateController, context),
                      ]),
                      fila([
                        campoDias,
                        buildTextField('HORAS ESPERADAS', hoursController, true),
                      ]),
                      fila([
                        buildDropdownField('ESTADO', statuses, (value) {
                          setState(() {
                            selectedStatus = value ?? 'CREADA';
                          });
                        },
                            initialValue: selectedStatus,
                            allowChange:
                                widget.id == null || widget.status == 'CREADA'
                                    ? false
                                    : true),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Activar la encuesta al guardar'),
                          value: activarEncuesta,
                          onChanged:
                              widget.status == 'CREADA' || widget.status == null
                                  ? (bool? value) {
                                      setState(() {
                                        activarEncuesta = value ?? false;
                                      });
                                    }
                                  : null,
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _seccion(
                  context,
                  'Quién responde ($totalElegidos de ${activeUsers.length})',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _filtro = v),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre, profesión, cargo o sede',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      if (puedeElegir)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Seleccionar a todos'),
                          value: selectAll,
                          onChanged: (v) => _seleccionarTodos(v ?? false),
                        ),
                      const Divider(height: 1),
                      if (indices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                                activeUsers.isEmpty
                                    ? 'No hay usuarios activos para este tipo de encuesta.'
                                    : 'Nadie coincide con la búsqueda.',
                                style: tema.bodyMedium),
                          ),
                        ),
                      for (final index in indices)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(activeUsers[index]['name'] ?? ''),
                          subtitle: Text(
                              '${activeUsers[index]['professionName']}  ·  ${activeUsers[index]['positionName']}  ·  ${activeUsers[index]['sede'] ?? ''}'),
                          value: userSelection[index],
                          onChanged: selectedStatus == 'CERRADA' ||
                                  (preloadedSelection[index] &&
                                      selectedStatus != 'CREADA')
                              ? null
                              : (bool? selected) {
                                  final userId = activeUsers[index]['userId'];
                                  setState(() {
                                    userSelection[index] = selected!;
                                    if (selected) {
                                      selectedUsers.add(userId);
                                    } else {
                                      selectedUsers.remove(userId);
                                    }
                                    _updateSelectAll();
                                  });
                                },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                firebaseButton(context, _textoBoton, _saveOrEditSurvey,
                    loading: isLoading),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _validateForm() {
    if (nameController.text.isEmpty ||
        startDateController.text.isEmpty ||
        endDateController.text.isEmpty ||
        daysController.text.isEmpty ||
        hoursController.text.isEmpty ||
        hoursController.text == '0' ||
        selectedStatus.isEmpty) {
      return false;
    }
    return true;
  }

  void _saveOrEditSurvey() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos: nombre, fechas y días hábiles.')),
      );
      return;
    }

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('Encuestas')
        .where('name', isEqualTo: nameController.text)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      bool shouldSkip = false;

      // Iterate through the documents to check if doc.id matches id.widget
      for (var doc in querySnapshot.docs) {
        if (widget.id != null && doc.id == widget.id) {
          shouldSkip = true;
          break; // Exit the loop once the matching document is found
        }
      }

      if (!shouldSkip) {
        // Name already in use, and it's not the current document
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ya existe una encuesta con ese nombre.'),
            duration: Duration(seconds: 4),
          ),
        );
        return; // Exit the function if name is in use
      }
    }

    setState(() {
      isLoading = true; // Set loading state to true
    });

    try {
      if (widget.id != null) {
        await _updateSurvey();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encuesta actualizada.')),
        );
      } else {
        if (selectedUsers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Elige al menos una persona para la encuesta.')),
          );
          return;
        }

        await _addSurvey();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encuesta creada.')),
        );
      }

      widget.reloadList();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      setState(() {
        isLoading = false; // Set loading state to false
      });
    }
  }

  Future<void> _addSurvey() async {
    String id = await idGenerator(encuestas, 'Encuestas');
    var newSurveyDoc =
        FirebaseFirestore.instance.collection('Encuestas').doc(id);
    await newSurveyDoc.set({
      'name': nameController.text,
      'startDate': startDateController.text,
      'endDate': endDateController.text,
      'days': daysController.text,
      'status': activarEncuesta == true ? 'ACTIVA' : selectedStatus,
      'hours': hoursController.text,
      'tipo': widget.tipo
    });

    // Retrieve the selected user IDs
    List<String> selectedUserIds = userSelection
        .asMap()
        .entries
        .where((entry) => entry.value)
        .map((entry) => activeUsersSnapshot.docs[entry.key].id)
        .toList();

    await _escribirEnLotes([
      for (final userId in selectedUserIds)
        (b) => b.set(newSurveyDoc.collection('Usuarios').doc(userId),
            {'status': 'ABIERTA'})
    ]);
  }

  Future<void> _updateSurvey() async {
    var surveyDoc =
        FirebaseFirestore.instance.collection('Encuestas').doc(widget.id);

    try {
      // Update the main survey document
      await surveyDoc.update({
        'name': nameController.text,
        'startDate': startDateController.text,
        'endDate': endDateController.text,
        'days': daysController.text,
        'status': activarEncuesta == true && widget.status == 'CREADA'
            ? 'ACTIVA'
            : selectedStatus,
        'hours': hoursController.text,
      });

      var userCollection = surveyDoc.collection('Usuarios');
      var currentUsers = await userCollection.get();

      final existentes = currentUsers.docs.map((d) => d.id).toSet();
      final operaciones = <void Function(WriteBatch)>[];

      // Quita a quien ya no está elegido, salvo si ya envió su respuesta.
      // Solo a quienes se podían ver en la lista: quien ya no está activo
      // (o cambió de rol) conserva su registro.
      final visibles = activeUsers.map((u) => u['userId']).toSet();
      for (var doc in currentUsers.docs) {
        if (visibles.contains(doc.id) &&
            !selectedUsers.contains(doc.id) &&
            doc.data()['status'] != 'ENVIADA') {
          operaciones.add((b) => b.delete(userCollection.doc(doc.id)));
        }
      }

      // Agrega a quienes se eligieron y todavía no estaban.
      for (var userId in selectedUsers.toSet()) {
        if (!existentes.contains(userId)) {
          operaciones.add((b) =>
              b.set(userCollection.doc(userId), {'status': 'ABIERTA'}));
        }
      }
      await _escribirEnLotes(operaciones);
    } catch (e) {
      print('Failed to update survey: $e');
      rethrow;
    }
  }

  /// Escribe en lotes de hasta 400 operaciones (límite de Firestore: 500)
  /// en vez de una petición por persona.
  Future<void> _escribirEnLotes(
      List<void Function(WriteBatch)> operaciones) async {
    const tamano = 400;
    for (int i = 0; i < operaciones.length; i += tamano) {
      final batch = FirebaseFirestore.instance.batch();
      for (final op in operaciones.skip(i).take(tamano)) {
        op(batch);
      }
      await batch.commit();
    }
  }
}
