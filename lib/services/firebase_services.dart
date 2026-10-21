import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

Future<List<Map<String, dynamic>>> getParametro(String param) async {
  List<Map<String, dynamic>> parametroList = [];
  final CollectionReference parametros = db.collection(param);

  // Query all documents
  QuerySnapshot allParam = await parametros.get();
  for (var document in allParam.docs) {
    Map<String, dynamic> parametro = {
      'id': document.id,
      'data': document.data(),
    };
    parametroList.add(parametro);
  }

  // Custom sort function
  parametroList.sort((a, b) {
    String statusA = a['data']['status'];
    String statusB = b['data']['status'];

    // First sort by status
    int statusComparison = compareStatus(statusA, statusB);
    if (statusComparison != 0) {
      return statusComparison;
    }

    // Conditional sorting based on 'param'
    if (param == 'Actividades') {
      String idA = a['id'];
      String idB = b['id'];
      return idA.compareTo(idB);
    } else {
      String nameA = a['data']['name'];
      String nameB = b['data']['name'];
      return nameA.compareTo(nameB);
    }
  });

  return parametroList;
}

int compareStatus(String statusA, String statusB) {
  const statusOrder = ['PENDIENTE', 'ACTIVO', 'INACTIVO'];
  int indexA = statusOrder.indexOf(statusA);
  int indexB = statusOrder.indexOf(statusB);

  // Handle cases where status is not in the predefined list
  if (indexA == -1) indexA = statusOrder.length;
  if (indexB == -1) indexB = statusOrder.length;

  return indexA.compareTo(indexB);
}

Future<String> getFormState(String formId, String userId) async {  
  DocumentSnapshot formDoc = await FirebaseFirestore.instance.collection('Encuestas').doc(formId).collection('Usuarios').doc(userId).get();

  if (formDoc.exists) {
    return formDoc['status'];
  } else {
    return 'NULL';
  }
}

Future<String> getUserRole() async {
  // Obtener el usuario autenticado
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    // Obtener el ID del usuario
    String userId = user.uid;

    // Buscar el documento en la colección "Usuarios"
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Usuarios').doc(userId).get();

    if (userDoc.exists) {
      // Retornar el campo 'rol'
      return userDoc['rol'];
    } else {
      throw Exception('Documento de usuario no encontrado');
    }
  } else {
    throw Exception('No hay un usuario autenticado');
  }
}

Future<List<Map<String, dynamic>>> getUsuarios() async {
  final List<Map<String, dynamic>> usersList = [];
  final CollectionReference usuarios = db.collection('Usuarios');
  final CollectionReference positions = db.collection('Cargos');
  final CollectionReference professions = db.collection('Profesiones');

  // Lanzamos las 3 consultas en paralelo
  final futures = await Future.wait([
    positions.get(),
    professions.get(),
    usuarios.get(),
  ]);

  // ignore: unnecessary_cast
  final QuerySnapshot positionDocs = futures[0] as QuerySnapshot;
  // ignore: unnecessary_cast
  final QuerySnapshot professionDocs = futures[1] as QuerySnapshot;
  // ignore: unnecessary_cast
  final QuerySnapshot users = futures[2] as QuerySnapshot;

  // Mapear id -> nombre de cargos
  final Map<String, String> positionNames = {};
  for (var document in positionDocs.docs) {
    final data = document.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey('name')) {
      positionNames[document.id] = data['name'] as String;
    }
  }

  // Mapear id -> nombre de profesiones
  final Map<String, String> professionNames = {};
  for (var document in professionDocs.docs) {
    final data = document.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey('name')) {
      professionNames[document.id] = data['name'] as String;
    }
  }

  // Usuarios
  for (var document in users.docs) {
    final data = document.data() as Map<String, dynamic>?;
    if (data != null) {
      final String positionName =
          positionNames[data['position']] ?? 'Unknown Position';
      final String professionName =
          professionNames[data['profession']] ?? 'Unknown Profession';

      final Map<String, dynamic> usuario = {
        'id': document.id,
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'role': data['role'] ?? '',
        'status': data['status'] ?? '',
        'gender': data['gender'] ?? '',
        'idType': data['idType'] ?? '',
        'sede': data['sede'] ?? '',
        'positionId': data['position'] ?? '',
        'position': positionName,
        'professionId': data['profession'] ?? '',
        'profession': professionName,
      };
      usersList.add(usuario);
    }
  }

  // Ordenar igual que antes: primero ACTIVO, luego por nombre
  usersList.sort((a, b) {
    final int statusComparison =
        a['status'] == 'ACTIVO' && b['status'] != 'ACTIVO'
            ? -1
            : (a['status'] != 'ACTIVO' && b['status'] == 'ACTIVO' ? 1 : 0);

    if (statusComparison != 0) {
      return statusComparison;
    } else {
      return a['name'].compareTo(b['name']);
    }
  });

  return usersList;
}


