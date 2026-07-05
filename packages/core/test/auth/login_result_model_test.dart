import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

// Padrão de testes de model (Agent_Context_App.md, seção 5.4):
// fromJson snake/camel, campos null → defaults, empty().
void main() {
  group('LoginResultModel', () {
    test('fromJson com 1 institution retorna token direto', () {
      final model = LoginResultModel.fromJson(const {'ok': true, 'token': 'jwt-final'});

      expect(model.token, 'jwt-final');
      expect(model.needsSelection, isFalse);
      expect(model.institutions, isEmpty);
    });

    test('fromJson com N institutions retorna selectionToken + lista', () {
      final model = LoginResultModel.fromJson(const {
        'ok': true,
        'select': true,
        'selectionToken': 'jwt-selecao',
        'institutions': [
          {'institutionId': 1, 'schemaName': 'setes_setes', 'name': 'Setes', 'profile': 'super'},
          {'institutionId': 2, 'schemaName': 'setes_alpha', 'name': 'Alpha', 'profile': null},
        ],
      });

      expect(model.needsSelection, isTrue);
      expect(model.selectionToken, 'jwt-selecao');
      expect(model.institutions, hasLength(2));
      expect(model.institutions.first.institutionId, 1);
      expect(model.institutions.last.profile, isNull);
    });

    test('empty() retorna sessão vazia', () {
      final model = LoginResultModel.empty();

      expect(model.token, isNull);
      expect(model.needsSelection, isFalse);
    });
  });

  group('MenuModuleModel', () {
    test('fromJson monta módulo com interfaces e privilégios', () {
      final model = MenuModuleModel.fromJson(const {
        'module': {'id': 10, 'description': 'Sistema', 'icon': 2},
        'interfaces': [
          {
            'id': 100,
            'description': 'Estabelecimentos',
            'buttonAction': '/institution',
            'imgIndex': 1,
            'privileges': ['view', 'update'],
          },
        ],
      });

      expect(model.id, 10);
      expect(model.interfaces.single.can('VIEW'), isTrue);
      expect(model.interfaces.single.can('delete'), isFalse);
    });

    test('fromJson com module null usa pseudo-módulo Geral', () {
      final model = MenuModuleModel.fromJson(const {
        'module': {'id': null, 'description': null},
        'interfaces': [],
      });

      expect(model.id, isNull);
      expect(model.description, 'Geral');
    });
  });
}
