import 'package:equatable/equatable.dart';

/// Tema da institution (tb_institution_theme — decisão 16).
class InstitutionTheme extends Equatable {
  const InstitutionTheme({this.primaryColor, this.secondaryColor, this.logoBase64});

  /// #RRGGBB
  final String? primaryColor;
  final String? secondaryColor;

  /// data URI pronto para a UI (logo servida pela API)
  final String? logoBase64;

  @override
  List<Object?> get props => [primaryColor, secondaryColor, logoBase64];
}
