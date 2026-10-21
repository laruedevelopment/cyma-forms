/// Horas esperadas de una encuesta semanal: 9 h por día hábil menos 3 h
/// (5 días → 42 h semanales).
const int horasPorDia = 9;
const int horasDescuentoSemana = 3;

/// Calcula las horas esperadas a partir de los días hábiles.
int calcularHorasEsperadas(Object? dias) {
  final d = int.tryParse(dias?.toString() ?? '') ?? 0;
  final horas = d * horasPorDia - horasDescuentoSemana;
  return horas < 0 ? 0 : horas;
}

/// Horas esperadas de una encuesta: usa el valor guardado (`hours`) y, si no
/// existe, lo calcula desde los días (`days`).
String horasEsperadasDe(Map<String, dynamic>? data) {
  final guardadas = data?['hours']?.toString() ?? '';
  if (guardadas.isNotEmpty) return guardadas;
  return calcularHorasEsperadas(data?['days']).toString();
}
