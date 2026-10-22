// ignore_for_file: avoid_web_libraries_in_flutter, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:forms_app/listforms.dart';
import 'package:forms_app/listparam.dart';
import 'package:forms_app/listusers.dart';
import 'package:forms_app/userforms.dart';
import 'dart:html' as html;

class MainMenu extends StatefulWidget {
  final String? role;
  final String? uid;
  MainMenu({super.key, required this.role, required this.uid});
  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  String role = 'ANON';
  String uid = '';

  @override
  void initState() {
    super.initState();
    role = widget.role ?? role;
    uid = widget.uid ?? uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('CYMA - ENCUESTAS MOP')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (role != 'ADMINISTRADOR') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ListUserForms(uid: uid))),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text('RESPONDER ENCUESTA'),
                  ),
                ],
                if (role != 'USUARIO') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ListFormsScreen())),
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    label: const Text('ADMINISTRAR ENCUESTAS'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ListUsersScreen())),
                    icon: const Icon(Icons.people_outline, size: 20),
                    label: const Text('ADMINISTRAR USUARIOS'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ListParameterScreen(param: 'Proyectos'))),
                    icon: const Icon(Icons.business_center_outlined, size: 20),
                    label: const Text('ADMINISTRAR PROYECTOS'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ListParameterScreen(param: 'Actividades'))),
                    icon: const Icon(Icons.task_outlined, size: 20),
                    label: const Text('ADMINISTRAR ACTIVIDADES'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ListParameterScreen(param: 'Cargos'))),
                    icon: const Icon(Icons.work_outline, size: 20),
                    label: const Text('ADMINISTRAR CARGOS'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ListParameterScreen(param: 'Profesiones'))),
                    icon: const Icon(Icons.school_outlined, size: 20),
                    label: const Text('ADMINISTRAR PROFESIONES'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => html.window.open(
                      "https://app.powerbi.com/view?r=eyJrIjoiMzBiZGZjMGYtMjJlMy00NDhiLThlODUtNmE3Mzk3NjA1MWM2IiwidCI6IjJlZDU1NzRjLWY5YmEtNDQyNi05NjU4LWU0NzdhZDc0MzlkYiIsImMiOjR9",
                      '_blank',
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    label: const Text('CONSULTAS'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
