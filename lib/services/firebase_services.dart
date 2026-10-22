import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

class _CatalogoEnCache {
  final DateTime leidoEn;
  final List<Map<String, dynamic>> docs;
  _CatalogoEnCache(this.leidoEn, this.docs);
}

const Duration _vigenciaCatalogo = Duration(minutes: 5);
final Map<String, _CatalogoEnCache> _catalogos = {};

/// Lee un catálogo (Cargos, Profesiones, Proyectos, Actividades) una sola vez
/// y lo reutiliza unos minutos. Cambian poco y se pedían completos en cada
/// pantalla. Cada elemento es {'id': ..., 'data': {...}}.
Future<List<Map<String, dynamic>>> catalogo(String param,
    {bool forzar = false}) async {
  final guardado = _catalogos[param];
  if (!forzar &&
      guardado != null &&
      DateTime.now().difference(guardado.leidoEn) < _vigenciaCatalogo) {
    return guardado.docs;
  }
  final snap = await db.collection(param).get();
  final docs = [
    for (final d in snap.docs) {'id': d.id, 'data': d.data()}
  ];
  _catalogos[param] = _CatalogoEnCache(DateTime.now(), docs);
  return docs;
}

void invalidarCatalogo(String param) => _catalogos.remove(param);

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
    String statusA = a['data']['status'] ?? '';
    String statusB = b['data']['status'] ?? '';

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

Future<List<Map<String, dynamic>>> getUsuarios() async {
  final List<Map<String, dynamic>> usersList = [];
  final CollectionReference usuarios = db.collection('Usuarios');

  // Usuarios en vivo; Cargos y Profesiones salen de la caché (se leen en paralelo)
  final resultados = await Future.wait([
    catalogo('Cargos'),
    catalogo('Profesiones'),
    usuarios.get(),
  ]);
  final cargos = resultados[0] as List<Map<String, dynamic>>;
  final profesiones = resultados[1] as List<Map<String, dynamic>>;
  final QuerySnapshot users = resultados[2] as QuerySnapshot;

  final Map<String, String> positionNames = {
    for (final c in cargos)
      if (c['data']['name'] != null) c['id']: c['data']['name'] as String
  };
  final Map<String, String> professionNames = {
    for (final p in profesiones)
      if (p['data']['name'] != null) p['id']: p['data']['name'] as String
  };

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

  // Solo se necesitan dos números por encuesta: se piden como agregados
  // (count) en vez de descargar todas las respuestas de cada persona.
  final futures = formSnap.docs.map((document) async {
    final usuariosSubcollection =
        forms.doc(document.id).collection('Usuarios');
    final conteos = await Future.wait([
      usuariosSubcollection.count().get(),
      usuariosSubcollection
          .where('status', isNotEqualTo: 'ENVIADA')
          .count()
          .get(),
    ]);

    return {
      'id': document.id,
      'data': document.data(),
      'usuariosTotal': conteos[0].count ?? 0,
      'usuariosNonEnviada': conteos[1].count ?? 0,
    };
  }).toList();

  final results = await Future.wait(futures);

  formsList.addAll(results);
  formsList.sort((a, b) => b['id'].compareTo(a['id']));
  return formsList;
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

  invalidarCatalogo(param);
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
  // Basta con contar; antes se descargaba toda la colección solo para eso.
  counter = ((await ref.count().get()).count ?? 0) + 1;
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

Future<void> updateParameter(
    String id, String param, String nombre, String estado) async {
  await FirebaseFirestore.instance.collection(param).doc(id).update({
    'name': nombre.toUpperCase(),
    'status': estado.toUpperCase(),
  });
  invalidarCatalogo(param);
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





