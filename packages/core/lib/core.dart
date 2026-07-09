/// packages/core — núcleo compartilhado do setes-app (decisão 10).
library core;

export 'src/core/config/app_config.dart';
export 'src/error/failure.dart';
export 'src/shared/helpers/catalog_i18n.dart';
export 'src/shared/helpers/responsive.dart';
export 'src/shared/http/api_client.dart';
export 'src/shared/storage/local_prefs.dart';

export 'src/auth/auth_module.dart';
export 'src/auth/domain/entity/auth_session.dart';
export 'src/auth/domain/entity/institution_option.dart';
export 'src/auth/domain/repository/auth_repository.dart';
export 'src/auth/domain/usecase/login_usecase.dart';
export 'src/auth/domain/usecase/select_institution_usecase.dart';
export 'src/auth/data/model/login_result_model.dart';
export 'src/auth/data/datasource/auth_remote_datasource.dart';
export 'src/auth/data/repository/auth_repository_impl.dart';
export 'src/auth/presentation/bloc/auth_bloc.dart';
export 'src/auth/presentation/page/login_page.dart';
export 'src/auth/presentation/page/select_institution_page.dart';

export 'src/menu/domain/entity/menu_entity.dart';
export 'src/menu/domain/repository/menu_repository.dart';
export 'src/menu/domain/usecase/get_menus_usecase.dart';
export 'src/menu/data/model/menu_model.dart';
export 'src/menu/data/datasource/menu_remote_datasource.dart';
export 'src/menu/data/repository/menu_repository_impl.dart';

export 'src/preference/domain/repository/preference_repository.dart';
export 'src/preference/domain/usecase/get_preferences_usecase.dart';
export 'src/preference/domain/usecase/save_preference_usecase.dart';
export 'src/preference/data/datasource/preference_remote_datasource.dart';
export 'src/preference/data/repository/preference_repository_impl.dart';
export 'src/preference/presentation/locale_sync.dart';
export 'src/preference/presentation/widget/language_selector.dart';
