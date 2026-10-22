import 'package:flutter/material.dart';

/// Colores de CyMA: azul institucional como base y dorado como único acento.
/// Mismos valores que usa el resto de aplicaciones de la marca.
class Marca {
  static const c50 = Color(0xFFEEF3F8);
  static const c100 = Color(0xFFD6E2EE);
  static const c200 = Color(0xFFADC4DC);
  static const c500 = Color(0xFF2D5B89);
  static const c600 = Color(0xFF1F4A75);
  static const c700 = Color(0xFF143D66);
  static const c800 = Color(0xFF0F2F4F);
  static const c900 = Color(0xFF0A2138);
}

class Dorado {
  static const c100 = Color(0xFFF4ECDC);
  static const c300 = Color(0xFFDCC28A);
  static const c500 = Color(0xFFB3914F);
  static const c700 = Color(0xFF806633);
}

/// Neutros cálidos y tonos de texto.
class Tinta {
  static const fondo = Color(0xFFF7F6F3);
  static const superficie = Colors.white;
  static const sutil = Color(0xFFF8FAFC);
  static const borde = Color(0xFFE2E8F0);
  static const bordeFuerte = Color(0xFFCBD5E1);
  static const texto = Color(0xFF1E293B);
  static const textoMedio = Color(0xFF334155);
  static const textoSuave = Color(0xFF566274);
  static const deshabilitado = Color(0xFF94A3B8);

  static const error = Color(0xFFB91C1C);
  static const errorFondo = Color(0xFFFEF2F2);
  static const ok = Color(0xFF166534);
  static const okFondo = Color(0xFFE7F4EA);
  static const aviso = Color(0xFF92400E);
  static const avisoFondo = Color(0xFFFEF3C7);
}

class AppTheme {
  static const double radioCampo = 10;
  static const double radioTarjeta = 12;

  static ThemeData get light {
    final esquema = ColorScheme.fromSeed(
      seedColor: Marca.c700,
      primary: Marca.c700,
      onPrimary: Colors.white,
      secondary: Dorado.c500,
      onSecondary: Tinta.texto,
      surface: Tinta.superficie,
      error: Tinta.error,
    );

    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radioCampo),
      borderSide: const BorderSide(color: Tinta.bordeFuerte),
    );

    return ThemeData(
      useMaterial3: false,
      colorScheme: esquema,
      primaryColor: Marca.c700,
      scaffoldBackgroundColor: Tinta.fondo,
      dividerColor: Tinta.borde,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Marca.c800,
            height: 1.25),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Marca.c800,
            height: 1.3),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Tinta.texto),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Tinta.texto),
        bodyLarge: TextStyle(fontSize: 15, color: Tinta.texto, height: 1.45),
        bodyMedium:
            TextStyle(fontSize: 14, color: Tinta.textoMedio, height: 1.45),
        bodySmall:
            TextStyle(fontSize: 12.5, color: Tinta.textoSuave, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Marca.c700,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardTheme(
        color: Tinta.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: const BorderSide(color: Tinta.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tinta.superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: borde,
        enabledBorder: borde,
        disabledBorder:
            borde.copyWith(borderSide: const BorderSide(color: Tinta.borde)),
        focusedBorder: borde.copyWith(
            borderSide: const BorderSide(color: Marca.c500, width: 2)),
        errorBorder:
            borde.copyWith(borderSide: const BorderSide(color: Tinta.error)),
        focusedErrorBorder: borde.copyWith(
            borderSide: const BorderSide(color: Tinta.error, width: 2)),
        labelStyle: const TextStyle(color: Tinta.textoSuave, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Marca.c600, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: Tinta.deshabilitado),
        errorStyle: const TextStyle(color: Tinta.error, fontSize: 12.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Marca.c700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Tinta.borde,
          disabledForegroundColor: Tinta.deshabilitado,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioCampo)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((estados) {
            if (estados.contains(WidgetState.hovered)) {
              return Colors.white.withOpacity(0.08);
            }
            if (estados.contains(WidgetState.pressed)) {
              return Colors.white.withOpacity(0.14);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Marca.c700,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: Tinta.bordeFuerte),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioCampo)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Marca.c600,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Marca.c600),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Tinta.superficie,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: Marca.c800),
        contentTextStyle: const TextStyle(
            fontSize: 14.5, color: Tinta.textoMedio, height: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Tinta.texto,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioCampo)),
        insetPadding: const EdgeInsets.all(16),
      ),
      dividerTheme:
          const DividerThemeData(color: Tinta.borde, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected) ? Marca.c700 : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: Marca.c600),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: Tinta.texto, borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Marca.c600,
        textColor: Tinta.texto,
      ),
    );
  }
}
