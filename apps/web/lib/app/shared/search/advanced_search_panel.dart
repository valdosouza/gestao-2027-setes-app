import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../entity/widgets/entity_date.dart';
import '../format/money.dart';
import 'search_criteria_datasource.dart';
import 'search_criterion.dart';

/// Abre o painel da PESQUISA AVANÇADA (prompt_pesquisa_avancada.md) e devolve
/// os valores novos — null = cancelado (nada muda). O painel é apresentação
/// pura: não pesquisa sozinho; quem recarrega a lista é o bloc do módulo
/// (evento com filtro + critérios, sempre na página 1).
///
/// Vive em app/shared/search (não em register/) porque as telas de processo
/// (D-BA9, Onda 3) usam o mesmo painel fora da fábrica.
Future<SearchCriteriaValues?> showAdvancedSearch({
  required BuildContext context,
  required List<SearchCriterion> criteria,
  required SearchCriteriaValues current,
  required SearchCriteriaDatasource datasource,
}) =>
    showDialog<SearchCriteriaValues>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: _AdvancedSearchBody(
            criteria: criteria,
            current: current,
            datasource: datasource,
          ),
        ),
      ),
    );

/// Número digitado em pt-BR no painel → valor (null = vazio; NaN = inválido).
/// M1 do gate socrático: '1.500' é MIL E QUINHENTOS (ponto = milhar), não
/// 1,5 — vírgula é o ÚNICO separador decimal aceito ('1.234,56', '1500,5').
/// Mesmo teto de magnitude da API (MAX_RANGE_MAGNITUDE = 1e13): o 422 fica
/// inalcançável pela tela.
abstract final class AdvancedSearchNumbers {
  static final _pattern = RegExp(r'^-?(\d{1,3}(\.\d{3})+|\d+)(,\d+)?$');

  static double? parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (!_pattern.hasMatch(t)) return double.nan;
    final n = double.parse(t.replaceAll('.', '').replaceAll(',', '.'));
    return n.abs() > 1e13 ? double.nan : n;
  }
}

/// Teto do texto de um critério — espelho de MAX_TEXT_LENGTH da API.
const maxCriterionTextLength = 100;

/// Texto de um valor para o chip (lista) — mesma formatação do painel.
String describeCriterionValue(SearchCriterion criterion, Object value) {
  String point(Object? v) => switch (criterion.kind) {
        SearchCriterionKind.date => isoDateToDisplay(v as String?),
        SearchCriterionKind.money => setesMoney((v as num).toDouble()),
        _ => '$v',
      };
  return switch (value) {
    SearchRange r when r.from != null && r.to != null =>
      'search.range'.tr(args: [point(r.from), point(r.to)]),
    SearchRange r when r.from != null =>
      'search.rangeFrom'.tr(args: [point(r.from)]),
    SearchRange r => 'search.rangeTo'.tr(args: [point(r.to)]),
    SearchLookupValue l => l.name,
    List<dynamic> l =>
      l.map((o) => criterion.optionLabelKey('$o').tr()).join(', '),
    bool b => b ? 'register.yes'.tr() : 'register.no'.tr(),
    _ => '$value',
  };
}

class _AdvancedSearchBody extends StatefulWidget {
  const _AdvancedSearchBody({
    required this.criteria,
    required this.current,
    required this.datasource,
  });

  final List<SearchCriterion> criteria;
  final SearchCriteriaValues current;
  final SearchCriteriaDatasource datasource;

  @override
  State<_AdvancedSearchBody> createState() => _AdvancedSearchBodyState();
}

class _AdvancedSearchBodyState extends State<_AdvancedSearchBody> {
  final _formKey = GlobalKey<FormState>();

  /// Controllers por critério: texto usa [key]; faixas usam key.from/key.to.
  final _controllers = <String, TextEditingController>{};
  final _lookups = <String, SearchLookupValue?>{};
  final _options = <String, Set<String>>{};
  final _bools = <String, bool?>{};

