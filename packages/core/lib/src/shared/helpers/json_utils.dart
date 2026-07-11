/// Conversores tolerantes para JSON de APIs.
///
/// Drivers MySQL podem serializar DECIMAL como string ("12.00") — aceitar
/// num E string evita quebrar um fromJson inteiro por um campo numérico
/// (caso real: listas de Estado/Cidade sumiam, 2026-07-11).
library;

double? jsonDouble(dynamic v) => switch (v) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(',', '.')),
      _ => null,
    };

int? jsonInt(dynamic v) => switch (v) {
      null => null,
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
