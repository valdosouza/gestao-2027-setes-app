import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/auth_bloc.dart';

/// Tela "Escolha o estabelecimento" (workflow do prompt, decisão 3):
/// o padrão NÃO pula a tela — apenas vem pré-selecionado (decisão 15:
/// gravado localmente no dispositivo).
class SelectInstitutionPage extends StatefulWidget {
  const SelectInstitutionPage({super.key, this.bloc});

  /// Optional bloc for tests; when null, uses `Modular.get<AuthBloc>()`.
  final AuthBloc? bloc;

  @override
  State<SelectInstitutionPage> createState() => _SelectInstitutionPageState();
}

class _SelectInstitutionPageState extends State<SelectInstitutionPage> {
  late final AuthBloc bloc;
  int? _selectedId;
  bool _setAsDefault = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc ?? Modular.get<AuthBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      bloc: bloc,
      listener: (context, state) {
        if (state is AuthAuthenticated) Modular.to.navigate('/home/');
      },
      builder: (context, state) {
        if (state is AuthLoading) {
          return const SetesScaffold(body: SetesCircularProgressIndicator());
        }
        if (state is! AuthNeedsSelection) {
          // Sessão de seleção perdida (refresh no navegador) → volta ao login
          return SetesScaffold(
            body: Center(
              child: SetesButton(
                label: 'auth.login'.tr(),
                onPressed: () => Modular.to.navigate('/login'),
              ),
            ),
          );
        }

        // Pré-seleciona o padrão local (decisão 15) na primeira montagem
        if (!_initialized) {
          _initialized = true;
          final options = state.session.institutions;
          _selectedId = options
                  .any((o) => o.institutionId == state.defaultInstitutionId)
              ? state.defaultInstitutionId
              : null;
        }

        final institutions = state.session.institutions;
        return SetesScaffold(
          appBarTitle: 'auth.chooseInstitution'.tr(),
          body: Center(
            child: SizedBox(
              width: 480,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: institutions.length,
                      itemBuilder: (context, index) {
                        final option = institutions[index];
                        return SetesListTile(
                          title: SetesText(option.name),
                          subtitle: option.profile != null ? SetesText(option.profile!) : null,
                          leading: const Icon(Icons.business_outlined),
                          selected: _selectedId == option.institutionId,
                          trailing: _selectedId == option.institutionId
                              ? const Icon(Icons.check_circle_outline)
                              : null,
                          onTap: () => setState(() => _selectedId = option.institutionId),
                        );
                      },
                    ),
                  ),
                  SetesCheckbox(
                    label: 'auth.setAsDefault'.tr(),
                    value: _setAsDefault,
                    onChanged: (v) => setState(() => _setAsDefault = v ?? false),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SetesButton(
                      label: 'auth.continue'.tr(),
                      onPressed: _selectedId == null
                          ? null
                          : () => bloc.add(AuthInstitutionSelected(
                                institutionId: _selectedId!,
                                setAsDefault: _setAsDefault,
                              )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
