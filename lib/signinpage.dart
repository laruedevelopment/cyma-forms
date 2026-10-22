// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/mainmenu.dart';
import 'package:forms_app/newuser.dart';
import 'package:forms_app/resetpassword.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  void _reloadList() {
    setState(() {}); // Empty setState just to trigger rebuild
  }

  bool _loggingIn = false;
  String? _error;

  final TextEditingController _passwordTextcontroller = TextEditingController();
  final TextEditingController _emailTextController = TextEditingController();

  @override
  void dispose() {
    _passwordTextcontroller.dispose();
    _emailTextController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loggingIn) return;
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    const mensajeError =
        'El correo o la contraseña no coinciden. Revísalos o crea una cuenta.';
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailTextController.text.trim(),
          password: _passwordTextcontroller.text);
      final uid = credential.user!.uid;
      final userData = await fetchUserData(uid);
      if (userData == null || userData['status'] != 'ACTIVO') {
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _error = mensajeError);
        return;
      }
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  MainMenu(role: userData['role'], uid: uid)));
    } catch (_) {
      if (mounted) setState(() => _error = mensajeError);
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/LogoCyMA.png',
                        height: 84, semanticLabel: 'Logo de CyMA'),
                  ),
                  const SizedBox(height: 24),
                  Text('Encuestas MOP',
                      textAlign: TextAlign.center, style: tema.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Registro de horas por proyecto y actividad',
                      textAlign: TextAlign.center, style: tema.bodyMedium),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Tinta.superficie,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Tinta.borde),
                    ),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Iniciar sesión', style: tema.titleMedium),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Tinta.errorFondo,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 18, color: Tinta.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Tinta.error,
                                            fontSize: 13.5)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailTextController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'nombre@cyma.com.co',
                            ),
                          ),
                          const SizedBox(height: 16),
                          PasswordField(
                            label: 'Contraseña',
                            controller: _passwordTextcontroller,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _login(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ResetPasswordPage()),
                              ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          firebaseButton(context, 'Entrar', _login,
                              loading: _loggingIn),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AddEditUser(
                              reloadList: _reloadList,
                              admin: false,
                            );
                          });
                    },
                    child: const Text('Crear una cuenta'),
                  ),
                  const SizedBox(height: 32),
                  Text('Consultoría y Medio Ambiente S.A.',
                      textAlign: TextAlign.center, style: tema.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
