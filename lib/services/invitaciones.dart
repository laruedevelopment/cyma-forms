import 'dart:convert' as convert;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Mismo script de Google (Apps Script) que recibe las respuestas. Él lee
/// quiénes faltan por responder y envía el correo; el navegador solo pide el
/// envío con la sesión del administrador.
const String _scriptUrl =
    'https://script.google.com/macros/s/AKfycbx5IBms2-rf8gDG4aBQD1i-MwrybevSjf7NJMSFmTAZMGZ5OiznEHIWO15FmW2WMcGJ/exec';

class ResultadoInvitacion {
  final bool ok;
  final String mensaje;
  final int destinatarios;
  final String proveedor;

  const ResultadoInvitacion({
    required this.ok,
    this.mensaje = '',
    this.destinatarios = 0,
    this.proveedor = '',
  });
}

Future<ResultadoInvitacion> _pedir(Map<String, String> datos) async {
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

/// Cuántas personas recibirían la invitación (sin enviar nada).
Future<ResultadoInvitacion> contarPendientes(String idEncuesta) =>
    _pedir({'idEncuesta': idEncuesta, 'simular': '1'});

/// Envía la invitación a quienes aún no han enviado la encuesta.
Future<ResultadoInvitacion> enviarInvitaciones(
        String idEncuesta, String cuerpo) =>
    _pedir({'idEncuesta': idEncuesta, 'cuerpo': cuerpo});
