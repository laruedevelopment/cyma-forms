// ignore_for_file: prefer_typing_uninitialized_variables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:forms_app/services/firebase_services.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:forms_app/widgets/forms_widgets.dart';
import 'package:forms_app/widgets/page_body.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class FormsPage extends StatefulWidget {
  final String idForm; // Nullable to differentiate between adding and editing
  final String formName;
  final String dates;
  final String uidUser;
  final String hours;
  final String formState;
  final String answers;
  final DateTime date;
  final VoidCallback reloadList;
  // Si no es null, un administrador está completando la encuesta de esa persona.
  final String? onBehalfOfName;
  FormsPage({
    super.key,
    required this.idForm,
    required this.formName,
    required this.dates,
    required this.uidUser,
    required this.hours,
    required this.formState,
    required this.answers,
    required this.date,
    required this.reloadList,
    this.onBehalfOfName,
  });

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  bool get _onBehalf => widget.onBehalfOfName != null;

  String _confirmText() {
    final base = (double.tryParse(expectedHours) ?? 0) != totalHours
        ? 'Registraste $totalHours h y se esperan $expectedHours h. ¿Enviar de todas formas? Esta acción no es reversible.'
        : 'Esta acción no es reversible.';
    return _onBehalf
        ? 'Vas a enviar esta encuesta en nombre de ${widget.onBehalfOfName}. Quedará registrado que la envió tu usuario.\n\n$base'
        : base;
  }

  // Controllers
  final TextEditingController idTypeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController roleController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController professionController = TextEditingController();
  final TextEditingController sedeController = TextEditingController();
  // Projects and activities
  List<Map<String, dynamic>> projects = [];
  List<Parametro> projectsList = [];
  List<Parametro> activitiesList = [];
  String expectedHours = '';
  double totalHours = 0;
  bool enviarEncuesta = false;
  List<TextEditingController> projectControllers = [];
  List<TextEditingController> activityControllers = [];
  List<TextEditingController> hoursControllers = [];
  late final Future<void> dataFetch;
  bool isLoading = true; // Loading state

  // Initialize controllers and data in initState
  @override
  void initState() {
    super.initState();
    // Initialize lists and controllers here
    projects = [];
    projectControllers = [];
    activityControllers = [];
    hoursControllers = [];
    enviarEncuesta = widget.formState == 'ENVIADA' ? true : false;
    _formKey = GlobalKey<FormState>();

    dataFetch = retrieveDataAndInit().whenComplete(() {
      if (widget.formState != 'ABIERTA' &&
          widget.answers != 'NULL' &&
          widget.answers.isNotEmpty) {
        projects = loadAnswers(widget.answers);
        //print(1);
        //print(projects);
        initializeControllers(projects);
        updateTotalHours();
      }
    });
    updateTotalHours();
    setState(() {
      isLoading = false; // Data is no longer loading
    });
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    idTypeController.dispose();
    nameController.dispose();
    idController.dispose();
    roleController.dispose();
    positionController.dispose();
    professionController.dispose();
    sedeController.dispose();
    // Dispose all controllers
    for (var controller in projectControllers) {
      controller.dispose();
    }
    for (var controller in activityControllers) {
      controller.dispose();
    }
    for (var controller in hoursControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reloadList() async {
    await Future.wait([initPro(), initAct()]);
    setState(() {});
  }

  Future<void> retrieveDataAndInit() async {
    // Datos de la persona, proyectos y actividades en paralelo.
    await Future.wait([retrieveData(), initPro(), initAct()]);
  }

  Future<bool> _sendToSheetsAtomic({
    required String scriptURL,
    required String idEncuesta,
    required String idUsuario,
    required List projects,
    required String fechaString, // EXACTO: DateTime.now().toString()
  }) async {
    final submissionId = '$idEncuesta-$idUsuario-$fechaString';

    // Mantener EXACTAMENTE los nombres y el orden esperado en Apps Script
    final rows = <Map<String, dynamic>>[];
    for (var p in projects) {
      rows.add({
        'idencuesta': idEncuesta,
        'idusuario': idUsuario,
        'proyecto': p['project'],
        'actividad': p['activity'],
        'horas': p['hours'],
        'fecha': fechaString, // mismo formato que ya usas (toString)
      });
    }

    const int maxRetries = 3; // número máximo de intentos
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        // Token de sesión de Firebase: el script lo valida para confirmar que
        // quien envía es el dueño de las filas (idusuario).
        final idToken =
            await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';

        // Enviar como application/x-www-form-urlencoded (sin especificar headers)
        final resp = await http.post(
          Uri.parse(scriptURL),
          body: {
            'submissionId': submissionId,
            'idToken': idToken,
            'rows': convert.jsonEncode(
                rows), // rows va como JSON en un campo de formulario
          },
        );

        print('POST Sheets attempt=$attempt status=${resp.statusCode}');

        if (resp.statusCode == 200) {
          final data = convert.jsonDecode(resp.body);
          final status = (data['status'] ?? '').toString();
          if (status == 'SUCCESS' || status == 'SUCCESS_ALREADY_PROCESSED') {
            return true; // ✅ enviado correctamente o ya procesado
          }
        }
      } catch (e) {
        print('POST Sheets error (attempt $attempt) = $e');
      }

      // Si falló este intento, hacemos backoff antes del siguiente
      if (attempt < maxRetries) {
        final delayMs = 500 * attempt * attempt; // 0.5s, 2s, 4.5s...
        print('POST Sheets retry in ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // Si ningún intento logró enviar correctamente
    return false;
  }

  Future<void> initPro() async {
    projectsList = await getParamwithId('Proyectos');
    projectsList.sort((a, b) => a.name.trim().compareTo(b.name.trim()));
  }

  Future<void> initAct() async {
    activitiesList = await getParamwithId('Actividades');
  }

  Future<List<Parametro>> getSugProjects(String query) async {
    final q = query.toLowerCase();
    return projectsList.where((p) => p.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.name.trim().compareTo(b.name.trim()));
  }

  Future<List<Parametro>> getSugActivities(String query) async {
    final q = query.toLowerCase();
    return activitiesList
        .where((a) => a.name.toLowerCase().contains(q))
        .toList();
  }

  Future<List<Parametro>> getParamwithId(String param) async {
    // Catálogo en caché; en una encuesta enviada se ven todos, también los inactivos.
    // Proyectos y actividades se leen siempre al día: si un admin inactiva
    // uno, no debe seguir ofreciéndose.
    final docs = await catalogo(param, forzar: true);
    return [
      for (final d in docs)
        if (widget.formState == 'ENVIADA' ||
            (d['data']['status'] != null && d['data']['status'] != 'INACTIVO'))
          Parametro(id: d['id'], name: d['data']['name'] ?? '')
    ];
  }

  Future<void> retrieveData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(widget.uidUser)
          .get();
      if (snapshot.exists) {
        // Access data from snapshot
        Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          final nombres = await Future.wait([
            fetchParameter('Profesiones', data['profession']),
            fetchParameter('Cargos', data['position']),
          ]);
          final profession = nombres[0];
          final position = nombres[1];
          setState(() {
            idTypeController.text = data['idType'] ?? '';
            idController.text = data['id'] ?? '';
            nameController.text = data['name'] ?? '';
            roleController.text = data['role'] ?? '';
            professionController.text = profession ?? '';
            positionController.text = position ?? '';
            sedeController.text = data['sede'] ?? '';
            expectedHours = widget.hours;
          });
        }
      }
    } catch (error) {
      //print("Error retrieving data: $error");
    }
  }

  void addProject() {
    setState(() {
      final newProject = {'projectName': '', 'activityName': '', 'hours': '0'};
      projects.add(newProject);
      final projectController = TextEditingController();
      final activityController = TextEditingController();
      final hoursController = TextEditingController();
      projectControllers.add(projectController);
      activityControllers.add(activityController);
      hoursControllers.add(hoursController);
      // Add listeners to update the projects list
      projectController.addListener(() {
        newProject['projectName'] = projectController.text;
      });
      activityController.addListener(() {
        newProject['activityName'] = activityController.text;
      });
      hoursController.addListener(() {
        newProject['hours'] = hoursController.text;
        updateTotalHours();
      });
    });
  }

  void removeProject(int index) {
    setState(() {
      projects.removeAt(index);
      projectControllers[index].dispose();
      activityControllers[index].dispose();
      hoursControllers[index].dispose();
      projectControllers.removeAt(index);
      activityControllers.removeAt(index);
      hoursControllers.removeAt(index);
      updateTotalHours();
    });
  }

  void updateTotalHours() {
    double newTotal = 0;
    for (var project in projects) {
      var temp = project['hours'];
      if (temp != null && temp.toString().isNotEmpty) {
        newTotal += double.tryParse(temp.toString().replaceAll(',', '.')) ?? 0;
      }
    }
    setState(() {
      totalHours = double.parse(newTotal.toStringAsFixed(1));
    });
  }

  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.formName, overflow: TextOverflow.ellipsis),
            Text(widget.dates,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: Marca.c100)),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _margenLateral(context)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: Form(
                key: _formKey,
                child: FutureBuilder(
                    future: dataFetch,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'No pudimos cargar la encuesta',
                          message:
                              'Revisa tu conexión y vuelve a abrirla desde la lista.',
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_onBehalf) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD),
                                  border: Border.all(
                                      color: const Color(0xFFFFC107)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Estás completando la encuesta de ${widget.onBehalfOfName} como administrador. Los cambios y el envío quedarán registrados a tu nombre.',
                                  style: const TextStyle(
                                      color: Color(0xFF5D4B00),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Datos de la persona',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const Divider(height: 14),
                                    Wrap(
                                      spacing: 32,
                                      runSpacing: 10,
                                      children: [
                                        _infoField('Tipo de documento',
                                            idTypeController.text),
                                        _infoField('Identificación',
                                            idController.text),
                                        _infoField('Sede', sedeController.text),
                                        _infoField(
                                            'Nombre', nameController.text),
                                        _infoField('Rol', roleController.text),
                                        _infoField(
                                            'Cargo', positionController.text),
                                        _infoField('Profesión',
                                            professionController.text),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Actividades',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            _resumenHoras(),
                            SizedBox(height: 10),
                            ListView.builder(
                              shrinkWrap: true,
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                return buildProjectItem(index);
                              },
                            ),
                            SizedBox(height: 10),
                            if (projects.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                    'Aún no has agregado actividades. Pulsa «Agregar actividad» para empezar.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed:
                                    isLoading || widget.formState == 'ENVIADA'
                                        ? null
                                        : addProject,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Agregar actividad'),
                              ),
                            ),
                            SizedBox(height: 20),
                            Visibility(
                              visible: /*widget.formState != 'ENVIADA'*/ false,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AddParam(
                                                  param: 'Proyectos',
                                                  reloadList: _reloadList);
                                            },
                                          );
                                        },
                                        child: Text('AGREGAR NUEVO PROYECTO')),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: ElevatedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AddParam(
                                                  param: 'Actividades',
                                                  reloadList: _reloadList);
                                            },
                                          );
                                        },
                                        child: Text('AGREGAR NUEVA ACTIVIDAD')),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            _barraAcciones(),
                          ],
                        );
                      }
                    }),
              ),
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: const Color(0x990F2F4F),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            enviarEncuesta
                                ? 'Enviando tu encuesta. No cierres esta ventana.'
                                : 'Guardando tu borrador…',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _margenLateral(BuildContext c) {
    final w = MediaQuery.of(c).size.width;
    return w < 700 ? 8 : ((w - 900) / 2).clamp(16.0, 1000.0);
  }

  String _h(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Avance de horas registradas frente a las esperadas, con mensaje y color.
  Widget _resumenHoras() {
    final esperadas = double.tryParse(expectedHours) ?? 0;
    final falta = esperadas - totalHours;
    Color color = Tinta.textoSuave;
    String mensaje = '';
    if (esperadas > 0) {
      if (falta > 0) {
        color = Tinta.aviso;
        mensaje = 'Te faltan ${_h(falta)} h';
      } else if (falta < 0) {
        color = Tinta.error;
        mensaje = 'Te pasas ${_h(-falta)} h';
      } else {
        color = Tinta.ok;
        mensaje = 'Completo';
      }
    }
    final avance =
        esperadas <= 0 ? 0.0 : (totalHours / esperadas).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tinta.superficie,
        borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
        border: Border.all(color: Tinta.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Registraste ${_h(totalHours)} de $expectedHours h esperadas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (mensaje.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: Text(mensaje,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 8,
              backgroundColor: Tinta.borde,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  /// Guardar borrador y Enviar encuesta: dos acciones claras en vez de una
  /// casilla que cambiaba el texto del botón.
  Widget _barraAcciones() {
    if (widget.formState == 'ENVIADA') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Tinta.okFondo,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Tinta.ok, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Esta encuesta ya fue enviada. Solo puedes consultarla.',
                  style:
                      TextStyle(color: Tinta.ok, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: pressed
                ? null
                : () {
                    setState(() => enviarEncuesta = false);
                    _enviarOGuardar();
                  },
            child: const Text('Guardar borrador'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: pressed
                ? null
                : () {
                    setState(() => enviarEncuesta = true);
                    _enviarOGuardar();
                  },
            child: const Text('Enviar encuesta'),
          ),
        ),
      ],
    );
  }

  /// Guarda el borrador o envía la encuesta, según `enviarEncuesta`.
  /// Nombres de proyectos o actividades elegidos que hoy están INACTIVOS.
  Future<List<String>> _inactivosElegidos() async {
    try {
      final r = await Future.wait([
        catalogo('Proyectos', forzar: true),
        catalogo('Actividades', forzar: true),
      ]);
      Set<String> inactivos(List<Map<String, dynamic>> docs) => {
            for (final d in docs)
              if (d['data']['status'] == 'INACTIVO')
                (d['data']['name'] ?? '').toString().trim()
          };
      final proyectos = inactivos(r[0]);
      final actividades = inactivos(r[1]);
      final elegidos = <String>[];
      for (int i = 0; i < projectControllers.length; i++) {
        final pr = projectControllers[i].text.trim();
        final ac = activityControllers[i].text.trim();
        if (proyectos.contains(pr)) elegidos.add(pr);
        if (actividades.contains(ac)) elegidos.add(ac);
      }
      return elegidos;
    } catch (_) {
      return []; // si no se puede comprobar, no bloquea el guardado
    }
  }

  Future<void> _enviarOGuardar() async {
    // Lock the button immediately to prevent double-submit
    setState(() {
      pressed = true;
      isLoading = true;
    });

    String currentState = await getFormState(widget.idForm, widget.uidUser);
    if (currentState != 'ENVIADA') {
      bool toReview = false;
      bool confirmed = true;

      if (enviarEncuesta) {
        confirmed = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('¿Está seguro de que desea enviar la encuesta?'),
              content: Text(
                _confirmText(),
                style: TextStyle(fontSize: 18),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      }

      if (!confirmed) {
        setState(() {
          isLoading = false;
          pressed = false;
        });
        return;
      }

      // Un proyecto o actividad inactivado mientras la persona llenaba la
      // encuesta no puede guardarse: se revisa contra los datos actuales.
      final inactivos = await _inactivosElegidos();
      if (inactivos.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ya no está disponible: ${inactivos.join(', ')}. Cámbialo por otro y vuelve a intentar.'),
            duration: const Duration(seconds: 6),
          ),
        );
        setState(() {
          isLoading = false;
          pressed = false;
        });
        return;
      }

      // Continue with the rest of your logic to update projects and send the survey...
      setState(() {
        for (int i = 0; i < projects.length; i++) {
          projects[i]['projectName'] = projectControllers[i].text;
          projects[i]['activityName'] = activityControllers[i].text;
          projects[i]['hours'] = hoursControllers[i].text;
        }
      });

      if (projects.isEmpty && enviarEncuesta) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, agregue al menos una actividad.'),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          isLoading = false;
          pressed = false;
        });
        return;
      }

      for (var controller in activityControllers) {
        if (controller.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Por favor, complete todos los campos de actividades.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            isLoading = false;
            pressed = false;
          });
          return; // Prevent form submission if any activityController is empty
        }
      }

      for (var controller in projectControllers) {
        if (controller.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Por favor, complete todos los campos de proyectos.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            isLoading = false;
            pressed = false;
          });
          return; // Prevent form submission if any projectController is empty
        }
      }

      // Check if any hoursController is empty
      for (var controller in hoursControllers) {
        if (controller.text.isEmpty || controller.text == '0') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Por favor, complete todos los campos de horas.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            isLoading = false;
            pressed = false;
          });
          return; // Prevent form submission if any hoursController is empty
        }
      }

      // Then, handle new projects and activities
      for (var project in projects) {
        if (!projectsList.any((p) => p.name == project['projectName'])) {
          // Check if project was already created in this session
          toReview = true;
        } else {
          project['project'] = projectsList
              .firstWhere((p) => p.name == project['projectName'])
              .id;
        }

        if (!activitiesList.any((a) => a.name == project['activityName'])) {
          // Check if activity was already created in this session
          toReview = true;
        } else {
          project['activity'] = activitiesList
              .firstWhere((a) => a.name == project['activityName'])
              .id;
        }
      }

      if (!toReview) {
        try {
          // Single timestamp used everywhere to keep data consistent
          final DateTime now = DateTime.now();
          final String fechaString = now.toString();

          List<String> projectStrings = [];
          for (var project in projects) {
            projectStrings.add(
                "?idencuesta=${widget.idForm}&idusuario=${widget.uidUser}&proyecto=${project['project']}&actividad=${project['activity']}&horas=${project['hours']}&fecha=$fechaString");
          }
          final String resultString = projectStrings.join(';');

          final bool tempEnv = enviarEncuesta;

          // Pre-flight check right before Sheets: abort early if already ENVIADA
          // (reduces race-condition window with concurrent sessions)
          if (tempEnv) {
            final preFlightState =
                await getFormState(widget.idForm, widget.uidUser);
            if (preFlightState == 'ENVIADA') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Esta encuesta ya fue enviada.'),
                  duration: Duration(seconds: 4),
                ),
              );
              setState(() {
                isLoading = false;
              });
              Navigator.of(context).pop();
              return;
            }
          }

          bool sheetsOk = false;
          if (tempEnv) {
            const String scriptURL =
                'https://script.google.com/macros/s/AKfycbx5IBms2-rf8gDG4aBQD1i-MwrybevSjf7NJMSFmTAZMGZ5OiznEHIWO15FmW2WMcGJ/exec';
            sheetsOk = await _sendToSheetsAtomic(
              scriptURL: scriptURL,
              idEncuesta: widget.idForm,
              idUsuario: widget.uidUser,
              projects: projects,
              fechaString: fechaString,
            );
          }

          // Transactional Firestore update: final safeguard against race conditions
          bool alreadyEnviada = false;
          final docRef = FirebaseFirestore.instance
              .collection('Encuestas')
              .doc(widget.idForm)
              .collection('Usuarios')
              .doc(widget.uidUser);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            final currentStatus = snapshot.data()?['status'] ?? '';
            if (currentStatus == 'ENVIADA') {
              alreadyEnviada = true;
              return;
            }
            // Si un administrador actúa por otra persona,
            // queda identificado en el documento y en
            // el registro de auditoría.
            final actor = FirebaseAuth.instance.currentUser?.uid;
            final onBehalf = actor != null && actor != widget.uidUser;
            transaction.update(docRef, {
              'answer': resultString,
              'status': sheetsOk ? 'ENVIADA' : 'GUARDADA',
              'date': now,
              'idencuesta': widget.idForm,
              if (onBehalf) 'editedBy': actor,
              if (onBehalf) 'editedAt': now,
              if (onBehalf && sheetsOk) 'sentBy': actor,
            });
            if (onBehalf) {
              transaction.set(
                  FirebaseFirestore.instance.collection('Auditoria').doc(), {
                'encuestaId': widget.idForm,
                'targetUid': widget.uidUser,
                'actorUid': actor,
                'action': sheetsOk ? 'ENVIO_POR' : 'EDITO_BORRADOR',
                'at': now,
              });
            }
          });

          if (alreadyEnviada) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Esta encuesta ya fue enviada.'),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() {
              isLoading = false;
            });
            Navigator.of(context).pop();
            return;
          }

          String snackText;
          if (tempEnv && sheetsOk) {
            snackText = 'Encuesta enviada exitosamente.';
          } else if (tempEnv && !sheetsOk) {
            snackText =
                'Tus respuestas se guardaron, pero no se pudo enviar a Google Sheets por un problema de red.';
          } else {
            snackText = 'Encuesta guardada exitosamente.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(snackText), duration: const Duration(seconds: 4)),
          );

          widget.reloadList();
          setState(() {
            isLoading = false;
          });
          Navigator.of(context).pop();
        } catch (e) {
          // Any network or Firestore error: reset state so user can retry
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al guardar la encuesta. Por favor intente de nuevo.'),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red.shade700,
            ),
          );
          setState(() {
            isLoading = false;
            pressed = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Por favor, cree los proyectos o actividades faltantes.'),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          isLoading = false;
          pressed = false;
        });
        return;
      }
      widget.reloadList();
      setState(() {
        isLoading = false;
      });
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Esta encuesta ya fue enviada.'),
          duration: Duration(seconds: 4),
        ),
      );
      setState(() {});
    }
  }

  late final _formKey;
  bool saving = false;

  List<Map<String, String>> loadAnswers(String encodedString) {
    List<Map<String, String>> parsedList = [];
    List<String> items = encodedString.split(';');
    for (String item in items) {
      if (item.isEmpty) continue;
      Map<String, String> itemMap = {};
      List<String> keyValuePairs = item.split('&');
      String proyectoValue = '';
      String activityValue = '';
      for (String keyValuePair in keyValuePairs) {
        List<String> keyValue = keyValuePair.split('=');
        if (keyValue.length == 2) {
          String key = keyValue[0];
          String value = Uri.decodeComponent(keyValue[1]);
          if (key.startsWith('?')) {
            key = key.substring(1);
          }
          switch (key) {
            case 'proyecto':
              key = 'project';
              proyectoValue = value;
              break;
            case 'actividad':
              key = 'activity';
              activityValue = value;
              break;
            case 'horas':
              key = 'hours';
              break;
          }
          itemMap[key] = value;
        }
      }
      itemMap['projectName'] = getProjectNameById(proyectoValue);
      itemMap['activityName'] = getActivityNameById(activityValue);
      parsedList.add(itemMap);
    }
    return parsedList;
  }

  void initializeControllers(List<Map<String, dynamic>> answers) {
    for (int i = 0; i < answers.length; i++) {
      var answer = answers[i];
      if (answer.containsKey('project') && answer.containsKey('activity')) {
        String projectId = answer['project'] ?? '';
        String activityId = answer['activity'] ?? '';
        String projectName = getProjectNameById(projectId);
        String activityName = getActivityNameById(activityId);
        while (projectControllers.length <= i) {
          projectControllers.add(TextEditingController());
        }
        while (activityControllers.length <= i) {
          activityControllers.add(TextEditingController());
        }
        while (hoursControllers.length <= i) {
          hoursControllers.add(TextEditingController());
        }
        projectControllers[i].text = projectName;
        activityControllers[i].text = activityName;
        hoursControllers[i].text = answer['hours'] ?? '';
      }
    }
  }

  Widget buildProjectItem(int index) {
    TextEditingController projectController = projectControllers[index];
    TextEditingController activityController = activityControllers[index];
    TextEditingController hoursController = hoursControllers[index];
    projectController.addListener(() {
      final text = projectController.text.toUpperCase();
      if (projectController.text != text) {
        projectController.value = projectController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    activityController.addListener(() {
      final text = activityController.text.toUpperCase();
      if (activityController.text != text) {
        activityController.value = activityController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });

    final bool bloqueado = widget.formState == 'ENVIADA';
    final estiloTexto = TextStyle(color: bloqueado ? Tinta.texto : null);

    final proyecto = TypeAheadFormField<Parametro>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: projectController,
        enabled: !bloqueado,
        decoration: const InputDecoration(labelText: 'Proyecto'),
        style: estiloTexto,
      ),
      suggestionsCallback: getSugProjects,
      onSuggestionSelected: (project) {
        setState(() {
          projects[index]['project'] = project.id;
          projects[index]['projectName'] = project.name;
          projectController.text = project.name;
        });
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (proyecto) {
        if (proyecto!.isEmpty) {
          return 'Elige un proyecto de la lista';
        } else if (!projectsList.any((project) => project.name == proyecto)) {
          return 'Ese proyecto no está en la lista';
        } else {
          return null;
        }
      },
      itemBuilder: (context, project) {
        return ListTile(
          dense: true,
          title: Text(project.name),
        );
      },
      onSaved: (proyecto) async {
        if (proyecto != null &&
            !projectsList.any((project) => project.name == proyecto)) {
          await saveParameter('Proyectos', proyecto, 'PENDIENTE');
          projectsList.add(Parametro(
              id: DateTime.now().toString(),
              name: proyecto)); // Temporarily add the new project
        }
      },
      noItemsFoundBuilder: (context) {
        return const SizedBox.shrink();
      },
    );

    final actividad = TypeAheadFormField<Parametro>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: activityController,
        enabled: !bloqueado,
        decoration: const InputDecoration(labelText: 'Actividad'),
        style: estiloTexto,
      ),
      suggestionsCallback: getSugActivities,
      onSuggestionSelected: (activity) {
        setState(() {
          projects[index]['activity'] = activity.id;
          projects[index]['activityName'] = activity.name;
          activityController.text = activity.name;
        });
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (activity) {
        if (activity!.isEmpty) {
          return 'Elige una actividad de la lista';
        } else if (!activitiesList.any((act) => act.name == activity)) {
          return 'Esa actividad no está en la lista';
        } else {
          return null;
        }
      },
      itemBuilder: (context, activity) {
        return ListTile(
          dense: true,
          title: Text(activity.name),
        );
      },
      onSaved: (activity) async {
        // Save the ocupacion to Firebase if it's a new value
        if (!activitiesList.any((act) => act.name == activity)) {
          saveParameter('Actividades', activity!, 'PENDIENTE');
        }
      },
      noItemsFoundBuilder: (context) {
        return const SizedBox.shrink();
      },
    );

    final horas = TextFormField(
      controller: hoursController,
      enabled: !bloqueado,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: const InputDecoration(labelText: 'Horas', suffixText: 'h'),
      style: estiloTexto,
      onChanged: (value) {
        double? newValue = double.tryParse(value);
        setState(() {
          projects[index]['hours'] =
              newValue?.toString(); // Store as String to avoid type issues
          updateTotalHours();
        });
        // Preserve cursor position
        hoursController.value = hoursController.value.copyWith(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
    );

    final quitar = IconButton(
      tooltip: 'Quitar actividad',
      onPressed: bloqueado ? null : () => removeProject(index),
      icon: Icon(Icons.delete_outline,
          color: bloqueado ? Tinta.deshabilitado : Tinta.error),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 640) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: proyecto),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: actividad),
                const SizedBox(width: 12),
                SizedBox(width: 110, child: horas),
                const SizedBox(width: 4),
                quitar,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              proyecto,
              const SizedBox(height: 12),
              actividad,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: horas),
                  const SizedBox(width: 4),
                  quitar,
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget buildTextField(
      String labelText, TextEditingController controller, bool readOnly) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
    );
  }

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Tinta.textoSuave,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value : '—',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Tinta.texto)),
      ],
    );
  }

  String getProjectNameById(String id) {
    if (id.isEmpty) return '';
    var project = projectsList.firstWhere((p) => p.id == id,
        orElse: () => Parametro(id: '', name: ''));
    return project.name;
  }

  String getActivityNameById(String id) {
    if (id.isEmpty) return '';
    var activity = activitiesList.firstWhere((a) => a.id == id,
        orElse: () => Parametro(id: '', name: ''));
    return activity.name;
  }
}

