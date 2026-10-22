// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/form.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/services/hours_utils.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';
import 'package:intl/intl.dart';

class ListUserForms extends StatefulWidget {
  final String uid;

  const ListUserForms({super.key, required this.uid});

  @override
  // ignore: library_private_types_in_public_api
  _ListUserFormsState createState() => _ListUserFormsState();
}

class _ListUserFormsState extends State<ListUserForms> {
  late String uid;
  late Future<List<dynamic>> _futureForms;

  @override
  void initState() {
    super.initState();
    uid = widget.uid;
    _futureForms = getEncuestasUser(uid); // cargamos por primera vez
  }

  void _reloadList() {
    setState(() {
      // forzamos a FutureBuilder a usar un Future NUEVO
      _futureForms = getEncuestasUser(uid);
    });
  }

  /// Abre la encuesta: editable si está activa, solo lectura si ya se cerró.
  Future<void> _abrir(dynamic item) async {
    final String? status = await getStatus(item['id'], uid);
    if (status != item['user']['status']) {
      _reloadList();
    }

    final bool activa = item['data']['status'] == 'ACTIVA';
    final bool abierta = item['user']['status'] == 'ABIERTA';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormsPage(
          idForm: item['id'],
          formName: item['data']['name'],
          dates: item['data']['startDate'] + ' - ' + item['data']['endDate'],
          uidUser: uid,
          hours: horasEsperadasDe(item['data']),
          formState: activa ? item['user']['status'] : 'ENVIADA',
          answers: abierta ? 'NULL' : item['user']['answer'],
          date: abierta
              ? DateTime.now()
              : (item['user']['date'] as Timestamp).toDate(),
          reloadList: _reloadList,
        ),
      ),
    );

    if (!activa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta encuesta ya está cerrada: solo puedes consultarla.'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    // Al volver de FormsPage, volvemos a consultar Firestore
    _reloadList();
  }

  String _accion(dynamic item) {
    if (item['data']['status'] != 'ACTIVA') return 'Ver';
    switch (item['user']['status']) {
      case 'ENVIADA':
        return 'Ver';
      case 'GUARDADA':
        return 'Continuar';
      default:
        return 'Responder';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Responder encuesta')),
      body: FutureBuilder<List<dynamic>>(
        future: _futureForms,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos cargar tus encuestas',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _reloadList,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final encuestas = snapshot.data!;
          if (encuestas.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Todavía no tienes encuestas asignadas',
              message:
                  'Cuando te asignen una, aparecerá aquí para que registres tus horas.',
            );
          }
          return PageBody(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tus encuestas', style: tema.headlineSmall),
                const SizedBox(height: 4),
                Text('Elige una para registrar o revisar tus horas.',
                    style: tema.bodyMedium),
                const SizedBox(height: 20),
                for (final item in encuestas) ...[
                  _EncuestaCard(
                    item: item,
                    accion: _accion(item),
                    onTap: () => _abrir(item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String?> getStatus(String itemId, String uid) async {
    try {
      var documentSnapshot = await FirebaseFirestore.instance
          .collection('Encuestas')
          .doc(itemId)
          .collection('Usuarios')
          .doc(uid)
          .get();

      if (documentSnapshot.exists) {
        var data = documentSnapshot.data();
        return data?['status'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

class _EncuestaCard extends StatelessWidget {
  final dynamic item;
  final String accion;
  final VoidCallback onTap;

  const _EncuestaCard({
    required this.item,
    required this.accion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final userStatus = item['user']['status'] as String? ?? '';
    final surveyStatus = item['data']['status'] as String? ?? '';
    final nombre = item?['data']['name'] ?? '';
    final fechas =
        '${item?['data']['startDate']} - ${item?['data']['endDate']}';

    Widget estado;
    if (userStatus != 'ABIERTA' && item?['user']['date'] != null) {
      estado = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          statusChip(userStatus),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy HH:mm')
                .format(item['user']['date'].toDate()),
            style: tema.bodySmall,
          ),
        ],
      );
    } else {
      estado = statusChip(surveyStatus);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: tema.titleMedium),
                    const SizedBox(height: 4),
                    Text('${item?['id'] ?? ''}  ·  $fechas',
                        style: tema.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              estado,
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Marca.c50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(accion,
                    style: const TextStyle(
                        color: Marca.c700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
