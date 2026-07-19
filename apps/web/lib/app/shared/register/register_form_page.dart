import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../feedback/feedback.dart';

/// Descritor de campo (decisão 20): parametriza o formulário genérico.
///
/// Fase 2 campos configuráveis: [validator] pode devolver CHAVE i18n
/// (setes_validators) — a fábrica traduz com .tr(); [mask] aplica
/// SetesMaskFormatter na digitação e o valor vai SEM máscara no onSave
/// (decisão 19). Use applyFieldConfig (field_config_merge.dart) para
/// mesclar a config do cliente (caption/required/mask — decisão 7).
class RegisterField {
  const RegisterField({
    required this.name,
    required this.label,
    this.obscure = false,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
    this.mask,
  })  : isLookup = false,
        display = '',
        onPick = null,
        validatorMessage = null;

  /// Campo de FK com lista de apoio (skill campo-lookup-fk.md): renderiza
  /// [SetesLookupField] mostrando [display] (readOnly, fora do Tab);
  /// Icons.search chama [onPick], que abre showSetesLookup e guarda o id
  /// escolhido no ESTADO DA PÁGINA — o id nunca entra nos values do onSave.
  const RegisterField.lookup({
    required this.name,
    required this.label,
    required this.display,
    required this.onPick,
    this.validatorMessage,
  })  : isLookup = true,
        obscure = false,
        readOnly = true,
        keyboardType = null,
        validator = null,
        mask = null;

  final String name;
  final String label;
  final bool obscure;

  /// Campo exibido mas não editável (ex.: código imutável na edição).
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  /// Máscara de digitação `#`/`A` (decisão 16). O valor salvo vai SEM
  /// máscara (decisão 19 — a fábrica aplica unmask no onSave).
  final String? mask;

  /// true = campo de FK (constructor [RegisterField.lookup]).
  final bool isLookup;

  /// Descrição atual do registro relacionado ('' se nada escolhido).
  final String display;

  /// Abre a lista de apoio (a página chama showSetesLookup e faz setState).
  final VoidCallback? onPick;

  /// Mensagem exibida pelo Form.validate() quando nada foi escolhido.
  final String? validatorMessage;
}

/// Aba extra do formulário (ex.: "Permissões" no cadastro de Usuário —
/// pedido do Valdo 2026-07-12). O conteúdo é responsabilidade da página
/// (rolagem própria); o estado deve viver na página/seções autônomas.
class RegisterTab {
  const RegisterTab({required this.label, required this.child});

  final String label;
  final Widget child;
}

/// Fábrica de cadastros (decisão 20) — formulário no contrato visual do
/// customer_register (skill criar-formulario-cadastro.md) via [SetesFormShell].
///
/// ARQUITETURA_MODULOS.md: a fábrica é APRESENTAÇÃO PURA — não executa
/// operações. [onSave]/[onDelete] apenas DISPARAM eventos no bloc do módulo;
/// sucesso/erro passam pela PONTE de feedback no BlocListener da página
/// (showSuccessFeedback/showFailureFeedback — Framework de Mensagens; erro
/// com fields[] ancora no campo via [RegisterFormPageState.showServerFieldError]).
/// O flag [saving] vem do estado do bloc e desabilita as ações.
///
/// Com [extraTabs], o form vira TabBar/TabBarView: os campos ficam na aba
/// principal (mantida VIVA via keep-alive — o salvar valida o Form mesmo
/// com outra aba aberta) e cada RegisterTab vira uma aba própria.
class RegisterFormPage extends StatefulWidget {
  const RegisterFormPage({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.onCancel,
    this.initialValues = const {},
    this.canSave = true,
    this.onDelete,
    this.canDelete = false,
    this.saving = false,
    this.extraChildren = const <Widget>[],
    this.extraTabs = const <RegisterTab>[],
    this.mainTabLabel,
    super.key,
  });

