import 'dart:convert' as convert;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Recordatorios por correo.
///
/// Forma principal (la de siempre): el navegador del administrador pide el envío
/// a nocodeapi, que lo manda por Zoho Mail desde auxiliar.pmo@cyma.com.co. El
/// enlace de nocodeapi lleva una clave, así que NO está en el código: se lee de
/// Firestore (Configuracion/correo), que solo pueden leer los administradores.
///
/// Respaldo: si ese enlace no está configurado, se pide el envío al Apps Script
/// (que lo manda por Gmail).
const String _scriptUrl =
    'https://script.google.com/macros/s/AKfycbx5IBms2-rf8gDG4aBQD1i-MwrybevSjf7NJMSFmTAZMGZ5OiznEHIWO15FmW2WMcGJ/exec';
const String _remitente = 'auxiliar.pmo@cyma.com.co';
const int _destinatariosPorCorreo = 40;

class ResultadoInvitacion {
  final bool ok;
  final String mensaje;
  final int destinatarios;
  final String proveedor;

  /// Se puede mandar un correo de prueba solo al administrador.
  final bool permitePrueba;

  const ResultadoInvitacion({
    required this.ok,
    this.mensaje = '',
    this.destinatarios = 0,
    this.proveedor = '',
    this.permitePrueba = false,
  });
}

class _ConfigCorreo {
  final Uri base; // https://v1.nocodeapi.com/<cuenta>/zohomail/<clave>
  final bool usarCopiaOculta;
  const _ConfigCorreo(this.base, this.usarCopiaOculta);
}

/// Enlace de nocodeapi guardado por un MASTER; null si no está o no es válido.
Future<_ConfigCorreo?> _leerConfig() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('Configuracion')
        .doc('correo')
        .get();
    final url = doc.data()?['url'];
    if (url is! String) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'v1.nocodeapi.com') {
      return null;
    }
    // Copia oculta: se activa solo si se comprobó que nocodeapi la respeta.
    return _ConfigCorreo(uri, doc.data()?['bcc'] == true);
  } catch (_) {
    return null;
  }
}

/// Correos válidos y sin repetir de quienes tienen la encuesta y no la han enviado.
Future<List<String>> _correosPendientes(String idEncuesta) async {
  final db = FirebaseFirestore.instance;
  final asignados = await db
      .collection('Encuestas')
      .doc(idEncuesta)
      .collection('Usuarios')
      .get();
  final ids = [
    for (final d in asignados.docs)
      if (d.data()['status'] != 'ENVIADA') d.id
  ];
  final consultas = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
  for (int i = 0; i < ids.length; i += 30) {
    consultas.add(db
        .collection('Usuarios')
        .where(FieldPath.documentId,
            whereIn: ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30))
        .get());
  }
  final patron = RegExp(r'^[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+$');
  final vistos = <String>{};
  for (final snap in await Future.wait(consultas)) {
    for (final u in snap.docs) {
      final datos = u.data();
      if (datos['status'] != 'ACTIVO') continue;
      final correo = (datos['email'] ?? '').toString().trim().toLowerCase();
      if (patron.hasMatch(correo)) vistos.add(correo);
    }
  }
  return vistos.toList();
}

String _htmlCuerpo(String texto) {
  final seguro = texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final conEnlaces = seguro.replaceAllMapped(
      RegExp(r'(https?://[^\s<]+)'), (m) => '<a href="${m[1]}">${m[1]}</a>');
  return '<html><body><p>${conEnlaces.replaceAll(RegExp(r'\r?\n'), '<br>')}</p></body></html>';
}

/// Un correo por llamada a nocodeapi (la capa gratuita permite 300 llamadas al mes).
Future<String?> _enviarPorNocodeapi(
    _ConfigCorreo config, List<String> para, String asunto, String html,
    {bool copiaOculta = false}) async {
  final parametros = <String, String>{
    'fromAddress': _remitente,
    'toAddress': copiaOculta ? _remitente : para.join(','),
    if (copiaOculta) 'bccAddress': para.join(','),
    'subject': asunto,
    'content': html,
    'mailFormat': 'html',
  };
  final uri = config.base.replace(
    path: '${config.base.path.replaceAll(RegExp(r'/+$'), '')}/sendEmail',
    queryParameters: parametros,
  );
  try {
    final resp = await http.post(uri, headers: {
      'Content-Type': 'application/json'
    }).timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) return null;
    if (resp.statusCode == 429) {
      return 'Se agotó el límite mensual de nocodeapi. Inténtalo el mes siguiente o cambia de plan.';
    }
    return 'nocodeapi rechazó el envío (código ${resp.statusCode}). Si lleva más de una semana sin usarse, entra a nocodeapi y reactiva el servicio.';
  } catch (_) {
    return 'No se pudo conectar con el servicio de correo. Revisa tu conexión.';
  }
}

