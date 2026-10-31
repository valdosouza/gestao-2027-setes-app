import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../shared/http/api_client.dart';
import '../../../shared/storage/local_prefs.dart';
import '../../../theme/presentation/cubit/theme_cubit.dart';
import '../../domain/entity/session_user.dart';
import '../../domain/usecase/get_me_usecase.dart';

/// Item a mais no menu do usuário (ex.: idioma e tema no celular, onde a
/// barra não tem espaço para os ícones — onda D da densidade).
class UserBadgeEntry {
  const UserBadgeEntry({
    required this.label,
    required this.onSelected,
    this.icon,
    this.checked,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;

  /// Não nulo = item marcável (ex.: o idioma corrente).
  final bool? checked;
}

/// Identificação do usuário logado (GET /api/core/me) + menu com "Sair".
///
/// Logout ATIVO revoga o "Manter conectado" (pedido do Valdo): limpa o
/// token persistido E a flag keep_connected, zera o tema para o padrão
/// Setes e volta ao login.
class UserBadge extends StatefulWidget {
  const UserBadge({
    super.key,
    this.usecase,
    this.compact = false,
    this.entriesBuilder,
  });

  /// Optional usecase for tests; when null, uses `Modular.get<GetMeUsecase>()`.
  final GetMeUsecase? usecase;

  /// Só o ícone (barra do celular): o nome vai para o topo do menu.
  final bool compact;

  /// Itens a mais no menu, entre a identificação e o "Sair". Montados ao
  /// abrir o menu, com o contexto do PRÓPRIO badge — o do popup morre quando
  /// ele fecha, antes de o item ser executado.
  final List<UserBadgeEntry> Function(BuildContext context)? entriesBuilder;

  @override
  State<UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends State<UserBadge> {
  SessionUser? _user;
  List<UserBadgeEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    final usecase = widget.usecase ?? Modular.get<GetMeUsecase>();
    usecase().then((result) {
      if (!mounted) return;
      result.fold((_) {}, (user) => setState(() => _user = user));
    });
  }

  Future<void> _logout() async {
    final prefs = Modular.get<LocalPrefs>();
    Modular.get<ApiClient>().token = null;
    await prefs.setSessionToken(null);
    await prefs.setKeepConnected(false); // logout ativo revoga o "Manter conectado"
    Modular.get<ThemeCubit>().reset();   // volta ao tema padrão Setes no login
    Modular.to.navigate('/login');
  }

  void _onSelected(String value) {
    if (value == 'logout') {
      _logout();
      return;
    }
    final index = int.tryParse(value.replaceFirst('entry:', ''));
    if (index != null && index < _entries.length) _entries[index].onSelected();
  }

  /// Ícone + nome + seta. Nome: até 160 px na barra (largura livre); numa
  /// coluna (largura limitada — o pé do menu lateral) encolhe com reticências.
  Widget _full(String name) => LayoutBuilder(
        builder: (context, constraints) {
          final text = Text(name, overflow: TextOverflow.ellipsis);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined),
              const SizedBox(width: 6),
              if (constraints.hasBoundedWidth)
                Flexible(child: text)
              else
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: text),
              const Icon(Icons.arrow_drop_down),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final name = _user?.name ?? '';
    final subtitle = [
      if (_user?.institutionName != null) _user!.institutionName!,
      if (_user?.role.isNotEmpty ?? false) _user!.role,
    ].join(' · ');

    return PopupMenuButton<String>(
      tooltip: name.isEmpty ? 'home.logout'.tr() : name,
      onSelected: _onSelected,
      itemBuilder: (popupContext) {
        _entries = widget.entriesBuilder?.call(context) ?? const [];
        return [
          if (widget.compact && name.isNotEmpty)
            PopupMenuItem<String>(
              enabled: false,
              child: Text(name, style: Theme.of(popupContext).textTheme.titleSmall),
            ),
          if (subtitle.isNotEmpty)
            PopupMenuItem<String>(
              enabled: false,
              child: Text(subtitle, style: Theme.of(popupContext).textTheme.bodySmall),
            ),
          if (_entries.isNotEmpty) const PopupMenuDivider(),
          for (final (index, entry) in _entries.indexed)
            if (entry.checked != null)
              CheckedPopupMenuItem<String>(
                value: 'entry:$index',
                checked: entry.checked!,
                child: Text(entry.label),
              )
            else
              PopupMenuItem<String>(
                value: 'entry:$index',
                child: Row(
                  children: [
                    Icon(entry.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(entry.label),
                  ],
                ),
              ),
          if (_entries.isNotEmpty) const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, size: 18),
                const SizedBox(width: 8),
                Text('home.logout'.tr()),
              ],
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: widget.compact
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.account_circle_outlined), Icon(Icons.arrow_drop_down)],
              )
            : _full(name),
      ),
    );
  }
}
