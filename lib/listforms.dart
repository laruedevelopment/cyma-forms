// ignore_for_file: use_build_context_synchronously

import 'package:forms_app/form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/addeditforms.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/hours_utils.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';

class ListFormsScreen extends StatefulWidget {
  const ListFormsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListFormsScreenState createState() => _ListFormsScreenState();
}

class _ListFormsScreenState extends State<ListFormsScreen> {
  void _reloadList() {
    setState(() {
      _futuro = _cargar();
    });
  }

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  late Future<List<dynamic>> _futuro;

  Future<List<dynamic>> _cargar() async => await getEncuestas();

  void _abrirEditor(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditForm(
          reloadList: _reloadList,
          id: item['id'],
          name: item['data']['name'],
          startDate: item['data']['startDate'],
          endDate: item['data']['endDate'],
          days: item['data']['days'],
          status: item['data']['status'],
          hours: item['data']['hours'],
          tipo: item['data']['tipo'],
        ),
      ),
    );
  }

  void _verUsuarios(dynamic item) {
    final String dates =
        item['data']['startDate'] + ' - ' + item['data']['endDate'];
    final String hours = horasEsperadasDe(item['data']);
    _loadAndShowUsers(context, item['id'], item['data']['name'] ?? '', dates,
        hours, item['data']['status']);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar encuestas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => modalTipoEncuesta(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva encuesta'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos cargar las encuestas',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _reloadList,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final encuestas = snapshot.data!;
          return PageBody(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Encuestas', style: tema.headlineSmall),
                const SizedBox(height: 4),
                Text(
                    'Toca una encuesta para editarla. Con el ojo ves quién ha respondido.',
                    style: tema.bodyMedium),
                const SizedBox(height: 20),
                if (encuestas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Todavía no hay encuestas.')),
                  ),
                for (final item in encuestas) ...[
                  _TarjetaEncuesta(
                    item: item,
                    onEditar: () => _abrirEditor(item),
                    onVer: () => _verUsuarios(item),
                    onCorreo: () => confirmacionEmail(
                        context, item['id'], item['data']['name']),
                    onEliminar: () =>
                        mostrarDialogoConfirmacion(context, item['id']),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 72),
              ],
            ),
          );
        },
      ),
    );
  }

  void modalTipoEncuesta(BuildContext context) {
    void ir(String tipo) {
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                AddEditForm(tipo: tipo, reloadList: _reloadList)),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nueva encuesta'),
          content: const SizedBox(
            width: 380,
            child: Text('¿Para quién es esta encuesta?'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            OutlinedButton(
                onPressed: () => ir('G'), child: const Text('Gerentes')),
            OutlinedButton(
                onPressed: () => ir('U'), child: const Text('Usuarios')),
            ElevatedButton(
                onPressed: () => ir('T'), child: const Text('Todos')),
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
          title: const Text('Eliminar encuesta'),
          content: const Text(
              '¿Seguro que quieres eliminar esta encuesta? Solo se pueden eliminar las que aún no se han enviado.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Tinta.error),
              child: const Text('Eliminar'),
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
          const SnackBar(content: Text('Encuesta eliminada.')),
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

  // El envío de invitaciones por correo está fuera de servicio: el servicio
  // anterior (Zoho vía nocodeapi) fue dado de baja. Pendiente de un reemplazo
  // que corra en un servidor y no en el navegador.
  void confirmacionEmail(BuildContext context, String id, String nameEncuesta) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'El envío de invitaciones por correo no está disponible por ahora.'),
        duration: Duration(seconds: 5),
      ),
    );
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

      // 2. Datos de las personas: una consulta por cada 30 (límite de whereIn)
      //    en vez de una lectura por persona.
      final ids = selectedUsersSnapshot.docs.map((d) => d.id).toList();
      final bloques = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (int i = 0; i < ids.length; i += 30) {
        bloques.add(firestore
            .collection('Usuarios')
            .where(FieldPath.documentId,
                whereIn: ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30))
            .get());
      }
      final datosPersonas = <String, Map<String, dynamic>>{};
      for (final snap in await Future.wait(bloques)) {
        for (final d in snap.docs) {
          datosPersonas[d.id] = d.data();
        }
      }

      final users = <User>[];
      for (final doc in selectedUsersSnapshot.docs) {
        final userData = datosPersonas[doc.id];
        if (userData == null) continue;
        final dataEncuestaUser = doc.data();
        users.add(User(
          id: doc.id,
          status: dataEncuestaUser['status'],
          data: userData,
          answer: dataEncuestaUser['answer'],
          date: dataEncuestaUser['date'],
        ));
      }

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
            title: Text('Respuestas · $titulo'),
            content: SizedBox(
              width: 520,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(users[index].data['name'] ?? ''),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: statusChip(users[index].status)),
                    ),
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
                                // Un admin puede completar un borrador por la persona;
                                // lo ya enviado se ve en solo lectura.
                                onBehalfOfName:
                                    users[index].data['name'] as String?,
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
                                'Esta persona aún no ha iniciado la encuesta.',
                              ),
                            ),
                          );
                        }
                      },
                      tooltip: users[index].status == 'GUARDADA'
                          ? 'Ver o completar borrador'
                          : 'Ver respuestas',
                      icon: const Icon(
                        Icons.remove_red_eye_outlined,
                        color: Marca.c600,
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cerrar'),
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

class _TarjetaEncuesta extends StatelessWidget {
  final dynamic item;
  final VoidCallback onEditar;
  final VoidCallback onVer;
  final VoidCallback onCorreo;
  final VoidCallback onEliminar;

  const _TarjetaEncuesta({
    required this.item,
    required this.onEditar,
    required this.onVer,
    required this.onCorreo,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final estado = item['data']['status'] ?? '';
    final total = item['usuariosTotal'];
    final pendientes = item['usuariosNonEnviada'];
    final conteo = (total != null && pendientes != null)
        ? '$pendientes por responder de $total'
        : '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
        onTap: onEditar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item['data']['name'] ?? '',
                        style: tema.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  statusChip(estado),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                  '${item['id'] ?? ''}  ·  ${item['data']['startDate']} - ${item['data']['endDate']}',
                  style: tema.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(conteo, style: tema.bodyMedium),
                  ),
                  IconButton(
                    tooltip: 'Ver quién ha respondido',
                    onPressed: onVer,
                    icon: const Icon(Icons.remove_red_eye_outlined,
                        color: Marca.c600),
                  ),
                  IconButton(
                    tooltip: 'Enviar invitaciones por correo',
                    onPressed: estado == 'ACTIVA' ? onCorreo : null,
                    icon: const Icon(Icons.email_outlined),
                  ),
                  IconButton(
                    tooltip: estado == 'CREADA'
                        ? 'Eliminar encuesta'
                        : 'Solo se eliminan encuestas sin enviar',
                    onPressed: estado == 'CREADA' ? onEliminar : null,
                    icon: Icon(Icons.delete_outline_outlined,
                        color: estado == 'CREADA' ? Tinta.error : null),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
