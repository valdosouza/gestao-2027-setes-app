import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../setes_theme.dart';
import '../cubit/theme_cubit.dart';
import '../widget/institution_logo.dart';

/// Personalização da identidade visual pelo cliente (decisões 16 e 27):
/// escolhe primária/secundária numa paleta; aplica na hora e persiste
/// em tb_institution_theme via PUT /api/core/theme.
///
/// Feedback (Framework de Mensagens, Onda B): página de PACKAGE não pode
/// importar a ponte do app (`app/shared/feedback/`) — usa direto o
/// apresentador do design system (peça E: showSetesMessage/
/// showSetesDecision), que é exatamente o que a ponte envelopa; os textos
/// chegam prontos (i18n aqui). Nada de ScaffoldMessenger/AlertDialog.
class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key, this.cubit});

  /// Optional cubit for tests; when null, uses `Modular.get<ThemeCubit>()`.
  final ThemeCubit? cubit;

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late final ThemeCubit cubit;

  static const List<Color> _palette = [
    SetesColors.blue, SetesColors.navy, SetesColors.green, SetesColors.greenDark,
    Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF00838F),
    Color(0xFF00695C), Color(0xFF558B2F), Color(0xFFF9A825),
    Color(0xFFEF6C00), Color(0xFFD84315), Color(0xFFC62828),
    Color(0xFFAD1457), Color(0xFF6A1B9A), Color(0xFF4527A0),
    Color(0xFF37474F),
  ];

  String? _primaryHex;
  String? _secondaryHex;

  @override
  void initState() {
    super.initState();
    cubit = widget.cubit ?? Modular.get<ThemeCubit>();
    _primaryHex = cubit.state.primaryHex;
    _secondaryHex = cubit.state.secondaryHex;
  }

  /// Upload da logomarca (decisão 16): vira base64 → PUT /api/core/theme →
  /// storage da API. Só afeta a HOME (login = sempre logo Setes).
  Future<void> _pickLogo() async {
    const typeGroup = XTypeGroup(label: 'Imagens', extensions: ['png', 'jpg', 'jpeg', 'webp']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 1_400_000) {
      // Pendência corrigível pelo usuário = dialog de validação (R1/R3).
      if (mounted) {
        await showSetesMessage(
          context,
          kind: SetesMessageKind.validation,
          title: 'feedback.validationTitle'.tr(),
          message: 'theme.logoTooBig'.tr(),
          okLabel: 'register.ok'.tr(),
        );
      }
      return;
    }
    final ext = file.name.split('.').last.toLowerCase();
    final mime = ext == 'jpg' ? 'jpeg' : ext;
    await cubit.saveLogo('data:image/$mime;base64,${base64Encode(bytes)}');
  }

  /// Voltar ao padrão Setes é uma DECISÃO (R4): Sim = repõe as cores padrão
  /// na paleta (persistem no "Aplicar e salvar"); Cancelar = nada.
  Future<void> _confirmResetToDefault() async {
    final decision = await showSetesDecision(
      context,
      message: 'theme.resetConfirm'.tr(),
      yesLabel: 'register.yes'.tr(),
      cancelLabel: 'register.cancel'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    setState(() {
      _primaryHex = SetesTheme.colorToHex(SetesColors.blue);
      _secondaryHex = SetesTheme.colorToHex(SetesColors.navy);
    });
  }

  Widget _swatchGrid(String? selectedHex, ValueChanged<String> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final color in _palette)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onPick(SetesTheme.colorToHex(color)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 3,
                    color: selectedHex == SetesTheme.colorToHex(color)
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) => SetesScaffold(
        appBarTitle: 'theme.title'.tr(),
        body: Center(
          child: SizedBox(
            width: 520,
            child: ListView(
              padding: const EdgeInsets.all(SetesMetrics.padding),
              children: [
                SetesText.title('theme.primary'.tr()),
                const SizedBox(height: 8),
                _swatchGrid(_primaryHex, (hex) => setState(() => _primaryHex = hex)),
                const SizedBox(height: 24),
                SetesText.title('theme.secondary'.tr()),
                const SizedBox(height: 8),
                _swatchGrid(_secondaryHex, (hex) => setState(() => _secondaryHex = hex)),
                const SizedBox(height: 24),
                SetesText.title('theme.logo'.tr()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InstitutionLogo(height: 48, cubit: cubit),
                    const SizedBox(width: 16),
                    SetesButton(
                      label: 'theme.uploadLogo'.tr(),
                      kind: SetesButtonKind.secondary,
                      icon: Icons.upload_outlined,
                      onPressed: _pickLogo,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SetesButton(
                  label: 'theme.apply'.tr(),
                  onPressed: () async {
                    await cubit.save(primaryHex: _primaryHex, secondaryHex: _secondaryHex);
                    if (context.mounted) Modular.to.pop();
                  },
                ),
                const SizedBox(height: 8),
                SetesButton(
                  label: 'theme.resetToDefault'.tr(),
                  kind: SetesButtonKind.secondary,
                  onPressed: _confirmResetToDefault,
                ),
              ],
            ),
          ),
        ),
      );
}