  @override
  void initState() {
    super.initState();
    for (final c in widget.criteria) {
      final value = widget.current.values[c.key];
      switch (c.kind) {
        case SearchCriterionKind.text:
          _controllers[c.key] =
              TextEditingController(text: value is String ? value : '');
        case SearchCriterionKind.number:
        case SearchCriterionKind.money:
        case SearchCriterionKind.date:
          final r = value is SearchRange ? value : const SearchRange();
          _controllers['${c.key}.from'] =
              TextEditingController(text: _rangeText(c, r.from));
          _controllers['${c.key}.to'] =
              TextEditingController(text: _rangeText(c, r.to));
        case SearchCriterionKind.lookup:
          _lookups[c.key] = value is SearchLookupValue ? value : null;
        case SearchCriterionKind.options:
          _options[c.key] = {
            if (value is List) ...value.map((e) => '$e'),
          };
        case SearchCriterionKind.bool:
          _bools[c.key] = value is bool ? value : null;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _rangeText(SearchCriterion c, Object? v) {
    if (v == null) return '';
    if (c.kind == SearchCriterionKind.date) return isoDateToDisplay(v as String);
    if (c.kind == SearchCriterionKind.money) {
      return (v as num).toStringAsFixed(2).replaceAll('.', ',');
    }
    return '$v';
  }

  static double? _parseNumber(String text) => AdvancedSearchNumbers.parse(text);

  Object? _rangePoint(SearchCriterion c, String text) {
    if (c.kind == SearchCriterionKind.date) return displayDateToIso(text);
    final n = _parseNumber(text);
    if (n == null || n.isNaN) return null;
    if (c.kind == SearchCriterionKind.money) return roundMoney(n);
    return n == n.truncateToDouble() ? n.toInt() : n;
  }

  String? _validatePoint(SearchCriterion c, String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return null;
    if (c.kind == SearchCriterionKind.date) return validateOptionalDate(t);
    final n = _parseNumber(t);
    return (n == null || n.isNaN) ? 'register.invalidNumber'.tr() : null;
  }

  String? _validateRange(SearchCriterion c) {
    final from = _rangePoint(c, _controllers['${c.key}.from']!.text);
    final to = _rangePoint(c, _controllers['${c.key}.to']!.text);
    if (from == null || to == null) return null;
    final inverted = from is String
        ? from.compareTo(to as String) > 0
        : (from as num) > (to as num);
    return inverted ? 'search.invalidRange'.tr() : null;
  }

  void _clear() => setState(() {
        for (final c in _controllers.values) {
          c.clear();
        }
        _lookups.updateAll((_, __) => null);
        _options.updateAll((_, __) => <String>{});
        _bools.updateAll((_, __) => null);
      });

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final raw = <String, Object?>{};
    for (final c in widget.criteria) {
      switch (c.kind) {
        case SearchCriterionKind.text:
          raw[c.key] = _controllers[c.key]!.text;
        case SearchCriterionKind.number:
        case SearchCriterionKind.money:
        case SearchCriterionKind.date:
          raw[c.key] = SearchRange(
            from: _rangePoint(c, _controllers['${c.key}.from']!.text),
            to: _rangePoint(c, _controllers['${c.key}.to']!.text),
          );
        case SearchCriterionKind.lookup:
          raw[c.key] = _lookups[c.key];
        case SearchCriterionKind.options:
          // ordem do domínio (estável no chip e na URL)
          raw[c.key] =
              c.options.where(_options[c.key]!.contains).toList();
        case SearchCriterionKind.bool:
          raw[c.key] = _bools[c.key];
      }
    }
    Navigator.of(context).pop(SearchCriteriaValues.from(raw));
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final iso = displayDateToIso(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: iso == null ? DateTime.now() : DateTime.parse(iso),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => controller.text =
        '${picked.day.toString().padLeft(2, '0')}/'
        '${picked.month.toString().padLeft(2, '0')}/${picked.year}');
  }

  Future<void> _pickLookup(SearchCriterion c) async {
    final picked = await showSetesLookup<SearchLookupItem>(
      context: context,
      title: c.labelKey.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) => widget.datasource.lookup(c.lookup!, filter),
      itemId: (i) => i.id,
      itemLabel: (i) => i.name,
    );
    if (picked == null || !mounted) return;
    setState(() => _lookups[c.key] =
        SearchLookupValue(id: picked.id, name: picked.name));
  }

  Widget _rangeField(SearchCriterion c, String end) {
    final controller = _controllers['${c.key}.$end']!;
    final isDate = c.kind == SearchCriterionKind.date;
    return SetesTextField(
      label: 'search.$end'.tr(),
      hint: isDate ? 'register.dateHint'.tr() : null,
      controller: controller,
      keyboardType: isDate
          ? TextInputType.datetime
          : const TextInputType.numberWithOptions(decimal: true),
      suffixIcon: isDate ? Icons.calendar_today : null,
      onSuffixPressed: isDate ? () => _pickDate(controller) : null,
      validator: (v) =>
          _validatePoint(c, v) ?? (end == 'to' ? _validateRange(c) : null),
    );
  }

  Widget _field(SearchCriterion c) {
    final label = c.labelKey.tr();
    switch (c.kind) {
      case SearchCriterionKind.text:
        return SetesTextField(
          label: label,
          hint: 'search.containsHint'.tr(),
          controller: _controllers[c.key],
          // M3 do gate: o mesmo teto da API (MAX_TEXT_LENGTH) — 422 inalcançável
          validator: (v) => (v?.trim().length ?? 0) > maxCriterionTextLength
              ? 'search.tooLong'.tr(args: ['$maxCriterionTextLength'])
              : null,
        );
      case SearchCriterionKind.number:
      case SearchCriterionKind.money:
      case SearchCriterionKind.date:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText(label),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _rangeField(c, 'from')),
              const SizedBox(width: 12),
              Expanded(child: _rangeField(c, 'to')),
            ]),
          ],
        );
      case SearchCriterionKind.lookup:
        return SetesLookupField(
          label: label,
          display: _lookups[c.key]?.name ?? '',
          onSearch: () => _pickLookup(c),
          onClear: () => setState(() => _lookups[c.key] = null),
        );
      case SearchCriterionKind.options:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText(label),
            for (final option in c.options)
              SetesCheckbox(
                label: c.optionLabelKey(option).tr(),
                value: _options[c.key]!.contains(option),
                onChanged: (v) => setState(() => v == true
                    ? _options[c.key]!.add(option)
                    : _options[c.key]!.remove(option)),
              ),
          ],
        );
      case SearchCriterionKind.bool:
        return SetesDropdown<String>(
          label: label,
          value: switch (_bools[c.key]) {
            true => 'yes',
            false => 'no',
            null => 'any',
          },
          items: const ['any', 'yes', 'no'],
          itemLabel: (i) => switch (i) {
            'yes' => 'register.yes'.tr(),
            'no' => 'register.no'.tr(),
            _ => 'search.any'.tr(),
          },
          onChanged: (i) => setState(() => _bools[c.key] = switch (i) {
                'yes' => true,
                'no' => false,
                _ => null,
              }),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SetesText('search.title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in widget.criteria) ...[
                        _field(c),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SetesButton(
                    label: 'search.clear'.tr(),
                    kind: SetesButtonKind.text,
                    onPressed: _clear,
                  ),
                  const SizedBox(width: 8),
                  SetesButton(
                    label: 'register.cancel'.tr(),
                    kind: SetesButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  SetesButton(
                    label: 'register.search'.tr(),
                    icon: Icons.search,
                    onPressed: _apply,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
