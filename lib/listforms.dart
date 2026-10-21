// ignore_for_file: use_build_context_synchronously

import 'package:forms_app/form.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/addeditforms.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/hours_utils.dart';
import 'package:forms_app/widgets/forms_widgets.dart';

class ListFormsScreen extends StatefulWidget {
  ListFormsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListFormsScreenState createState() => _ListFormsScreenState();
}

class _ListFormsScreenState extends State<ListFormsScreen> {
  void _reloadList() {
    setState(() {}); // Empty setState just to trigger rebuild
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('ADMINISTRACIÓN DE ENCUESTAS')),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(350, 50, 350, 50),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ENCUESTAS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ESTADO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ), // Add spacing between header and FutureBuilder
            ),
            SizedBox(height: 10),
            Expanded(
              child: FutureBuilder(
                future: getEncuestas(),
                builder: ((context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemCount: snapshot.data?.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data?[index];
                        return SizedBox(
                            height: 100, // Adjust height as necessary
                            child: GestureDetector(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        item?['id'] ?? '',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(item?['data']['name'] ?? '',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                            Text(
                                              '${item?['data']['startDate']} - ${item?['data']['endDate']}',
                                              style: TextStyle(fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            statusChip(
                                                item?['data']['status'] ?? ''),
                                            Text(
                                              'USUARIOS ASOCIADOS: ${item?['usuariosTotal'] ?? ''}',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            Text(
                                              'USUARIOS POR RESPONDER: ${item?['usuariosNonEnviada'] ?? ''}',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          String dates = item?['data']
                                                  ['startDate'] +
                                              ' - ' +
                                              item?['data']['endDate'];
                                          String hours =
                                              horasEsperadasDe(item?['data']);
                                          _loadAndShowUsers(
                                              context,
                                              item?['id'],
                                              item?['data']['name'] ?? '',
                                              dates,
                                              hours,
                                              item?['data']['status']);
                                        },
                                        icon: Icon(
                                            Icons.remove_red_eye_outlined,
                                            color: Colors.blue),
                                      ),
                                      Visibility(
                                        visible: true,
                                        child: IconButton(
                                          onPressed: () {
                                            if (item != null &&
                                                item.containsKey('id') &&
                                                item['data']['status'] ==
                                                    'ACTIVA') {
                                              confirmacionEmail(
                                                  context,
                                                  item['id'],
                                                  item['data']['name']);
                                            }
                                          },
                                          icon: Icon(Icons.email_outlined,
                                              color: item?['data']['status'] ==
                                                      'ACTIVA'
                                                  ? Colors.green
                                                  : Colors.grey),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          if (item != null &&
                                              item.containsKey('id') &&
                                              item['data']['status'] ==
                                                  'CREADA') {
                                            mostrarDialogoConfirmacion(
                                                context, item['id']);
                                          } else {
                                            print(
                                                'Error: ID del documento no disponible');
                                          }
                                        },
                                        icon: Icon(
                                            Icons.delete_outline_outlined,
                                            color: item?['data']['status'] ==
                                                    'CREADA'
                                                ? Colors.red
                                                : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              onTap: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AddEditForm(
                                        reloadList: _reloadList,
                                        id: item?['id'],
                                        name: item?['data']['name'],
                                        startDate: item?['data']['startDate'],
                                        endDate: item?['data']['endDate'],
                                        days: item?['data']['days'],
                                        status: item?['data']['status'],
                                        hours: item?['data']['hours'],
                                        tipo: item?['data']['tipo'],
                                      );
                                    });
                              },
                            ));
                      },
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                }),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          modalTipoEncuesta(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void modalTipoEncuesta(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('TIPO DE ENCUESTA'),
          content: Text('¿PARA QUIÉN ESTÁ DESTINADA ESTA ENCUESTA?'),
          actions: <Widget>[
            TextButton(
              child: Text('ENCUESTA PARA GERENTES'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddEditForm(
                            tipo: 'G',
                            reloadList: _reloadList,
                          )), // Navigate to the NewUserPage
                );
              },
            ),
            TextButton(
              child: Text('ENCUESTA PARA USUARIOS'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddEditForm(
                            tipo: 'U',
                            reloadList: _reloadList,
                          )), // Navigate to the NewUserPage
                );
              },
            ),
            TextButton(
              child: Text('ENCUESTA PARA TODOS'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddEditForm(
                            tipo: 'T',
                            reloadList: _reloadList,
                          )), // Navigate to the NewUserPage
                );
              },
            ),
          ],
        );
      },
    );
  }

  void mostrarDialogoConfirmacion(BuildContext context, String documentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CONFIRMACIÓN'),
          content: Text('¿ESTÁS SEGURO DE QUE DESEAS ELIMINAR ESTA ENCUESTA?'),
          actions: <Widget>[
            TextButton(
              child: Text('CANCELAR'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ELIMINAR'),
              onPressed: () async {
                Navigator.of(context).pop(); // Cierra el diálogo
                await eliminarItem(
                    documentId); // Llama a la función de eliminación
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> eliminarItem(String documentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Encuestas')
          .doc(documentId)
          .update({'status': 'ELIMINADA'});
      print('Estado del documento actualizado a ELIMINADA con éxito');

      if (mounted) {
        // Verifica si el widget aún está montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ENCUESTA ELIMINADA SATISFACTORIAMENTE')),
        );
        _reloadList(); // Asegúrate de definir _reloadList en tu widget para actualizar la lista
      }
    } catch (e) {
      print('Error al actualizar el estado del documento: $e');
      if (mounted) {
        // Verifica si el widget aún está montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el documento: $e')),
        );
      }
    }
  }

  Future<void> sendEmail(String id, String nameEncuesta, String body) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Obtener IDs de la subcolección 'Usuarios' dentro de 'Encuestas'
    final selectedUsersSnapshot = await firestore
        .collection('Encuestas')
        .doc(id)
        .collection('Usuarios')
        .get();

    final selectedUsersIds =
        selectedUsersSnapshot.docs.map((doc) => doc.id).toList();

    // 2. Leer documentos de 'Usuarios' en paralelo (en vez de 1x1)
    final futures = selectedUsersIds.map((userId) async {
      final userDoc = await firestore.collection('Usuarios').doc(userId).get();
      final userData = userDoc.data();

      if (userDoc.exists && userData != null && userData.containsKey('email')) {
        return userData['email'] as String;
      }
      return null;
    }).toList();

    final selectedEmails =
        (await Future.wait(futures)).whereType<String>().toList();

    // Si no hay correos, no seguimos
    if (selectedEmails.isEmpty) {
      print(
          'No se encontraron correos electrónicos para los usuarios seleccionados.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron correos electrónicos válidos.'),
          ),
        );
      }
      return;
    }

    // Opcional: si quieres reflejar algo en la UI
    if (mounted) {
      setState(() {});
    }

    print(selectedEmails); // Para verificar la lista

    // 3. Enviar correo usando tu función existente
    await manualSendEmail(selectedEmails, nameEncuesta, body);
  }

  Future<void> manualSendEmail(
      List<String> recipients, String nameEncuesta, String body) async {
    String subject = "Invitación a diligenciar la encuesta $nameEncuesta";
    final String recipientsString = recipients.join(',');

    final url = Uri.parse(
        'https://v1.nocodeapi.com/javirueda7/zohomail/PrBQEYwVPmgtekXW/sendEmail?fromAddress=auxiliar.pmo@cyma.com.co&toAddress=$recipientsString&content=$body&subject=$subject&mailFormat=html');

    final headers = {
      'Content-Type': 'application/json',
    };

    final response = await http.post(url, headers: headers);

    if (response.statusCode == 200) {
      print('Success: ${response.body}');
    } else {
      print('Failed: ${response.statusCode}');
    }
  }

  void confirmacionEmail(BuildContext context, String id, String nameEncuesta) {
    TextEditingController emailBodyController = TextEditingController(text: '''
      Hola, el área técnica de CyMA te invita a responder la última encuesta, presiona en el siguiente link para visitar la plataforma de Encuestas MOP.
      
      https://cyma-encuestasmop.github.io/EncuestasMOP/
      
      Si ya fue respondida, hacer caso omiso a este correo.

      Cordial saludo,
      Equipo CyMA - Encuestas MOP
    ''');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CONFIRMACIÓN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                  '¿ESTÁS SEGURO QUE DESEAS ENVIAR LA INVITACIÓN A RESPONDER $nameEncuesta?'),
              SizedBox(height: 20),
              SizedBox(
                width: 800,
                child: TextField(
                  controller: emailBodyController,
                  decoration: InputDecoration(
                    labelText: 'Cuerpo del correo',
                    hintText: 'Escribe tu mensaje aquí',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 20,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('CANCELAR'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ENVIAR INVITACIONES'),
              onPressed: () async {
                String emailBody =
                    generateSimpleHtmlBody(emailBodyController.text);
                Navigator.of(context).pop(); // Cierra el diálogo
                await sendEmail(id, nameEncuesta,
                    emailBody); // Llama a la función de envío de correo
              },
            ),
          ],
        );
      },
    );
  }

  String generateSimpleHtmlBody(String body) {
    // Reemplaza los saltos de línea con etiquetas <br>
    String htmlBody = body.replaceAll('\n', '<br>');

    return '''
    <html>
      <body>
        <p>$htmlBody</p>
      </body>
    </html>
    ''';
  }

  Future<void> _loadAndShowUsers(
    BuildContext context,
    String id,
    String titulo,
    String dates,
    String hours,
    String status,
  ) async {
    // Mostrar círculo de carga mientras se obtienen los datos
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Leer subcolección de usuarios de la encuesta
      final selectedUsersSnapshot = await firestore
          .collection('Encuestas')
          .doc(id)
          .collection('Usuarios')
          .get();

      // 2. Disparar TODAS las lecturas a 'Usuarios' en paralelo (en vez de 1x1)
      final futures = selectedUsersSnapshot.docs.map((doc) async {
        final userId = doc.id;
        final dataEncuestaUser = doc.data();
        final userStatus = dataEncuestaUser['status'];
        final userAnswer = dataEncuestaUser['answer'];
        final userDate = dataEncuestaUser['date'];

        final userDoc =
            await firestore.collection('Usuarios').doc(userId).get();
        final userData = userDoc.data();

        if (!userDoc.exists || userData == null) {
          return null;
        }

        return User(
          id: userId,
          status: userStatus,
          data: userData,
          answer: userAnswer,
          date: userDate,
        );
      }).toList();

      // Esperar todos los futures y filtrar nulls
      final users = (await Future.wait(futures)).whereType<User>().toList();

      // 3. Ordenar por estado y luego por nombre, igual que antes
      users.sort((a, b) {
        const statusOrder = {
          'ABIERTA': 0,
          'GUARDADA': 1,
          'ENVIADA': 2,
        };

        final orderA = statusOrder[a.status] ?? 999;
        final orderB = statusOrder[b.status] ?? 999;

        final statusComparison = orderA.compareTo(orderB);
        if (statusComparison != 0) return statusComparison;

        final nameA = (a.data['name'] ?? '') as String;
        final nameB = (b.data['name'] ?? '') as String;
        return nameA.compareTo(nameB);
      });

      if (!mounted) {
        // Si el widget ya no está montado, solo cierro el loader y salgo
        Navigator.of(context).pop();
        return;
      }

      // Cerrar el círculo de carga
      Navigator.of(context).pop();

      // 4. Mostrar el diálogo con la lista de usuarios
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            alignment: Alignment.center,
            actionsAlignment: MainAxisAlignment.center,
            title: Text('USUARIOS POR RESPONDER - $titulo'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    leading: Text(users[index].status),
                    title: Text(users[index].data['name']),
                    subtitle: Text(users[index].id), // ID del usuario
                    trailing: IconButton(
                      onPressed: () {
                        if (users[index].status != 'ABIERTA') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormsPage(
                                idForm: id,
                                formName: titulo,
                                dates: dates,
                                uidUser: users[index].id,
                                hours: hours,
                                formState: users[index].status,
                                answers: users[index].answer,
                                date: (users[index].date as Timestamp).toDate(),
                                reloadList: _reloadList,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El usuario no ha inicilizado esta encuesta',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.remove_red_eye_outlined,
                        color: Colors.blueAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('CERRAR'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error al cargar usuarios: $e');

      // Cerrar el círculo de carga en caso de error
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: $e')),
        );
      }
    }
  }
}

class User {
  final String id;
  final String status;
  final Map<String, dynamic> data;
  final dynamic answer;
  final dynamic date;

  User(
      {required this.id,
      required this.status,
      required this.data,
      required this.answer,
      required this.date});
}
