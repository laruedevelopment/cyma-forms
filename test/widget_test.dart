import 'package:flutter_test/flutter_test.dart';
import 'package:forms_app/services/hours_utils.dart';

void main() {
  group('calcularHorasEsperadas', () {
    test('una semana de 5 días son 42 horas', () {
      expect(calcularHorasEsperadas(5), 42);
      expect(calcularHorasEsperadas('5'), 42);
    });

    test('menos días descuentan 9 h por día', () {
      expect(calcularHorasEsperadas(4), 33);
      expect(calcularHorasEsperadas(1), 6);
    });

    test('nunca es negativo', () {
      expect(calcularHorasEsperadas(0), 0);
    });

    test('valores vacíos o no numéricos dan 0', () {
      expect(calcularHorasEsperadas(''), 0);
      expect(calcularHorasEsperadas(null), 0);
      expect(calcularHorasEsperadas('abc'), 0);
    });
  });

  group('horasEsperadasDe', () {
    test('usa las horas guardadas si existen', () {
      expect(horasEsperadasDe({'hours': '40', 'days': '5'}), '40');
    });

    test('calcula desde los días si no hay horas guardadas', () {
      expect(horasEsperadasDe({'days': '5'}), '42');
      expect(horasEsperadasDe({'hours': '', 'days': '5'}), '42');
    });

    test('sin datos da 0', () {
      expect(horasEsperadasDe(null), '0');
    });
  });
}