Future<List<Map<String, dynamic>>> getEncuestas() async {
  final List<Map<String, dynamic>> formsList = [];
  final CollectionReference forms = db.collection('Encuestas');

  // Traemos solo encuestas cuyo status != "ELIMINADA"
  final formSnap =
      await forms.where('status', isNotEqualTo: 'ELIMINADA').get();

  // Procesamos cada encuesta en paralelo
  final futures = formSnap.docs.map((document) async {
    // Subcolección Usuarios de esta encuesta
    final usuariosSubcollection =
        forms.doc(document.id).collection('Usuarios');
    final usuariosSnapshot = await usuariosSubcollection.get();

    final int totalUsuarios = usuariosSnapshot.size;
    final int nonEnviadaCount = usuariosSnapshot.docs
        .where((doc) => doc['status'] != 'ENVIADA')
        .length;

    return {
      'id': document.id,
      'data': document.data(),
      'usuariosTotal': totalUsuarios,
      'usuariosNonEnviada': nonEnviadaCount,
    };
  }).toList();

  final results = await Future.wait(futures);

  formsList.addAll(results);
  formsList.sort((a, b) => b['id'].compareTo(a['id']));
  return formsList;
}


Future<Map<String, dynamic>?> getEncuestaWithUsers(String encuestaId) async {
  // Reference to the specific "Encuesta" document
  final DocumentReference encuestaDocRef = db.collection('Encuestas').doc(encuestaId);

  // Get the "Encuesta" document
  DocumentSnapshot encuestaDoc = await encuestaDocRef.get();

  // Check if the "Encuesta" document exists and its status is not 'ELIMINADA' or 'CREADA'
  if (encuestaDoc.exists) {
    var encuestaData = encuestaDoc.data() as Map<String, dynamic>?;
    if (encuestaData != null && encuestaData['status'] != 'ELIMINADA' && encuestaData['status'] != 'CREADA') {
      // Reference to the "Usuarios" subcollection within the current "Encuesta" document
      final CollectionReference usuariosCollection = encuestaDocRef.collection('Usuarios');

      // Query the "Usuarios" subcollection
      QuerySnapshot usuariosSnapshot = await usuariosCollection.get();

      // Convert the documents to a list of maps
      List<Map<String, dynamic>> usuariosList = usuariosSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Sort the list of users alphabetically by the 'name' field
      usuariosList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Create a map for the "Encuesta" document with the sorted users list
      Map<String, dynamic> encuesta = {
        'id': encuestaDoc.id,
        'data': encuestaData,
        'users': usuariosList,
      };

      return encuesta;
    }
  }

  // Return null if no matching document is found or the conditions are not met
  return null;
}