  final String title;
  final List<RegisterField> fields;
  final Map<String, String> initialValues;

  /// Dispara o evento de salvar no bloc com os values validados.
  final void Function(Map<String, String> values) onSave;
  final VoidCallback onCancel;

  /// Privilégios 'insert'/'update' do usuário (decisão 21).
  final bool canSave;

  /// Dispara o evento de excluir no bloc (a confirmação acontece AQUI,
  /// antes do disparo — exclusão sempre LÓGICA, decisão 4).
  final VoidCallback? onDelete;
  final bool canDelete;

  /// Estado do bloc: operação em andamento desabilita as ações.
  final bool saving;

  /// Widgets extras renderizados APÓS os campos, dentro do Form/ListView —
  /// seções que a fábrica não parametriza (ex.: grupo de checkboxes de
  /// privilégios na tela de Interfaces). O estado desses widgets vive na
  /// PÁGINA do módulo (como o id do lookup) — nunca nos values do onSave.
  final List<Widget> extraChildren;

  /// Abas ALÉM da principal (campos + extraChildren). Vazio = layout de
  /// aba única (comportamento original, sem TabBar).
  final List<RegisterTab> extraTabs;

  /// Rótulo da aba principal quando há [extraTabs] (default register.tabMain).
  final String? mainTabLabel;

  @override
  State<RegisterFormPage> createState() => RegisterFormPageState();
}

