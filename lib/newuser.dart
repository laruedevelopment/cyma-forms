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

  AddEditUser({this.id, this.typeId, this.gender, this.role, this.status, this.sede, required this.reloadList, required this.admin});

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

  final List<dynamic> idTypes = ['CÉDULA DE CIUDADANÍA', 'CÉDULA DE EXTRANJERÍA', 'PASAPORTE', 'NIT', 'OTRO'];
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

  Future<List<Parametro>> getSugPositions(String query) async {
    List<Parametro> savedCargos = await getParamwithId('Cargos');
    List<Parametro> filteredCargos = savedCargos
        .where((cargo) => cargo.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    filteredCargos.sort((a, b) => a.name.trim().compareTo(b.name.trim()));
    return filteredCargos;
  }

  Future<List<Parametro>> getSugProfessions(String query) async {
    List<Parametro> savedProfesiones = await getParamwithId('Profesiones');
    List<Parametro> filteredProfesiones = savedProfesiones
        .where((profesion) => profesion.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    filteredProfesiones.sort((a, b) => a.name.trim().compareTo(b.name.trim()));
    return filteredProfesiones;
  }

  Future<List<Parametro>> getParamwithId(String param) async {
    List<Parametro> parametros = [];
    QuerySnapshot queryParametros = await FirebaseFirestore.instance.collection(param).where('status', isEqualTo: 'ACTIVO').get();
    for (var doc in queryParametros.docs) {
      parametros.add(Parametro(id: doc.id, name: doc['name']));
    }
    return parametros;
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
    
    // Initialize professional and positional data
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
        final profession = await fetchParameter('Profesiones', userData['profession']);
        final position = await fetchParameter('Cargos', userData['position']);

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


   @override
  Widget build(BuildContext context) {
    professionController.addListener(() {
      final text = professionController.text.toUpperCase();
      if (professionController.text != text) {
        professionController.value = professionController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    positionController.addListener(() {
      final text = positionController.text.toUpperCase();
      if (positionController.text != text) {
        positionController.value = positionController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    initPos();
    initProf();
    print(professionsList);
    print(positionsList);
    return AlertDialog(
      title: Center(child: Text(widget.id != null ? 'EDITAR USUARIO' : 'CREAR USUARIO')),
      content: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: buildDropdownField('TIPO DE DOCUMENTO', idTypes, (value) {
                        setState(() {
                          selectedIdType = value ?? 'TIPO DE DOCUMENTO'; // Ensure a default value if null
                        });
                      }, initialValue: selectedIdType, allowChange: true),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: buildTextField('NÚMERO DE IDENTIFICACIÓN', idController, false)),
                    SizedBox(width: 10),
                    Expanded(
                      child: buildDropdownField('SEDE', sedes, (value) {
                        setState(() {
                          selectedSede = value ?? 'SEDE'; // Ensure a default value if null
                        });
                      }, initialValue: selectedSede, allowChange: true),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                buildTextField('NOMBRE', nameController, false),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: buildDateField('FECHA DE NACIMIENTO', bdayController, context)),
                    SizedBox(width: 10),
                    Expanded(
                      child: buildDropdownField(
                        'GÉNERO', genders, (value) {
                          setState(() {
                            selectedGender = value ?? 'GÉNERO';
                          });
                        }, initialValue: selectedGender, allowChange: true
                      ),
                    ),
                    Visibility(
                      visible: !admin,
                      child: SizedBox(width: 10),
                    ),
                    Visibility(
                      visible: !admin,
                      child: Expanded(child: PasswordField(
                        label: 'CONTRASEÑA',
                        controller: passwordController,
                      ),)
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: buildNumberField('CELULAR', phoneController, false)),
                    SizedBox(width: 10),
                    Expanded(child: buildEmailField('EMAIL (TEN PRESENTE QUE SERÁ USADO PARA EL INICIO DE SESIÓN)', emailController, widget.id != null ? true : false)),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(maxWidth: 800),                    
                  child: Row(
                    children: [
                      Expanded(
                        child: TypeAheadFormField<Parametro>(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: positionController,
                            decoration: InputDecoration(
                              labelText: 'CARGO',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                          ),
                          suggestionsCallback: getSugPositions,
                          itemBuilder: (context, cargo) {
                            return ListTile(
                              title: Text(cargo.name),
                            );
                          },
                          onSuggestionSelected: (cargo) {
                            setState(() {
                              positionController.text = cargo.name;
                              selectedPositionId = cargo.id;
                              print(selectedPositionId);
                            });
                          },
                          autovalidateMode: AutovalidateMode.always,
                          validator: (position) {
                            if (position!.isEmpty || !positionsList.any((cargo) => cargo.name == position)) {
                              return 'SELECCIONE UN CARGO DE LA LISTA';
                            } else {
                              return null;
                            }
                          },
                          onSaved: (position) {
                            setState(() {
                              // Handle saving the selected cargo id if needed
                            });
                          },
                        ),
                      ),                  
                      SizedBox(width: 10),                  
                      Expanded(
                        child: TypeAheadFormField<Parametro>(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: professionController,
                            decoration: InputDecoration(                          
                              labelText: 'PROFESIÓN',                          
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),                        
                            ),
                          ),
                          suggestionsCallback: getSugProfessions,
                          itemBuilder: (context, profesion) {
                            return ListTile(
                              title: Text(profesion.name),
                            );
                          },
                          onSuggestionSelected: (profesion) {
                            setState(() {
                              professionController.text = profesion.name;
                              selectedProfessionId = profesion.id;
                            });
                          },                   
                          autovalidateMode: AutovalidateMode.always,
                          validator: (profession) {
                            if (profession!.isEmpty || !professionsList.any((profesion) => profesion.name == profession)) {
                              return 'SELECCIONE UNA PROFESIÓN DE LA LISTA';
                            } else {
                              return null;
                            }
                          },
                          onSaved: (profession) {
                            // Save the ocupacion to Firebase if it's a new value
                            setState(() {
                              
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Visibility(
                  visible: admin,
                  child: Row(
                    children: [
                      Expanded(
                        child: buildDropdownField(
                          'ROL', roles, (value) {
                            setState(() {
                              selectedRole = value ?? 'ROL';
                            });
                          }, initialValue: selectedRole, allowChange: true
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: buildDropdownField(
                          'ESTADO', statuses, (value) {
                            setState(() {
                              selectedStatus = value!;
                            });
                          }, initialValue: selectedStatus, allowChange: true
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildButton('GUARDAR', Colors.green, () {
                      if (widget.id != null) {
                        _updateUser(userId);
                      } else {
                        _saveUser();
                      }
                    }, _isLoading),
                    buildButton('CANCELAR', Colors.red, () => Navigator.pop(context), _isLoading),
                  ],
                ),
              ],
            ),
          ),
          // Show loading indicator when _isLoading is true
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
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
        if (widget.admin == true) {
          final secondaryApp = await Firebase.initializeApp(
            name: 'userCreation',
            options: Firebase.app().options,
          );
          try {
            final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
            final credential = await secondaryAuth.createUserWithEmailAndPassword(
              email: emailController.text,
              password: randomAlphaNumeric(10),
            );
            newUid = credential.user!.uid;
            await secondaryAuth.signOut();
          } finally {
            await secondaryApp.delete();
          }
        } else {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          newUid = credential.user!.uid;
        }

        // Step 3: Save user data to Firestore
        await FirebaseFirestore.instance.collection('Usuarios').doc(newUid).set({
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

        if(selectedRole == 'USUARIO'){
          if(selectedPositionId == 'CG0007'){
            encuestasSnapshot = await FirebaseFirestore.instance
              .collection('Encuestas')
              .where('status', isEqualTo: 'ACTIVA')
              .where('tipo', whereIn: ['G', 'T'])
              .get();
          } else {
            encuestasSnapshot = await FirebaseFirestore.instance
              .collection('Encuestas')
              .where('status', isEqualTo: 'ACTIVA')
              .where('tipo', whereIn: ['U', 'T'])
              .get();
          }
          // Step 5: Add user to "Usuarios" subcollection in "Encuestas" with "ACTIVA" status      

          for (var encuestaDoc in encuestasSnapshot.docs) {
            await FirebaseFirestore.instance
                .collection('Encuestas')
                .doc(encuestaDoc.id)
                .collection('Usuarios')
                .doc(newUid)
                .set({
              'status': 'ABIERTA',
            });
          }
        }        
        widget.reloadList();
        // User saved successfully, set loading to false
        setState(() {
          _isLoading = false;
        });

        Navigator.pop(context, 'save');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El usuario ha sido creado con éxito.'),
            duration: Duration(seconds: 4),
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

        await FirebaseFirestore.instance.collection('Usuarios').doc(widget.id).update({
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

  Widget buildButton(String text, Color color, VoidCallback onPressed, bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: color,
      ),
      child: Text(text),
    );
  }

  bool _validateFields() {

    bool isPositionValid = positionsList.any((position) => position.id == selectedPositionId);
    bool isProfessionValid = professionsList.any((profession) => profession.id == selectedProfessionId);

    // Perform other validations
    if (idController.text.isEmpty ||
        nameController.text.isEmpty ||
        bdayController.text.isEmpty ||
        phoneController.text.isEmpty ||
        emailController.text.isEmpty ||
        !genders.contains(selectedGender) ||
        !idTypes.contains(selectedIdType) ||
        !statuses.contains(selectedStatus) ||
        !roles.contains(selectedRole) ||
        !sedes.contains(selectedSede) ||
        !isPositionValid ||
        !isProfessionValid) {
      return false;
    }

    // Validate password only when admin is false
    if (widget.admin != true) {
      if (passwordController.text.isEmpty || passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, ingrese una contraseña con al menos 6 caracteres.'),
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