Future<List<Map<String, dynamic>>> getEncuestasUser(String uid) async {
  final firestore = FirebaseFirestore.instance;

  // Filter in Firestore to avoid downloading ELIMINADA/CREADA surveys
  final encuestasSnap = await firestore
      .collection('Encuestas')
      .where('status', whereNotIn: ['ELIMINADA', 'CREADA'])
      .get();

  // Process each survey in parallel
  final futures = encuestasSnap.docs.map((encuestaDoc) async {
    final encuestaData = encuestaDoc.data() as Map<String, dynamic>?;

    if (encuestaData == null) return null;

    // Look up the user's document within this survey
    final userSnap = await encuestaDoc.reference
        .collection('Usuarios')
        .doc(uid)
        .get();

    if (!userSnap.exists) return null;

    return {
      'id': encuestaDoc.id,
      'data': encuestaData,
      // ignore: unnecessary_cast
      'user': userSnap.data() as Map<String, dynamic>?,
    };
  }).toList();

  // 4) Esperar TODOS los futuros de una sola vez (paralelo)
  final results = await Future.wait(futures);

  // 5) Limpiar los null y ordenar
  final filtered = results.where((e) => e != null).cast<Map<String, dynamic>>().toList();
  filtered.sort((a, b) => b['id'].compareTo(a['id']));

  return filtered;
}


Future<String> saveParameter(String param, String nombre, String estado) async {
  // Get a reference to the collection
  CollectionReference collectionReference = FirebaseFirestore.instance.collection(param);

  // Generate a unique ID
  String docId = await idGenerator(collectionReference, param);

  // Add the document with the generated ID
  await collectionReference.doc(docId).set({
    'name': nombre.toUpperCase(),
    'status': estado.toUpperCase(),
  });

  print('Parameter saved successfully');
  return docId; // Return the new document ID
}

void saveUser(String id, String idType, String name, String phone, String email, String position, String profession, String role, String status) async {
  // Get a reference to the collection
  CollectionReference collectionReference =
      FirebaseFirestore.instance.collection('Usuarios');
      
  collectionReference.doc(id).set({
    'idType': idType,
    'name': name,
    'phone': phone,
    'email': email.toLowerCase(),
    'position': position,
    'profession': profession,
    'role': role,
    'status': status,
  }).then((_) {
    print('Parameter saved successfully');
  }).catchError((error) {
    print('Failed to save parameter: $error');
  });
}

Future<String> idGenerator(CollectionReference ref, String collection) async {

  int counter = 0;
  String inicio = '';
  QuerySnapshot snapshot = await ref.get();
  counter = snapshot.size + 1;
  if(collection == 'Proyectos'){
    inicio = 'PR';
  } else if (collection == 'Profesiones'){
    inicio = 'PF';
  } else if (collection == 'Cargos'){
    inicio = 'CG';
  } else if (collection == 'Actividades'){
    inicio = 'AC';
  } else {
    inicio = collection[0];
  }
  String idGenerated = inicio + counter.toString().padLeft(4, '0');
  return idGenerated;
}

void updateParameter(String id, String param, String nombre, String estado) {
  FirebaseFirestore.instance.collection(param).doc(id).update({
    'name': nombre.toUpperCase(),
    'status': estado.toUpperCase(),
  }).then((value) {
    print('Parameter saved successfully');
  }).catchError((error) {
    print('Failed to save parameter: $error');
  });
}

Future<List<String>> getParamAuto(String param) async {
  List<String> parametros = [];
  QuerySnapshot? queryParametros = await db.collection(param).where('status', isEqualTo: 'ACTIVO').get();
  for (var doc in queryParametros.docs) {
    parametros.add(doc['name']);
  }
  return parametros;
}

Future<String?> fetchParameter(String param, String id) async {
  try {
    final docSnapshot = await FirebaseFirestore.instance.collection(param).doc(id).get();
    if (docSnapshot.exists) {
      return docSnapshot['name'];
    } else {
      print('$param document does not exist');
      return null;
    }
  } catch (e) {
    print('Error fetching $param document: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> fetchUserData(String userId) async {
  try {
    final docSnapshot = await FirebaseFirestore.instance.collection('Usuarios').doc(userId).get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    } else {
      print('User document does not exist');
      return null;
    }
  } catch (e) {
    print('Error fetching user document: $e');
    return null;
  }
}





