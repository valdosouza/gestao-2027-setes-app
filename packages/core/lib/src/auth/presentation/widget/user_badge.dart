import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../shared/http/api_client.dart';
import '../../../shared/storage/local_prefs.dart';
import '../../../theme/presentation/cubit/theme_cubit.dart';
import '../../domain/entity/session_user.dart';
import '../../domain/usecase/get_me_usecase.dart';

/// Identificação do usuário logado (GET /api/core/me) + menu com "Sair".
///
/// Logout ATIVO revoga o "Manter conectado" (pedido do Valdo): limpa o
/// token persistido E a flag keep_connected, zera o tema para o padrão
/// Setes e volta ao login.
class UserBadge extends StatefulWidget {
  const UserBadge({super.key, this.usecase});

  /// Optional usecase for tests; when null, uses `Modular.get<GetMeUsecase>()`.
  final GetMeUsecase? usecase;

  @override
  State<UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends State<UserBadge> {
  SessionUser? _user;

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

  @override
  Widget build(BuildContext context) {
    final name = _user?.name ?? '';
    final subtitle = [
      if (_user?.institutionName != null) _user!.institutionName!,
      if (_user?.role.isNotEmpty ?? false) _user!.role,
    ].join(' · ');

    return PopupMenuButton<String>(
      tooltip: name.isEmpty ? 'home.logout'.tr() : name,
      onSelected: (value) {
        if (value == 'logout') _logout();
      },
      itemBuilder: (context) => [
        if (subtitle.isNotEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
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
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