Future<ResultadoInvitacion> _pedirAlScript(Map<String, String> datos) async {
  try {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
    final resp = await http.post(Uri.parse(_scriptUrl), body: {
      ...datos,
      'accion': 'invitar',
      'idToken': idToken
    }).timeout(const Duration(seconds: 90));
    if (resp.statusCode != 200) {
      return const ResultadoInvitacion(
          ok: false,
          mensaje: 'El servicio de correo no respondió. Inténtalo de nuevo.');
    }
    final data = convert.jsonDecode(resp.body) as Map<String, dynamic>;
    final estado = (data['status'] ?? '').toString();
    final cantidad = (data['enviados'] ?? data['destinatarios'] ?? 0) as num;
    return ResultadoInvitacion(
      ok: estado == 'SUCCESS' || estado == 'OK',
      mensaje: (data['message'] ?? '').toString(),
      destinatarios: cantidad.toInt(),
      proveedor: (data['proveedor'] ?? '').toString(),
    );
  } catch (_) {
    return const ResultadoInvitacion(
        ok: false,
        mensaje:
            'No se pudo conectar con el servicio de correo. Revisa tu conexión.');
  }
}

/// Cuántas personas recibirían el recordatorio (sin enviar nada).
Future<ResultadoInvitacion> contarPendientes(String idEncuesta) async {
  final config = await _leerConfig();
  if (config == null) {
    return _pedirAlScript({'idEncuesta': idEncuesta, 'simular': '1'});
  }
  try {
    final correos = await _correosPendientes(idEncuesta);
    return ResultadoInvitacion(
        ok: true,
        destinatarios: correos.length,
        proveedor: 'Zoho',
        permitePrueba: true);
  } catch (_) {
    return const ResultadoInvitacion(
        ok: false, mensaje: 'No se pudo leer la lista de personas.');
  }
}

/// Envía el recordatorio a quienes aún no han enviado la encuesta.
Future<ResultadoInvitacion> enviarInvitaciones(
    String idEncuesta, String nombreEncuesta, String cuerpo) async {
  final config = await _leerConfig();
  if (config == null) {
    return _pedirAlScript({'idEncuesta': idEncuesta, 'cuerpo': cuerpo});
  }
  try {
    final correos = await _correosPendientes(idEncuesta);
    if (correos.isEmpty) {
      return const ResultadoInvitacion(
          ok: false, mensaje: 'No hay personas pendientes con correo.');
    }
    final asunto = 'Invitación a diligenciar la encuesta $nombreEncuesta';
    final html = _htmlCuerpo(cuerpo);
    int enviados = 0;
    for (int i = 0; i < correos.length; i += _destinatariosPorCorreo) {
      final lote = correos.sublist(
          i,
          i + _destinatariosPorCorreo > correos.length
              ? correos.length
              : i + _destinatariosPorCorreo);
      final error = await _enviarPorNocodeapi(config, lote, asunto, html,
          copiaOculta: config.usarCopiaOculta);
      if (error != null) {
        await _auditar(idEncuesta, enviados, 'con error');
        return ResultadoInvitacion(
            ok: false,
            mensaje: enviados == 0
                ? error
                : '$error Ya se habían enviado $enviados correos.',
            destinatarios: enviados);
      }
      enviados += lote.length;
    }
    await _auditar(idEncuesta, enviados, 'Zoho');
    return ResultadoInvitacion(
        ok: true, destinatarios: enviados, proveedor: 'Zoho');
  } catch (_) {
    return const ResultadoInvitacion(
        ok: false, mensaje: 'No se pudo enviar el recordatorio.');
  }
}

/// Manda el mismo mensaje solo al administrador, para ver cómo llega.
Future<ResultadoInvitacion> enviarPrueba(
    String nombreEncuesta, String cuerpo) async {
  final config = await _leerConfig();
  final yo = FirebaseAuth.instance.currentUser?.email;
  if (config == null || yo == null) {
    return const ResultadoInvitacion(
        ok: false, mensaje: 'La prueba no está disponible.');
  }
  final error = await _enviarPorNocodeapi(config, [yo],
      'PRUEBA - Invitación a la encuesta $nombreEncuesta', _htmlCuerpo(cuerpo),
      copiaOculta: config.usarCopiaOculta);
  return ResultadoInvitacion(
      ok: error == null,
      mensaje: error ?? 'Prueba enviada a $yo.',
      destinatarios: 1);
}

Future<void> _auditar(String idEncuesta, int cantidad, String detalle) async {
  try {
    final yo = FirebaseAuth.instance.currentUser;
    if (yo == null) return;
    await FirebaseFirestore.instance.collection('Auditoria').add({
      'accion': 'INVITACION',
      'actorUid': yo.uid,
      'idEncuesta': idEncuesta,
      'cantidad': cantidad,
      'detalle': detalle,
      'fecha': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // La auditoría no debe impedir el aviso.
  }
}
