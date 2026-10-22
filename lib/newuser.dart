// ignore: must_be_immutable
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:random_string/random_string.dart';
import 'dart:async';

class AddEditUser extends StatefulWidget {
  final String? id; // Nullable to differentiate between adding and editing
  final String? role;
  final String? status;
  final String? typeId;
  final String? gender;
  final String? sede;
  final bool? admin;

  final VoidCallback reloadList;

  const AddEditUser(
      {super.key,
      this.id,
      this.typeId,
      this.gender,
      this.role,
      this.status,
      this.sede,
      required this.reloadList,
      required this.admin});

  @override
  // ignore: library_private_types_in_public_api
  _AddEditUserState createState() => _AddEditUserState();
}

class _AddEditUserState extends State<AddEditUser> {
  bool _isLoading = false;
  late TextEditingController idController;
  late TextEditingController nameController;
  late TextEditingController bdayController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController professionController;
  late TextEditingController positionController;
  TextEditingController passwordController = TextEditingController();

  late String selectedIdType;
  late String selectedGender;
  late String selectedRole;
  late String selectedStatus;
  late String selectedSede;
  late String userId;
  late bool admin;

  final List<dynamic> idTypes = [
    'CÉDULA DE CIUDADANÍA',
    'CÉDULA DE EXTRANJERÍA',
    'PASAPORTE',
    'NIT',
    'OTRO'
  ];
  final List<dynamic> genders = ['MASCULINO', 'FEMENINO', 'OTRO'];
  final List<dynamic> roles = ['USUARIO', 'CONSULTOR', 'ADMINISTRADOR'];
  final List<dynamic> sedes = ['BUCARAMANGA', 'BOGOTÁ'];
  List<dynamic> positionsList = [];
  List<dynamic> professionsList = [];
  String? selectedPositionId;
  String? selectedProfessionId;
  final List<dynamic> statuses = ['ACTIVO', 'INACTIVO'];

  Future<void> initPos() async {
    positionsList = await getParamwithId('Cargos');
    positionsList.sort((a, b) => a.name.trim().compareTo(b.name.trim()));
  }

  Future<void> initProf() async {
    professionsList = await getParamwithId('Profesiones');
    professionsList.sort((a, b) => a.name.trim().compareTo(b.name.trim()));
  }

  // Los catálogos ya están en memoria (se leen una vez al abrir el diálogo).
  List<Parametro> _sugerencias(List<dynamic> lista, String query) {
    final q = query.toLowerCase();
    return lista
        .where((e) => e.name.toLowerCase().contains(q))
        .cast<Parametro>()
        .toList();
  }

  Future<List<Parametro>> getSugPositions(String query) async =>
      _sugerencias(positionsList, query);

  Future<List<Parametro>> getSugProfessions(String query) async =>
      _sugerencias(professionsList, query);

  Future<List<Parametro>> getParamwithId(String param) async {
    final docs = await catalogo(param, forzar: true);
    return [
      for (final d in docs)
        if (d['data']['status'] == 'ACTIVO')
          Parametro(id: d['id'], name: d['data']['name'] ?? '')
    ];
  }

