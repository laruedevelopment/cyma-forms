import 'dart:convert' as convert;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Recordatorios por correo.
///
/// El navegador pide el envío a un Apps Script de Google que corre con una
/// cuenta de correo propia de la plataforma (no la de una persona). El script
/// comprueba la sesión, lee quién falta por responder y envía con copia oculta;
/// las respuestas van a auxiliar.pmo@cyma.com.co. Fuente: apps-script/Correo.gs
const String _correoUrl = 'https://script.google.com/macros/s/PENDIENTE/exec';

class ResultadoInvitacion {
  final bool ok;
  final String mensaje;
  final int destinatarios;

  const ResultadoInvitacion({
    required this.ok,
    this.mensaje = '',
    this.destinatarios = 0,
  });
}

Future<ResultadoInvitacion> _pedir(Map<String, String> datos) async {
  if (_correoUrl.contains('PENDIENTE')) {
    return const ResultadoInvitacion(
        ok: false,
        mensaje: 'El envío de recordatorios todavía no está configurado.');
  }
  try {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
    final resp = await http.post(Uri.parse(_correoUrl), body: {
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
    );
  } catch (_) {
    return const ResultadoInvitacion(
        ok: false,
        mensaje:
            'No se pudo conectar con el servicio de correo. Revisa tu conexión.');
  }
}

/// Cuántas personas recibirían el recordatorio (sin enviar nada).
Future<ResultadoInvitacion> contarPendientes(String idEncuesta) =>
    _pedir({'idEncuesta': idEncuesta, 'simular': '1'});

/// Envía el recordatorio a quienes aún no han enviado la encuesta.
Future<ResultadoInvitacion> enviarInvitaciones(
    String idEncuesta, String cuerpo) async {
  final r = await _pedir({'idEncuesta': idEncuesta, 'cuerpo': cuerpo});
  await _auditar(idEncuesta, r.destinatarios, r.ok ? 'enviado' : 'con error');
  return r;
}

/// Manda el mismo mensaje solo al administrador, para ver cómo llega.
Future<ResultadoInvitacion> enviarPrueba(
    String idEncuesta, String cuerpo) async {
  final r =
      await _pedir({'idEncuesta': idEncuesta, 'cuerpo': cuerpo, 'prueba': '1'});
  if (!r.ok) return r;
  final yo = FirebaseAuth.instance.currentUser?.email ?? 'tu correo';
  return ResultadoInvitacion(
      ok: true, mensaje: 'Prueba enviada a $yo.', destinatarios: 1);
}

/// Deja constancia de quién envió un recordatorio y a cuántas personas.
Future<void> _auditar(String idEncuesta, int cantidad, String detalle) async {
  try {
    final yo = FirebaseAuth.instance.currentUser;
    if (yo == null || cantidad == 0) return;
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