class Parametro {
  final String id;
  final String name;
  Parametro({required this.id, required this.name});
}

class AddParam extends StatefulWidget {
  final String param;
  final VoidCallback reloadList;

  AddParam({required this.param, required this.reloadList});

  @override
  // ignore: library_private_types_in_public_api
  _AddParamState createState() => _AddParamState();
}

class _AddParamState extends State<AddParam> {
  late String id;
  TextEditingController nameController = TextEditingController();
  String selectedEstado = 'PENDIENTE';
  bool isLoading = false; // Loading state

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text('AGREGAR ${widget.param.toUpperCase()}')),
      content: SizedBox(
        height: 200,
        child: Padding(
          padding: EdgeInsets.fromLTRB(300, 30, 300, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildTextField('NOMBRE', nameController, false),
            ],
          ),
        ),
      ),
      actions: [
        isLoading
            ? Center(
                child: CircularProgressIndicator()) // Show loading indicator
            : TextButton(
                onPressed: () {
                  if (isLoading) return; // Prevent further actions if loading
                  setState(() {
                    isLoading = true; // Set loading state to true
                  });
                  _saveParameter(context);
                },
                child: Text('AGREGAR'),
              ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('CANCELAR'),
        ),
      ],
    );
  }

  void _saveParameter(BuildContext context) async {
    String nombre = nameController.text;
    String estado = selectedEstado;
    String param = widget.param;
    try {
      await saveParameter(param, nombre, estado);
      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parámetro guardado exitosamente.'),
          duration: Duration(seconds: 4),
        ),
      );
      // Clear the name field after saving
      nameController.clear();
      // Trigger a refresh of the list by calling setState
      widget.reloadList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el parámetro: $e'),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      Navigator.of(context).pop();
      setState(() {
        isLoading = false; // Reset loading state
      });
    }
  }
}
