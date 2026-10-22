import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forms_app/theme/app_theme.dart';

/// Etiqueta de estado: colores suaves con buen contraste y texto en minúscula.
Widget statusChip(String status) {
  final Color bg;
  final Color fg;
  switch (status.toUpperCase()) {
    case 'ENVIADA':
      bg = Tinta.okFondo;
      fg = Tinta.ok;
      break;
    case 'GUARDADA':
      bg = Tinta.avisoFondo;
      fg = Tinta.aviso;
      break;
    case 'PENDIENTE':
      bg = Tinta.avisoFondo;
      fg = Tinta.aviso;
      break;
    case 'ACTIVA':
    case 'ABIERTA':
      bg = Marca.c50;
      fg = Marca.c700;
      break;
    default: // CERRADA, CREADA, etc.
      bg = const Color(0xFFF1F5F9);
      fg = Tinta.textoMedio;
  }
  final texto = status.isEmpty
      ? ''
      : status.toUpperCase() == 'ABIERTA'
          ? 'Sin iniciar'
          : status[0].toUpperCase() + status.substring(1).toLowerCase();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(texto,
        style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1)),
  );
}

/// Botón principal de ancho completo. Mientras `loading` es true se bloquea y
/// muestra un indicador de carga.
Widget firebaseButton(BuildContext context, String title, Function onTap,
    {bool loading = false}) {
  return SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: loading ? null : () => onTap(),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Colors.white),
            )
          : Text(title, style: const TextStyle(fontSize: 15)),
    ),
  );
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final RegExp regExp = RegExp(r'^\+?[0-9]*$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    } else {
      return oldValue;
    }
  }
}

Widget buildDateField(
    String label, TextEditingController controller, BuildContext context) {
  return TextFormField(
    controller: controller,
    onTap: () async {
      final DateTime? picked = await showDatePicker(
        locale: const Locale("es", "CO"),
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2050),
      );
      if (picked != null && picked != DateTime.now()) {
        controller.text = "${picked.day}/${picked.month}/${picked.year}";
      }
    },
    readOnly: true,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
    ),
  );
}

Widget buildDropdownField(
  String label,
  List<dynamic> items,
  void Function(String?)? onChanged, {
  required String initialValue,
  required bool allowChange,
}) {
  return IgnorePointer(
    ignoring: !allowChange,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        constraints: const BoxConstraints(maxWidth: 800),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        enabled: allowChange,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            // El campo exterior ya dibuja el borde; evita heredar el del tema.
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          isExpanded: true,
          value: items.contains(initialValue) ? initialValue : items.first,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: allowChange ? onChanged : null,
          disabledHint:
              Text(items.contains(initialValue) ? initialValue : items.first),
        ),
      ),
    ),
  );
}

Widget buildTextField(
    String label, TextEditingController controller, bool read) {
  controller.addListener(() {
    final text = controller.text.toUpperCase();
    if (controller.text != text) {
      final cursorPosition = controller.selection.baseOffset;
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(
          offset: cursorPosition > text.length ? text.length : cursorPosition,
        ),
      );
    }
  });
  return SizedBox(
    width: 600,
    child: TextFormField(
      controller: controller,
      readOnly: read,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Widget buildEmailField(
    String label, TextEditingController controller, bool read) {
  controller.addListener(() {
    final text = controller.text.toLowerCase();
    if (controller.text != text) {
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  });
  return SizedBox(
    width: 600,
    child: TextFormField(
      controller: controller,
      readOnly: read,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Widget buildNumberField(
    String label, TextEditingController controller, bool read) {
  return SizedBox(
    width: 600,
    child: TextFormField(
      controller: controller,
      readOnly: read,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly
      ],
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Widget buildButton(String label, Color color, void Function()? onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(backgroundColor: color),
    child: Text(label),
  );
}

class PasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  // ignore: library_private_types_in_public_api
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscureText,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _obscureText ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(
              _obscureText
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: Tinta.textoSuave,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
        ),
      ),
    );
  }
}