  void _mayusculas(TextEditingController c) {
    c.addListener(() {
      final text = c.text.toUpperCase();
      if (c.text != text) {
        c.value = c.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize state variables with defaults or widget parameters
    userId = widget.id ?? '';
    selectedIdType = widget.typeId ?? 'CÉDULA DE CIUDADANÍA';
    selectedGender = widget.gender ?? 'MASCULINO';
    selectedStatus = widget.status ?? 'ACTIVO';
    selectedRole = widget.role ?? 'USUARIO';
    selectedSede = widget.sede ?? 'BUCARAMANGA';
    admin = widget.admin ?? false;

    // Initialize controllers
    idController = TextEditingController();
    nameController = TextEditingController();
    bdayController = TextEditingController();
    phoneController = TextEditingController();
    emailController = TextEditingController();
    professionController = TextEditingController();
    positionController = TextEditingController();

    _mayusculas(professionController);
    _mayusculas(positionController);

    // Catálogos: se leen una sola vez, en paralelo.
    initProf();
    initPos();

    // Fetch user data if widget.id is not null
    if (widget.id != null) {
      fetchAndPopulateUserData(widget.id!);
    }
  }

  // Method to fetch user data and populate controllers
  void fetchAndPopulateUserData(String userId) async {
    try {
      final userData = await fetchUserData(userId);
      if (userData != null) {
        // Fetch additional parameters asynchronously
        final nombres = await Future.wait([
          fetchParameter('Profesiones', userData['profession']),
          fetchParameter('Cargos', userData['position']),
        ]);
        final profession = nombres[0];
        final position = nombres[1];

        // Update state with fetched data
        setState(() {
          idController.text = userData['id'] ?? '';
          nameController.text = userData['name'] ?? '';
          bdayController.text = userData['bday'] ?? '';
          phoneController.text = userData['phone'] ?? '';
          emailController.text = userData['email'].toLowerCase() ?? '';
          professionController.text = profession ?? '';
          positionController.text = position ?? '';
          selectedProfessionId = userData['profession'];
          selectedPositionId = userData['position'];
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Widget _typeAhead({
    required String label,
    required TextEditingController controller,
    required Future<List<Parametro>> Function(String) sugerencias,
    required void Function(Parametro) alElegir,
    required bool Function(String) esValido,
    required String mensajeError,
  }) {
    return TypeAheadFormField<Parametro>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
      suggestionsCallback: sugerencias,
      itemBuilder: (context, e) => ListTile(title: Text(e.name)),
      noItemsFoundBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Sin coincidencias en la lista'),
      ),
      onSuggestionSelected: (e) => setState(() => alElegir(e)),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => (v == null || v.isEmpty || !esValido(v))
          ? mensajeError
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final angosto = ancho < 700;

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

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.id != null ? 'Editar usuario' : 'Crear usuario'),
      content: SizedBox(
        width: 760,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fila([
                      buildDropdownField('TIPO DE DOCUMENTO', idTypes, (value) {
                        setState(() {
                          selectedIdType = value ?? 'CÉDULA DE CIUDADANÍA';
                        });
                      }, initialValue: selectedIdType, allowChange: true),
                      buildTextField(
                          'NÚMERO DE IDENTIFICACIÓN', idController, false),
                    ]),
                    buildTextField('NOMBRE COMPLETO', nameController, false),
                    const SizedBox(height: 14),
                    fila([
                      buildDateField(
                          'FECHA DE NACIMIENTO', bdayController, context),
                      buildDropdownField('GÉNERO', genders, (value) {
                        setState(() {
                          selectedGender = value ?? 'MASCULINO';
                        });
                      }, initialValue: selectedGender, allowChange: true),
                    ]),
                    fila([
                      buildNumberField('CELULAR', phoneController, false),
                      buildDropdownField('SEDE', sedes, (value) {
                        setState(() {
                          selectedSede = value ?? 'BUCARAMANGA';
                        });
                      }, initialValue: selectedSede, allowChange: true),
                    ]),
                    buildEmailField('CORREO (con él inicia sesión)',
                        emailController, widget.id != null),
                    const SizedBox(height: 14),
                    if (!admin) ...[
                      PasswordField(
                        label: 'CONTRASEÑA (mínimo 6 caracteres)',
                        controller: passwordController,
                      ),
                      const SizedBox(height: 14),
                    ],
                    fila([
                      _typeAhead(
                        label: 'CARGO',
                        controller: positionController,
                        sugerencias: getSugPositions,
                        alElegir: (c) {
                          positionController.text = c.name;
                          selectedPositionId = c.id;
                        },
                        esValido: (v) =>
                            positionsList.any((c) => c.name == v),
                        mensajeError: 'Elige un cargo de la lista',
                      ),
                      _typeAhead(
                        label: 'PROFESIÓN',
                        controller: professionController,
                        sugerencias: getSugProfessions,
                        alElegir: (p) {
                          professionController.text = p.name;
                          selectedProfessionId = p.id;
                        },
                        esValido: (v) =>
                            professionsList.any((p) => p.name == v),
                        mensajeError: 'Elige una profesión de la lista',
                      ),
                    ]),
                    if (admin)
                      fila([
                        buildDropdownField('ROL', roles, (value) {
                          setState(() {
                            selectedRole = value ?? 'USUARIO';
                          });
                        }, initialValue: selectedRole, allowChange: true),
                        buildDropdownField('ESTADO', statuses, (value) {
                          setState(() {
                            selectedStatus = value ?? 'ACTIVO';
                          });
                        }, initialValue: selectedStatus, allowChange: true),
                      ]),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (widget.id != null) {
                    _updateUser(userId);
                  } else {
                    _saveUser();
                  }
                },
          child: Text(widget.id != null ? 'Guardar' : 'Crear usuario'),
        ),
      ],
    );
  }

  void _saveUser() async {
    // Validate fields
    if (_validateFields()) {
      try {
        // Set loading to true
        setState(() {
          _isLoading = true;
        });

        // Step 1: Check if email is already in use (only admins can query Usuarios;
        // for public sign-ups Firebase Auth reports email-already-in-use)
        if (widget.admin == true) {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('Usuarios')
              .where('email', isEqualTo: emailController.text.toLowerCase())
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // Email already in use
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('El correo electrónico ya está en uso.'),
                duration: Duration(seconds: 4),
              ),
            );
            return; // Exit the function if email is in use
          }
        }

        // Step 2: Create user in Firebase Authentication.
        // When an admin creates the account, a secondary Firebase app is used so
        // the admin's own session is kept and the Firestore writes below are
        // made as the admin.
        final String newUid;
        bool passwordEmailSent = false;
        if (widget.admin == true) {
          final secondaryApp = await Firebase.initializeApp(
            name: 'userCreation',
            options: Firebase.app().options,
          );
          try {
            final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
            final credential =
                await secondaryAuth.createUserWithEmailAndPassword(
              email: emailController.text,
              password: randomAlphaNumeric(10),
            );
            newUid = credential.user!.uid;
            // La contraseña inicial es aleatoria: la persona define la suya
            // desde el enlace que recibe por correo.
            try {
              await secondaryAuth.sendPasswordResetEmail(
                  email: emailController.text);
              passwordEmailSent = true;
            } catch (_) {}
            await secondaryAuth.signOut();
          } finally {
            await secondaryApp.delete();
          }
        } else {
          final credential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          newUid = credential.user!.uid;
        }

        // Step 3: Save user data to Firestore
        await FirebaseFirestore.instance
            .collection('Usuarios')
            .doc(newUid)
            .set({
          'idType': selectedIdType.toUpperCase(),
          'id': idController.text.toUpperCase(),
          'name': nameController.text.toUpperCase(),
          'bday': bdayController.text.toUpperCase(),
          'gender': selectedGender.toUpperCase(),
          'phone': phoneController.text.toUpperCase(),
          'email': emailController.text.toLowerCase(),
          'position': selectedPositionId?.toUpperCase(),
          'profession': selectedProfessionId?.toUpperCase(),
          'role': selectedRole.toUpperCase(),
          'status': selectedStatus.toUpperCase(),
          'sede': selectedSede.toUpperCase(),
        });
        late QuerySnapshot encuestasSnapshot;

        if (selectedRole == 'USUARIO') {
          if (selectedPositionId == 'CG0007') {
            encuestasSnapshot = await FirebaseFirestore.instance
                .collection('Encuestas')
                .where('status', isEqualTo: 'ACTIVA')
                .where('tipo', whereIn: ['G', 'T']).get();
          } else {
            encuestasSnapshot = await FirebaseFirestore.instance
                .collection('Encuestas')
                .where('status', isEqualTo: 'ACTIVA')
                .where('tipo', whereIn: ['U', 'T']).get();
          }
          // Step 5: Add user to "Usuarios" subcollection in "Encuestas" with "ACTIVA" status

          final batch = FirebaseFirestore.instance.batch();
          for (var encuestaDoc in encuestasSnapshot.docs) {
            batch.set(
                FirebaseFirestore.instance
                    .collection('Encuestas')
                    .doc(encuestaDoc.id)
                    .collection('Usuarios')
                    .doc(newUid),
                {'status': 'ABIERTA'});
          }
          await batch.commit();
        }
        widget.reloadList();
        // User saved successfully, set loading to false
        setState(() {
          _isLoading = false;
        });

        Navigator.pop(context, 'save');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.admin == true
                ? (passwordEmailSent
                    ? 'El usuario ha sido creado. Le enviamos un correo para que defina su contraseña.'
                    : 'El usuario ha sido creado, pero no se pudo enviar el correo de contraseña. Debe usar "Recuperar contraseña" en el inicio de sesión.')
                : 'El usuario ha sido creado con éxito.'),
            duration: Duration(seconds: 6),
          ),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code == 'email-already-in-use'
                ? 'El correo electrónico ya está en uso.'
                : 'Error al crear el usuario: ${e.message}'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _updateUser(String userId) async {
    // Validate fields
    if (_validateFields()) {
      try {
        // Set loading to true
        setState(() {
          _isLoading = true;
        });

        await FirebaseFirestore.instance
            .collection('Usuarios')
            .doc(widget.id)
            .update({
          'idType': selectedIdType.toUpperCase(),
          'id': idController.text.toUpperCase(),
          'name': nameController.text.toUpperCase(),
          'bday': bdayController.text.toUpperCase(),
          'gender': selectedGender.toUpperCase(),
          'phone': phoneController.text.toUpperCase(),
          'email': emailController.text.toLowerCase(),
          'position': selectedPositionId?.toUpperCase(),
          'profession': selectedProfessionId?.toUpperCase(),
          'role': selectedRole.toUpperCase(),
          'status': selectedStatus.toUpperCase(),
          'sede': selectedSede.toUpperCase()
        });

        // User updated successfully, set loading to false
        setState(() {
          _isLoading = false;
        });

        widget.reloadList();

        Navigator.pop(context, 'save');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El usuario ha sido actualizado con éxito.'),
            duration: Duration(seconds: 4),
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el usuario: $e'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  bool _validateFields() {
    bool isPositionValid =
        positionsList.any((position) => position.id == selectedPositionId);
    bool isProfessionValid = professionsList
        .any((profession) => profession.id == selectedProfessionId);

    // Perform other validations
    final missing = <String>[
      if (idController.text.isEmpty) 'número de identificación',
      if (nameController.text.isEmpty) 'nombre',
      if (bdayController.text.isEmpty) 'fecha de nacimiento',
      if (phoneController.text.isEmpty) 'celular',
      if (emailController.text.isEmpty) 'email',
      if (!genders.contains(selectedGender)) 'género',
      if (!idTypes.contains(selectedIdType)) 'tipo de documento',
      if (!statuses.contains(selectedStatus)) 'estado',
      if (!roles.contains(selectedRole)) 'rol',
      if (!sedes.contains(selectedSede)) 'sede',
      if (!isPositionValid) 'cargo (elige uno de la lista)',
      if (!isProfessionValid) 'profesión (elige una de la lista)',
    ];
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falta completar: ${missing.join(', ')}.'),
          duration: Duration(seconds: 5),
        ),
      );
      return false;
    }

    // Validate password only when admin is false
    if (widget.admin != true) {
      if (passwordController.text.isEmpty ||
          passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Por favor, ingrese una contraseña con al menos 6 caracteres.'),
            duration: Duration(seconds: 4),
          ),
        );
        return false;
      }
    }

    // All validations passed
    return true;
  }
}

class Parametro {
  final String id;
  final String name;

  Parametro({required this.id, required this.name});
}
