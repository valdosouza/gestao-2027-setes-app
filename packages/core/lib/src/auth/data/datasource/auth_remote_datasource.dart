import '../../../shared/http/api_client.dart';
import '../model/login_result_model.dart';

/// data implementa o que domain define (decisão 12).
class AuthRemoteDatasource {
  const AuthRemoteDatasource({required this.client});

  final ApiClient client;

  Future<LoginResultModel> login(String email, String password) async {
    final json = await client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return LoginResultModel.fromJson(json);
  }

  Future<String> selectInstitution(String selectionToken, int institutionId) async {
    final json = await client.post(
      '/auth/select-institution',
      {'institutionId': institutionId},
      overrideToken: selectionToken,
    );
    return json['token'] as String;
  }
}
