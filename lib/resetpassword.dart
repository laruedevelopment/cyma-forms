// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailTextController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _emailTextController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final correo = _emailTextController.text.trim();
    if (correo.isEmpty || !correo.contains('@') || !correo.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un correo válido.')),
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Si el correo está registrado, te enviamos un enlace para crear una contraseña nueva.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No pudimos enviar el correo. Revisa que esté bien escrito e inténtalo de nuevo.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: PageBody(
        maxWidth: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Olvidaste tu contraseña?', style: tema.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Escribe el correo con el que te registraste y te enviamos un enlace para crear una nueva.',
              style: tema.bodyMedium,
            ),
            const SizedBox(height: 24),
            buildEmailField('CORREO', _emailTextController, false),
            const SizedBox(height: 20),
            firebaseButton(context, 'Enviar enlace', _enviar,
                loading: _enviando),
          ],
        ),
      ),
    );
  }
}
