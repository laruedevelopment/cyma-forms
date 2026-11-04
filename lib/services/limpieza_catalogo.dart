import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:forms_app/services/firebase_services.dart';

/// Limpieza de proyectos y actividades que ya no se ofrecen (inactivos o
/// pendientes). Las respuestas guardan el CÓDIGO del proyecto/actividad, así que
/// borrar uno que alguien usó dejaría esa encuesta sin nombre. Por eso solo se
/// borran los que no aparecen en ninguna respuesta.
class ResultadoLimpieza {
  /// Registros no activos que nadie usó: se pueden borrar.
  final List<Map<String, dynamic>> sinUso;

  /// Registros no activos que sí aparecen en alguna respuesta: se conservan.
  final List<Map<String, dynamic>> enUso;

  const ResultadoLimpieza(this.sinUso, this.enUso);
}

/// Revisa TODAS las respuestas (una sola vez) y separa lo que se puede borrar.
Future<ResultadoLimpieza> analizarCatalogo(
  String param,
  List<Map<String, dynamic>> items,
  void Function(String) progreso,
) async {
  final campo = param == 'Proyectos' ? 'proyecto' : 'actividad';
  final patron = RegExp('$campo=([^&;]+)');
  final usados = <String>{};

  final db = FirebaseFirestore.instance;
  progreso('Leyendo encuestas…');
  final encuestas = await db.collection('Encuestas').get();
  int hechas = 0;
  await Future.wait(encuestas.docs.map((e) async {
    final asignados = await e.reference.collection('Usuarios').get();
    for (final r in asignados.docs) {
      final respuesta = (r.data()['answer'] ?? '').toString();
      for (final m in patron.allMatches(respuesta)) {
        usados.add(Uri.decodeComponent(m.group(1)!));
      }
    }
    hechas++;
    progreso('Revisando respuestas… $hechas de ${encuestas.size} encuestas');
  }));

  final sinUso = <Map<String, dynamic>>[];
  final enUso = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item['data']['status'] == 'ACTIVO') continue;
    (usados.contains(item['id']) ? enUso : sinUso).add(item);
  }
  return ResultadoLimpieza(sinUso, enUso);
}

/// Borra los registros indicados (en lotes) y deja constancia en la auditoría.
Future<void> eliminarDelCatalogo(String param, List<String> ids) async {
  final db = FirebaseFirestore.instance;
  for (int i = 0; i < ids.length; i += 400) {
    final batch = db.batch();
    for (final id in ids.skip(i).take(400)) {
      batch.delete(db.collection(param).doc(id));
    }
    await batch.commit();
  }
  invalidarCatalogo(param);
  try {
    final yo = FirebaseAuth.instance.currentUser;
    if (yo != null) {
      await db.collection('Auditoria').add({
        'accion': 'LIMPIEZA_CATALOGO',
        'actorUid': yo.uid,
        'catalogo': param,
        'cantidad': ids.length,
        'ids': ids,
        'fecha': FieldValue.serverTimestamp(),
      });
    }
  } catch (_) {
    // La auditoría no debe impedir la limpieza.
  }
}
