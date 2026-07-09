import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/session_user.dart';
import '../repository/auth_repository.dart';

class GetMeUsecase {
  const GetMeUsecase({required this.repository});

  final AuthRepository repository;

  Future<Either<Failure, SessionUser>> call() => repository.getMe();
}
