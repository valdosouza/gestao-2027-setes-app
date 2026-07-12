import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';

/// Contrato do repositório de Usuário (decisão 12: `Either<Failure, T>`).
/// Vínculos com institutions ficam no datasource (seção autônoma — mesmo
/// precedente da aba Interfaces do Estabelecimento).
abstract class UserRepository {
  Future<Either<Failure, List<UserListItem>>> getList(String filter);
  Future<Either<Failure, UserEntity>> get(int id);
  Future<Either<Failure, int>> post(UserEntity user);
  Future<Either<Failure, Unit>> put(UserEntity user);
  Future<Either<Failure, Unit>> delete(int id);
}
