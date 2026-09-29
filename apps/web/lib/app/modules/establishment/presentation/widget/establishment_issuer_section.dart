import 'dart:convert';

import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../data/datasource/establishment_issuer_datasource.dart';
import '../../domain/entity/establishment_issuer_entity.dart';

/// Arquivo .pfx escolhido pelo usuário (nome + bytes) — o conteúdo vira
/// base64 no PUT e NUNCA fica na tela depois do envio.
class PickedPfx {
  const PickedPfx({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Abre o seletor de arquivo do sistema filtrando .pfx/.p12 (file_selector —
/// web e desktop). Null = usuário cancelou.
Future<PickedPfx?> pickPfxFile() async {
  final typeGroup = XTypeGroup(
    label: 'forms.establishment.issuerPfxFiles'.tr(),
    extensions: const ['pfx', 'p12'],
    mimeTypes: const ['application/x-pkcs12'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return null;
  return PickedPfx(name: file.name, bytes: await file.readAsBytes());
}

/// Aba AUTÔNOMA "Emissor fiscal" do Meu Estabelecimento (Onda 3 — NFS-e
/// pelo Padrão Nacional; prompt_onda_nfe_sefaz.md §9.3). Mesmo padrão da
/// seção Canal API da conta bancária: carrega e salva pelo datasource
/// dedicado do sub-recurso e fala SÓ com a PONTE de feedback — o bloc do
/// form não entra (habilitação e certificado têm ciclo próprio).
///
/// Três coisas na tela:
/// 1. **Certificado digital (A1)** ÚNICO do estabelecimento (D-N31, Valdo
///    2026-09-28 — o mesmo par serve a homologação e a produção): presença
///    do par, validade e CNPJ lidos do arquivo; upload WRITE-ONLY (.pfx +
///    senha — a senha abre o arquivo uma vez na API e some da tela).
/// 2. **Documentos habilitados** por MODELO (SE/55): ambiente de emissão +
///    série; o badge "Habilitado" é DERIVADO pela API (linha + certificado
///    válido).
/// 3. Nada de preferências (elas ficam na engrenagem da interface billing).
class EstablishmentIssuerSection extends StatefulWidget {
  const EstablishmentIssuerSection({
    required this.datasource,
    this.pickPfx = pickPfxFile,
    super.key,
  });

  final EstablishmentIssuerDatasource datasource;

  /// Seletor de arquivo — injetável nos testes (default: diálogo do sistema).
  final Future<PickedPfx?> Function() pickPfx;

  @override
  State<EstablishmentIssuerSection> createState() =>
      _EstablishmentIssuerSectionState();
}

class _EstablishmentIssuerSectionState
    extends State<EstablishmentIssuerSection> {
  EstablishmentIssuerView? _view;
  bool _loading = true;
  bool _busy = false;

  /// Senha do .pfx — nunca persistida, limpa após o envio.
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Habilitação por modelo: ambiente escolhido + série digitada.
  final _environment = {for (final m in kIssuerModels) m: 'H'};
  final _serie = {
    for (final m in kIssuerModels) m: TextEditingController(),
  };
  final _serieFocus = {for (final m in kIssuerModels) m: FocusNode()};

  /// Recria os Dropdowns de ambiente quando a visão do servidor chega
  /// (FormField retém a seleção internamente).
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_password, ..._serie.values]) {
      c.dispose();
    }
    for (final f in [_passwordFocus, ..._serieFocus.values]) {
      f.dispose();
    }
    super.dispose();
  }

  void _apply(EstablishmentIssuerView view) {
    _view = view;
    _epoch++;
    for (final model in kIssuerModels) {
      final issuer = view.issuerFor(model);
      _environment[model] = issuer?.environment ?? 'H';
      _serie[model]!.text = issuer?.serie ?? '';
    }
  }

  /// Carrega a visão. O spinner some ANTES do dialog de falha (a tela nunca
  /// fica "ocupada" atrás de um dialog que espera o usuário).
  Future<void> _load() async {
    setState(() => _loading = true);
    EstablishmentIssuerView? view;
    Failure? failure;
    try {
      view = await widget.datasource.get();
    } on Failure catch (f) {
      failure = f;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (view != null) _apply(view);
    });
    if (failure != null) await showFailureFeedback(context, failure);
  }

  /// Executa uma ação do sub-recurso: aplica a visão devolvida (null =
  /// recarrega do GET — caso dos DELETEs e das rotas do certificado, que
  /// devolvem só a situação do cofre e mudam os `enabled` dos modelos),
  /// sucesso pela ponte, falha pela ponte — sempre com [_busy] já liberado
  /// quando o feedback aparece.
  Future<void> _run(Future<EstablishmentIssuerView?> Function() action,
      String successKey) async {
    setState(() => _busy = true);
    EstablishmentIssuerView? view;
    Failure? failure;
    try {
      view = await action();
    } on Failure catch (f) {
      failure = f;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (view != null) _apply(view);
    });
    if (failure != null) return showFailureFeedback(context, failure);
    if (view == null) {
      await _load(); // resposta sem a visão inteira → GET
      if (!mounted) return;
    }
    await showSuccessFeedback(context, successKey);
  }

  // ------------------------------------------------------------------
  // Certificado do estabelecimento (um só — D-N31)
  // ------------------------------------------------------------------

  Future<void> _uploadCertificate() async {
    final password = _password.text;
    if (password.isEmpty) {
      // Pendência corrigível → dialog da ponte + foco no campo (R3).
      await showValidationFeedback(
          context, 'forms.establishment.issuerCertPasswordRequired'.tr());
      _passwordFocus.requestFocus();
      return;
    }
    final picked = await widget.pickPfx();
    if (picked == null || !mounted) return;
    await _run(
      () async {
        await widget.datasource.saveCertificate(
            pfxBase64: base64Encode(picked.bytes), password: password);
        // write-only: a senha sai da tela assim que o arquivo foi aberto
        _password.clear();
        return null; // só o status volta → recarrega a visão (enabled)
      },
      'forms.establishment.issuerCertSaved',
    );
  }

  Future<void> _removeCertificate() async {
    final decision = await askDecision(
      context,
      message: 'forms.establishment.issuerCertRemoveConfirm'.tr(),
      yesLabel: 'forms.establishment.issuerRemove'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    await _run(
      () async {
        await widget.datasource.removeCertificate();
        return null; // só o status volta → recarrega a visão (enabled)
      },
      'forms.establishment.issuerCertRemoved',
    );
  }

  // ------------------------------------------------------------------
  // Habilitação por modelo
  // ------------------------------------------------------------------

  static final _serieRegex = RegExp(r'^\d{1,5}$');

  Future<void> _saveIssuer(String model) async {
    final serie = _serie[model]!.text.trim();
    if (!_serieRegex.hasMatch(serie)) {
      await showValidationFeedback(
          context, 'forms.establishment.issuerSerieInvalid'.tr());
      _serieFocus[model]!.requestFocus();
      return;
    }
    await _run(
      () => widget.datasource.saveIssuer(model,
          environment: _environment[model]!, serie: serie),
      'forms.establishment.issuerSaved',
    );
  }

  Future<void> _removeIssuer(String model) async {
    final decision = await askDecision(
      context,
      message: 'forms.establishment.issuerRemoveConfirm'
          .tr(args: [_modelLabel(model)]),
      yesLabel: 'forms.establishment.issuerRemove'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    await _run(
      () async {
        await widget.datasource.removeIssuer(model);
        return null; // DELETE devolve só {ok} → recarrega a visão
      },
      'forms.establishment.issuerRemoved',
    );
  }

  // ------------------------------------------------------------------
  // Rótulos
  // ------------------------------------------------------------------

  String _envLabel(String env) => env == 'P'
      ? 'forms.establishment.issuerEnvP'.tr()
      : 'forms.establishment.issuerEnvH'.tr();

  String _modelLabel(String model) => switch (model) {
        'SE' => 'forms.establishment.issuerModelSE'.tr(),
        '55' => 'forms.establishment.issuerModel55'.tr(),
        _ => model,
      };

  String _presence(bool ok) => ok
      ? 'forms.establishment.issuerPresent'.tr()
      : 'forms.establishment.issuerMissing'.tr();

  // ------------------------------------------------------------------
  // Blocos
  // ------------------------------------------------------------------

  Widget _row(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text,
            style: color == null ? null : TextStyle(color: color)),
      );

  /// Linha de validade: vencido · ainda não vigente · válido até (com
  /// alerta de cor a 30 dias do fim).
  Widget _validityRow(BuildContext context, IssuerCertificateInfo info) {
    final scheme = Theme.of(context).colorScheme;
    if (info.expired) {
      return _row(
          'forms.establishment.issuerCertExpired'.tr(args: [info.notAfterDate]),
          color: scheme.error);
    }
    if (info.notYetValid) {
      return _row(
          'forms.establishment.issuerCertNotYetValid'
              .tr(args: [info.notBeforeDate]),
          color: scheme.error);
    }
    return _row(
      'forms.establishment.issuerCertValidUntil'
          .tr(args: [info.notAfterDate, '${info.daysToExpire}']),
      color: info.daysToExpire <= 30 ? scheme.error : null,
    );
  }

  Widget _certificateBlock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _view!.certificate;
    final info = status.certificateInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('forms.establishment.issuerCertRow'
                .tr(args: [_presence(status.certificate)]),
            color: status.certificate ? null : scheme.error),
        _row('forms.establishment.issuerKeyRow'
                .tr(args: [_presence(status.privateKey)]),
            color: status.privateKey ? null : scheme.error),
        if (info != null) ...[
          _validityRow(context, info),
          if (info.cnpj != null && info.cnpj!.isNotEmpty)
            _row('forms.establishment.issuerCertCnpj'.tr(args: [info.cnpj!])),
        ],
        const SizedBox(height: 8),
        SetesTextField(
          label: 'forms.establishment.issuerCertPassword'.tr(),
          controller: _password,
          focusNode: _passwordFocus,
          obscureText: true,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            SetesButton(
              label: 'forms.establishment.issuerCertUpload'.tr(),
              icon: Icons.upload_file,
              loading: _busy,
              onPressed: _busy ? null : _uploadCertificate,
            ),
            SetesButton(
              label: 'forms.establishment.issuerRemove'.tr(),
              kind: SetesButtonKind.secondary,
              loading: _busy,
              onPressed:
                  _busy || !status.present ? null : _removeCertificate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, IssuerBadge badge) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (badge) {
      IssuerBadge.enabled => (
          'forms.establishment.issuerBadgeEnabled'.tr(),
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      IssuerBadge.noCertificate => (
          'forms.establishment.issuerBadgeNoCertificate'.tr(),
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      IssuerBadge.notConfigured => (
          'forms.establishment.issuerBadgeNotConfigured'.tr(),
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SetesText(label,
          style: TextStyle(color: foreground, fontSize: 12)),
    );
  }

  Widget _issuerBlock(BuildContext context, String model) {
    final view = _view!;
    final issuer = view.issuerFor(model);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SetesText(_modelLabel(model),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            _badge(context, view.badgeFor(model)),
          ],
        ),
        const SizedBox(height: 12),
        SetesDropdown<String>(
          key: ValueKey('issuerEnv$model$_epoch'),
          label: 'forms.establishment.issuerEnvironment'.tr(),
          value: _environment[model],
          items: kIssuerEnvironments,
          itemLabel: _envLabel,
          onChanged: (v) => setState(() => _environment[model] = v ?? 'H'),
        ),
        const SizedBox(height: 12),
        SetesTextField(
          label: 'forms.establishment.issuerSerie'.tr(),
          controller: _serie[model],
          focusNode: _serieFocus[model],
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            SetesButton(
              label: 'register.save'.tr(),
              icon: Icons.save_outlined,
              loading: _busy,
              onPressed: _busy ? null : () => _saveIssuer(model),
            ),
            SetesButton(
              label: 'forms.establishment.issuerRemove'.tr(),
              kind: SetesButtonKind.secondary,
              loading: _busy,
              onPressed:
                  _busy || issuer == null ? null : () => _removeIssuer(model),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: SetesCircularProgressIndicator());
    }
    if (_view == null) {
      // GET falhou (a ponte já mostrou o motivo) — oferece tentar de novo.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SetesButton(
            label: 'register.retry'.tr(),
            icon: Icons.refresh,
            onPressed: _load,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText.title('forms.establishment.issuerCertSection'.tr()),
              const SizedBox(height: 4),
              SetesText('forms.establishment.issuerCertHelp'.tr()),
              const SizedBox(height: 16),
              _certificateBlock(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText.title('forms.establishment.issuerDocsSection'.tr()),
              const SizedBox(height: 4),
              SetesText('forms.establishment.issuerDocsHelp'.tr()),
              const SizedBox(height: 16),
              for (final (i, model) in kIssuerModels.indexed) ...[
                if (i > 0) const Divider(height: 32),
                _issuerBlock(context, model),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
