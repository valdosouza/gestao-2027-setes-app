import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/institution_interfaces/institution_interfaces_tab.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../data/datasource/institution_interfaces_datasource.dart';
import '../../domain/entity/client_institution_entity.dart';
import '../bloc/institution_interfaces_bloc.dart';

/// Tela "Interfaces dos clientes" (D-PV11, Valdo 2026-10-18 —
/// `prompt_privilegios_interfaces.md` §11): lista de estabelecimentos →
/// quais telas cada um tem. Do grupo Super, delegável pelo Super a usuário
/// da Setes (a API confere a liberação; sem ALTERAR a aba fica só leitura).
class InstitutionInterfacesPage extends StatefulWidget {
  const InstitutionInterfacesPage({required this.title, super.key});

  final String title;

  @override
  State<InstitutionInterfacesPage> createState() => _InstitutionInterfacesPageState();
}

class _InstitutionInterfacesPageState extends State<InstitutionInterfacesPage> {
  late final InstitutionInterfacesBloc _bloc;
  late final InstitutionInterfacesDatasource _datasource;

  @override
  void initState() {
    super.initState();
    _datasource = Modular.get<InstitutionInterfacesDatasource>();
    _bloc = Modular.get<InstitutionInterfacesBloc>()..add(const InstitutionInterfacesListRequested(''));
  }

  Widget _buildList(InstitutionInterfacesListState state) => RegisterSearchPage<ClientInstitutionEntity>(
        title: widget.title,
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [
          c.name ?? '',
          if (!c.active) 'forms.institutionInterfaces.inactive'.tr(),
        ],
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) => _bloc.add(InstitutionInterfacesListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) => _bloc.add(InstitutionInterfacesListRequested(state.filter, pageSize: size)),
        configModuleKey: 'institution-interfaces',
        filter: state.filter,
        onFilterChanged: (filter) => _bloc.add(InstitutionInterfacesListRequested(filter)),
        onView: (client) => _bloc.add(InstitutionInterfacesOpened(client)),
      );

  Widget _buildDetail(InstitutionInterfacesDetailState state) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => _bloc.add(const InstitutionInterfacesBackToList()),
          ),
          title: Text('${widget.title} · ${state.client.name ?? state.client.id}'),
        ),
        body: InstitutionInterfacesTab(
          key: ValueKey('institution-interfaces-${state.client.id}'),
          institutionId: state.client.id,
          datasource: _datasource,
          // D-PV11: sem ALTERAR (marcado pelo Super) a aba só mostra
          canChange: CurrentInterface.can('ALTERAR'),
        ),
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<InstitutionInterfacesBloc, InstitutionInterfacesState>(
        bloc: _bloc,
        listenWhen: (_, current) => current is InstitutionInterfacesActionFailure,
        listener: (context, state) =>
            showFailureFeedback(context, (state as InstitutionInterfacesActionFailure).failure),
        buildWhen: (_, current) =>
            current is InstitutionInterfacesListState || current is InstitutionInterfacesDetailState,
        builder: (context, state) => switch (state) {
          InstitutionInterfacesDetailState() => _buildDetail(state),
          InstitutionInterfacesListState() => _buildList(state),
          _ => _buildList(const InstitutionInterfacesListState(loading: true)),
        },
      );
}
