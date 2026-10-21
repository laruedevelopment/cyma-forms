// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/hours_utils.dart';
import 'package:forms_app/widgets/forms_widgets.dart';

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

  AddEditForm({
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
  bool isLoading = false;

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

      final CollectionReference positions =
          FirebaseFirestore.instance.collection('Cargos');
      final CollectionReference professions =
          FirebaseFirestore.instance.collection('Profesiones');
      final positionQuery = positions.get();
      final professionQuery = professions.get();
      final results = await Future.wait([positionQuery, professionQuery]);

      final positionDocs = results[0].docs;
      final professionDocs = results[1].docs;

      positionNames = {
        for (var document in positionDocs)
          document.id:
              (document.data() as Map<String, dynamic>)['name'] as String? ??
                  'Unknown Position'
      };
      professionNames = {
        for (var document in professionDocs)
          document.id:
              (document.data() as Map<String, dynamic>)['name'] as String? ??
                  'Unknown Profession'
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

        if (widget.id != null) {
          _loadSelectedUsers(widget.id!);
          if (preloadedSelection.length == activeUsers.length) {
            selectAll = true;
          }
        } else {
          userSelection = List<bool>.filled(activeUsers.length, false);
        }
      });
    } catch (e) {
      print('Error loading active users: $e');
      // Handle the error, e.g., show a Snackbar or an alert
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Text(
                widget.id != null ? 'EDITAR ENCUESTA' : 'AGREGAR ENCUESTA')),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(350, 50, 350, 50),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 10),
                  buildTextField('NOMBRE', nameController, false),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: buildDateField(
                              'FECHA DE INICIO', startDateController, context)),
                      SizedBox(width: 10),
                      Expanded(
                          child: buildDateField('FECHA DE FINALIZACIÓN',
                              endDateController, context)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: 600,
                          child: TextFormField(
                            controller: daysController,
                            readOnly: false,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                              labelText: 'DÍAS HÁBILES',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                            ),
                            onChanged: (value) {
                              hoursController.text =
                                  calcularHorasEsperadas(value).toString();
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: buildTextField(
                            'HORAS ESPERADAS', hoursController, true),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: buildDropdownField('ESTADO', statuses, (value) {
                          setState(() {
                            selectedStatus = value ?? 'CREADA';
                          });
                        },
                            initialValue: selectedStatus,
                            allowChange:
                                widget.id == null || widget.status == 'CREADA'
                                    ? false
                                    : true),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: activarEncuesta,
                              onChanged: widget.status == 'CREADA' ||
                                      widget.status == null
                                  ? (bool? value) {
                                      setState(() {
                                        activarEncuesta = value ?? false;
                                      });
                                    }
                                  : null,
                            ),
                            Text('ACTIVAR ENCUESTA'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'NOMBRE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'PROFESIÓN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'CARGO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'SEDE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'ESTADO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(flex: 1, child: SizedBox())
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Visibility(
                      visible: selectedStatus == 'CREADA',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('SELECCIONAR TODOS'),
                          Checkbox(
                              value: selectAll,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectAll = value ?? false;
                                  userSelection = List<bool>.filled(
                                      activeUsers.length, selectAll);
                                  selectedUsers
                                      .clear(); // Clear the selected users list
                                  if (selectAll) {
                                    // If "Select All" is checked, add all user IDs to the list
                                    selectedUsers.addAll(activeUsers
                                        .where((user) =>
                                            user.containsKey('userId') &&
                                            user['userId'] != null)
                                        .map((user) => user['userId']!));
                                    // Also add all emails to the list
                                    print(activeUsers);
                                    print(selectedUsers);
                                  }
                                });
                              }),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: SizedBox(
                      height: 400,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: activeUsers.length,
                        itemBuilder: (context, index) {
                          var user = activeUsers[index];
                          var userId = activeUsersSnapshot.docs[index].id;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      flex: 4, child: Text(user['name'] ?? '')),
                                  Expanded(
                                      flex: 4,
                                      child: Text(user['professionName'])),
                                  Expanded(
                                      flex: 4,
                                      child: Text(user['positionName'])),
                                  Expanded(
                                      flex: 4, child: Text(user['sede'] ?? '')),
                                  Expanded(
                                      flex: 1,
                                      child: Text(
                                          user['status'] ?? 'NO ASIGNADA')),
                                  Expanded(
                                    flex: 1,
                                    child: Checkbox(
                                      value: userSelection[index],
                                      onChanged: selectedStatus == 'CERRADA' ||
                                              (preloadedSelection[index] &&
                                                  selectedStatus != 'CREADA')
                                          ? null // Disable the checkbox if status is 'CERRADA' or if it was preloaded selected
                                          : (bool? selected) {
                                              setState(() {
                                                userSelection[index] =
                                                    selected!;
                                                if (selected) {
                                                  selectedUsers.add(userId);
                                                } else {
                                                  selectedUsers.remove(userId);
                                                }
                                                _updateSelectAll();
                                              });
                                            },
                                    ),
                                  ),
                                ],
                              ),
                              Divider()
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            _saveOrEditSurvey();
                          },
                    child: Text((activarEncuesta && widget.status != 'CREADA')
                        ? (selectedStatus == 'CERRADA'
                            ? (widget.status != selectedStatus
                                ? 'CERRAR ENCUESTA'
                                : 'GUARDAR CAMBIOS ENCUESTA CERRADA')
                            : (widget.status != selectedStatus
                                ? 'ACTIVAR ENCUESTA'
                                : 'GUARDAR CAMBIOS ENCUESTA ACTIVA'))
                        : 'GUARDAR CAMBIOS ENCUESTA'),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(),
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
        SnackBar(content: Text('POR FAVOR, COMPLETE TODOS LOS CAMPOS')),
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
            content: Text('EL NOMBRE DE LA ENCUESTA YA ESTÁ EN USO.'),
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
          SnackBar(content: Text('¡ENCUESTA ACTUALIZADA EXITOSAMENTE!')),
        );
      } else {
        if (selectedUsers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('POR FAVOR, SELECCIONE AL MENOS UN USUARIO')),
          );
          return;
        }

        await _addSurvey();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡ENCUESTA CREADA EXITOSAMENTE!')),
        );
      }

      widget.reloadList();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e')),
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

    for (var userId in selectedUserIds) {
      await newSurveyDoc.collection('Usuarios').doc(userId).set({
        'status': 'ABIERTA',
      });
    }
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

      // Delete users not in selectedUsers and whose status is not 'ENVIADA'
      for (var doc in currentUsers.docs) {
        var docData = doc.data();
        if (!selectedUsers.contains(doc.id) && docData['status'] != 'ENVIADA') {
          await userCollection.doc(doc.id).delete();
        }
      }

      // Add new users from selectedUsers if they are not already present
      for (var userId in selectedUsers) {
        if (!currentUsers.docs.any((doc) => doc.id == userId)) {
          await userCollection.doc(userId).set({'status': 'ABIERTA'});
        }
      }
    } catch (e) {
      print('Failed to update survey: $e');
    }
  }
}
