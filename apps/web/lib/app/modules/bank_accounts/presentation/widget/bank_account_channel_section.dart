import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../data/datasource/bank_account_channel_datasource.dart';
import '../../domain/entity/bank_account_channel_entity.dart';

/// Seção AUTÔNOMA "Canal API" do form da conta bancária (Onda 2 — D-I3/D-I4;
/// mesmo padrão da Chave de Sincronização do Institution): carrega e salva
/// pelo datasource dedicado do sub-recurso e fala com a PONTE de feedback.
///
/// O que a tela mostra dos SEGREDOS é só presença + validade do certificado
/// (lida do arquivo pela API). O envio é WRITE-ONLY: os três campos são
/// colados e enviados; nada volta preenchido. O provider é derivado do banco
/// da conta — banco sem adaptador mostra o aviso e não oferece o form.
class BankAccountChannelSection extends StatefulWidget {
  const BankAccountChannelSection({
    required this.bankAccountId,
    required this.datasource,
    super.key,
  });

  final int bankAccountId;
  final BankAccountChannelDatasource datasource;

  @override
  State<BankAccountChannelSection> createState() => _BankAccountChannelSectionState();
}

class _BankAccountChannelSectionState extends State<BankAccountChannelSection> {
  BankAccountChannelView? _view;
  bool _loading = true;
  bool _busy = false;
  String _environment = 'S';
  String _active = 'S';
  final _clientId = TextEditingController();
  final _certificate = TextEditingController();
  final _privateKey = TextEditingController();
  final _clientSecret = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clientId.dispose();
    _certificate.dispose();
    _privateKey.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  void _apply(BankAccountChannelView view) {
    _view = view;
    final c = view.channel;
    if (c != null) {
      _environment = c.environment;
      _active = c.active;
      _clientId.text = c.clientId ?? '';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final view = await widget.datasource.get(widget.bankAccountId);
      if (mounted) setState(() => _apply(view));
    } on Failure catch (failure) {
      if (mounted) await showFailureFeedback(context, failure);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<BankAccountChannelView?> Function() action, String successKey) async {
    setState(() => _busy = true);
    try {
      final view = await action();
      if (!mounted) return;
      if (view != null) setState(() => _apply(view));
      await showSuccessFeedback(context, successKey);
    } on Failure catch (failure) {
      if (mounted) await showFailureFeedback(context, failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(
        () => widget.datasource.save(widget.bankAccountId,
            environment: _environment, clientId: _clientId.text, active: _active),
        'forms.bankAccount.channelSaved',
      );

  Future<void> _saveSecrets() async {
    if (_certificate.text.trim().isEmpty &&
        _privateKey.text.trim().isEmpty &&
        _clientSecret.text.trim().isEmpty) {
      await showValidationFeedback(context, 'forms.bankAccount.channelSecretsEmpty'.tr());
      return;
    }
    await _run(
      () async {
        final view = await widget.datasource.saveSecrets(widget.bankAccountId,
            certificatePem: _certificate.text, privateKeyPem: _privateKey.text,
            clientSecret: _clientSecret.text);
        // write-only: o que foi enviado sai da tela
        _certificate.clear();
        _privateKey.clear();
        _clientSecret.clear();
        return view;
      },
      'forms.bankAccount.channelSecretsSaved',
    );
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final r = await widget.datasource.test(widget.bankAccountId);
      if (!mounted) return;
      await showSuccessFeedback(context, 'forms.bankAccount.channelTestOk',
          args: [r.webhookUrl ?? 'forms.bankAccount.channelNoWebhook'.tr()]);
    } on Failure catch (failure) {
      if (mounted) await showFailureFeedback(context, failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyWebhook() async {
    final path = _view?.webhookPath;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) await showSuccessFeedback(context, 'forms.bankAccount.channelWebhookCopied');
  }

  Widget _row(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text, style: color == null ? null : TextStyle(color: color)),
      );

  Widget _secretsStatus(BuildContext context) {
    final s = _view?.secrets;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    String mark(bool ok) => ok ? 'forms.bankAccount.channelPresent'.tr() : 'forms.bankAccount.channelMissing'.tr();
    final info = s.certificateInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('forms.bankAccount.channelCertRow'.tr(args: [mark(s.certificate)]),
            color: s.certificate ? null : scheme.error),
        _row('forms.bankAccount.channelKeyRow'.tr(args: [mark(s.privateKey)]),
            color: s.privateKey ? null : scheme.error),
        _row('forms.bankAccount.channelSecretRow'.tr(args: [mark(s.clientSecret)]),
            color: s.clientSecret ? null : scheme.error),
        if (info != null)
          _row(
            info.expired
                ? 'forms.bankAccount.channelCertExpired'.tr(args: [info.notAfter.substring(0, 10)])
                : 'forms.bankAccount.channelCertValidUntil'
                    .tr(args: [info.notAfter.substring(0, 10), '${info.daysToExpire}']),
            color: info.expired || info.daysToExpire <= 30 ? scheme.error : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(16), child: SetesCircularProgressIndicator());
    }
    final view = _view;
    if (view == null) return const SizedBox.shrink();
    if (!view.adapterSupported) {
      return SetesCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText.title('forms.bankAccount.channelSection'.tr()),
            const SizedBox(height: 8),
            SetesText('forms.bankAccount.channelNoAdapter'.tr(args: [view.bankNumber])),
          ],
        ),
      );
    }
    return SetesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText.title('forms.bankAccount.channelSection'.tr()),
          const SizedBox(height: 4),
          SetesText('forms.bankAccount.channelHelp'.tr()),
          const SizedBox(height: 16),
          SetesDropdown<String>(
            label: 'forms.bankAccount.channelEnvironment'.tr(),
            value: _environment,
            items: const ['S', 'P'],
            itemLabel: (v) => v == 'P'
                ? 'forms.bankAccount.channelProduction'.tr()
                : 'forms.bankAccount.channelSandbox'.tr(),
            onChanged: (v) => setState(() => _environment = v ?? 'S'),
          ),
          const SizedBox(height: 16),
          SetesTextField(
            label: 'forms.bankAccount.channelClientId'.tr(),
            controller: _clientId,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active == 'S',
            onChanged: (v) => setState(() => _active = v ? 'S' : 'N'),
            title: SetesText('forms.bankAccount.channelActive'.tr()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SetesButton(
              label: 'forms.bankAccount.channelSave'.tr(),
              icon: Icons.save_outlined,
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
          if (view.channel != null) ...[
            const Divider(height: 32),
            SetesText.title('forms.bankAccount.channelSecrets'.tr()),
            const SizedBox(height: 4),
            SetesText('forms.bankAccount.channelSecretsHelp'.tr()),
            const SizedBox(height: 8),
            _secretsStatus(context),
            const SizedBox(height: 12),
            SetesTextField(
              label: 'forms.bankAccount.channelCertificate'.tr(),
              hint: '-----BEGIN CERTIFICATE-----',
              controller: _certificate,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SetesTextField(
              label: 'forms.bankAccount.channelPrivateKey'.tr(),
              hint: '-----BEGIN PRIVATE KEY-----',
              controller: _privateKey,
              maxLines: 3,
              obscureText: false,
            ),
            const SizedBox(height: 12),
            SetesTextField(
              label: 'forms.bankAccount.channelClientSecret'.tr(),
              controller: _clientSecret,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                SetesButton(
                  label: 'forms.bankAccount.channelSecretsSave'.tr(),
                  icon: Icons.lock_outline,
                  loading: _busy,
                  onPressed: _busy ? null : _saveSecrets,
                ),
                SetesButton(
                  label: 'forms.bankAccount.channelTest'.tr(),
                  icon: Icons.wifi_tethering,
                  kind: SetesButtonKind.secondary,
                  loading: _busy,
                  onPressed: _busy || !(view.secrets?.complete ?? false) ? null : _test,
                ),
              ],
            ),
            if (view.webhookPath != null) ...[
              const Divider(height: 32),
              SetesText.title('forms.bankAccount.channelWebhook'.tr()),
              const SizedBox(height: 4),
              SetesText('forms.bankAccount.channelWebhookHelp'.tr()),
              const SizedBox(height: 8),
              SetesTextField(
                label: 'forms.bankAccount.channelWebhookPath'.tr(),
                controller: TextEditingController(text: view.webhookPath),
                readOnly: true,
                suffixIcon: Icons.copy,
                onSuffixPressed: _copyWebhook,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