/// Estado PÚBLICO da fábrica: a página do módulo segura um
/// `GlobalKey<RegisterFormPageState>` para ancorar o fields[] do servidor
/// no campo ([showServerFieldError]) — Framework de Mensagens, Onda A.
class RegisterFormPageState extends State<RegisterFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  /// Foco programático por campo editável (R3: após o OK do dialog de
  /// pendência, o foco volta para o campo pendente).
  late final Map<String, FocusNode> _focusNodes;

  /// Key do FormField por campo: valida/marca SÓ o campo pendente (R3 —
  /// nada de Form.validate() pintando o formulário inteiro de vermelho).
  late final Map<String, GlobalKey<FormFieldState<String>>> _fieldKeys;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        if (!field.isLookup) // lookup: o id fica no estado da página
          field.name: TextEditingController(
              text: widget.initialValues[field.name] ?? ''),
    };
    _focusNodes = {
      for (final field in widget.fields)
        if (!field.isLookup) field.name: FocusNode(),
    };
    _fieldKeys = {
      for (final field in widget.fields)
        if (!field.isLookup) field.name: GlobalKey<FormFieldState<String>>(),
    };
  }

  /// R3 — UMA pendência por vez: percorre os campos NA ORDEM declarada,
  /// roda o validator no valor atual e, na PRIMEIRA mensagem, mostra o
  /// dialog (ponte) → OK → foco no campo, marcando SÓ ele inline. O save
  /// aborta; corrigiu, o próximo salvar mostra a próxima pendência.
  Future<void> _save() async {
    for (final field in widget.fields) {
      if (field.isLookup) {
        // FK sem escolha: o dialog carrega a validatorMessage (específica,
        // já traduzida). Campo readOnly/fora do Tab — sem foco/marca inline.
        if (field.validatorMessage != null && field.display.isEmpty) {
          await showValidationFeedback(context, field.validatorMessage!);
          return;
        }
        continue;
      }
      final message = field.validator?.call(_controllers[field.name]!.text);
      if (message != null) {
        // setes_validators devolve chave i18n (.tr() em texto já traduzido
        // devolve o próprio texto).
        await showValidationFeedback(context, message.tr());
        if (!mounted) return;
        _fieldKeys[field.name]?.currentState?.validate(); // marca SÓ ele
        _focusNodes[field.name]?.requestFocus();
        return;
      }
    }

    // Decisão 19: campo mascarado grava só os dígitos/caracteres.
    final maskByName = {
      for (final field in widget.fields)
        if (!field.isLookup && field.mask != null) field.name: field.mask,
    };
    widget.onSave({
      for (final entry in _controllers.entries)
        entry.key: maskByName.containsKey(entry.key)
            ? unmask(entry.value.text.trim())
            : entry.value.text.trim(),
    });
  }

  /// Ancora o erro de campo do SERVIDOR (`fields[]` do envelope 400/409) no
  /// formulário: dialog com a message do 1º campo apontado → OK → foco nele.
  /// Sem correspondência (ou sem fields[]) → feedback genérico da ponte.
  /// A página chama no listener do bloc via GlobalKey da fábrica.
  Future<void> showServerFieldError(Failure failure) async {
    if (failure.fields.isEmpty) return showFailureFeedback(context, failure);

    final serverField = failure.fields.first;
    final known = widget.fields.any((f) => f.name == serverField.field);
    if (!known) return showFailureFeedback(context, failure);

    // Regra do servidor (o validator local não a conhece): dialog + foco,
    // sem validate() inline — a marca vermelha ficaria mentirosa.
    await showValidationFeedback(context, serverField.message.tr());
    if (!mounted) return;
    _focusNodes[serverField.field]?.requestFocus();
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada. Sem ação alternativa → sem botão Não.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação (skill, item 8): Tab segue a ordem declarada dos campos e
    // SÓ os editáveis (readOnly e lookup ficam fora); foco inicial no
    // primeiro editável; Enter avança (next) e finaliza no último (done).
    final editableIndexes = [
      for (final (index, field) in widget.fields.indexed)
        if (!field.isLookup && !field.readOnly) index,
    ];
    final firstEditable = editableIndexes.isEmpty ? -1 : editableIndexes.first;
    final lastEditable = editableIndexes.isEmpty ? -1 : editableIndexes.last;

    final formContent = Form(
      key: _formKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (index, field) in widget.fields.indexed) ...[
              if (field.isLookup)
                // FK: readOnly e fora do Tab (SetesLookupField já exclui).
                SetesLookupField(
                  label: field.label,
                  display: field.display,
                  onSearch: field.onPick ?? () {},
                  validatorMessage: field.validatorMessage,
                )
              else
                FocusTraversalOrder(
                  order: NumericFocusOrder(index.toDouble()),
                  child: SetesTextField(
                    label: field.label,
                    controller: _controllers[field.name],
                    focusNode: _focusNodes[field.name],
                    fieldKey: _fieldKeys[field.name],
                    obscureText: field.obscure,
                    readOnly: field.readOnly,
                    autofocus: index == firstEditable,
                    keyboardType: field.keyboardType,
                    textInputAction: index == lastEditable
                        ? TextInputAction.done
                        : TextInputAction.next,
                    // Valida e traduz: setes_validators devolve chave i18n
                    // (.tr() em texto já traduzido devolve o próprio texto).
                    validator: field.validator == null
                        ? null
                        : (value) => field.validator!(value)?.tr(),
                    inputFormatters: field.mask == null
                        ? null
                        : [SetesMaskFormatter(field.mask!)],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            ...widget.extraChildren,
          ],
        ),
      ),
    );

    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onCancel,
      onSave: widget.canSave ? _save : null,
      onDelete:
          widget.canDelete && widget.onDelete != null ? _confirmDelete : null,
      child: widget.extraTabs.isEmpty
          ? formContent
          : DefaultTabController(
              length: 1 + widget.extraTabs.length,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: widget.mainTabLabel ?? 'register.tabMain'.tr()),
                      for (final tab in widget.extraTabs) Tab(text: tab.label),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Keep-alive: o Form continua montado (e validável
                        // pelo check do shell) com outra aba aberta.
                        _KeepAlive(child: formContent),
                        ...widget.extraTabs.map((tab) => tab.child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Mantém a aba principal viva no TabBarView (AutomaticKeepAlive).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
