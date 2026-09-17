import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/core/service/message_notification_listener.dart';
import 'package:flutter/widgets.dart';
import 'package:chat_app/core/service/background_call_service.dart';
import 'package:chat_app/core/service/notification_service.dart';
import 'package:chat_app/core/service/call_notification_listener.dart';
import 'package:chat_app/feature/auth/data/datasource/login_data_source.dart';
import 'package:chat_app/feature/auth/data/datasource/register_data_source.dart';
import 'package:chat_app/feature/auth/data/reposityImpl/login_repo_impl.dart';
import 'package:chat_app/feature/auth/data/reposityImpl/register_repo_impl.dart';
import 'package:chat_app/feature/auth/domain/reposity/login_repo.dart';
import 'package:chat_app/feature/auth/domain/reposity/register_repo.dart';
import 'package:chat_app/feature/auth/domain/usecase/login_usecase.dart';
import 'package:chat_app/feature/auth/domain/usecase/register_usecase.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_bloc.dart';
import 'package:chat_app/feature/auth/presentation/bloc/register_bloc.dart';
import 'package:chat_app/feature/call/callsignalingsevice/call_invite_payload.dart';
import 'package:chat_app/feature/call/data/datasource/call_remotedata_source.dart';
import 'package:chat_app/feature/call/data/repositoryImpl/call_repo_impl.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';
import 'package:chat_app/feature/group/data/repository_impl/group_repository_impl.dart';
import 'package:chat_app/feature/group/domain/repository/group_repository.dart';
import 'package:chat_app/feature/group/domain/usercase/create_group_usecase.dart';
import 'package:chat_app/feature/group/presentation/bloc/group_bloc.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/data/datasource/message_socket_datasource.dart';
import 'package:chat_app/feature/message/data/repositoryImpl/message_repo_impl.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';
import 'package:chat_app/feature/message/domain/usecase/connect_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/get_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/open_direct_conversation_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/send_message_usecase.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_bloc.dart';
import 'package:chat_app/feature/searchusers/data/datasource/user_remote_datasource.dart';
import 'package:chat_app/feature/searchusers/data/repositoryImpl/user_rearch_repo_impl.dart';
import 'package:chat_app/feature/searchusers/domain/reposity/user_search_repo.dart';
import 'package:chat_app/feature/searchusers/domain/usecase/search_user_usecase.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

final sl = GetIt.instance;

void initDependencies() {
  // 1. External (HTTP Client)
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => TokenStorage());
  // 2. Auth Feature - Data Sources
  sl.registerLazySingleton<RegisterDataSource>(
    () => RegisterDataSourceImpl(client: sl()),
  );
  // 3. Auth Feature - Repositories
  sl.registerLazySingleton<RegisterRepo>(
    () => RegisterRepoImpl(registerDataSource: sl()),
  );
  // 4. Auth Feature - Use Cases
  sl.registerLazySingleton(() => RegisterUsecase(sl()));
  // 5. Auth Feature - BLoC
  sl.registerFactory(() => RegisterBloc(registerUsecase: sl()));
  // --- LOGIN FEATURE ---
  sl.registerLazySingleton<LoginDataSource>(
    () => LoginDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<LoginRepo>(
    () => LoginRepoImpl(loginDataSource: sl()),
  );
  sl.registerLazySingleton(() => LoginUsecase(sl()));
  sl.registerFactory(() => LoginBloc(loginUsecase: sl()));

  sl.registerLazySingleton<MessageDataSource>(
    () => MessageDataSourceImpl(client: sl(), tokenStorage: sl()),
  );

  sl.registerLazySingleton<MessageSocketDataSource>(
    () => MessageSocketDataSourceImpl(tokenStorage: TokenStorage()),
  );
  sl.registerLazySingleton<MessageRepo>(
    () =>
        MessageRepoImpl(messageDataSource: sl(), messageSocketDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetMessagesUsecase(sl()));
  sl.registerLazySingleton(() => OpenDirectConversationUsecase(sl()));
  sl.registerLazySingleton(() => SendMessageUsecase(sl()));
  sl.registerLazySingleton(() => ConnectMessageUsecase(sl()));
  sl.registerFactory(
    () => MessageBloc(
      getMessagesUsecase: sl(),
      sendMessageUsecase: sl(),
      connectSocketUsecase: sl(),
    ),
  );
  sl.registerLazySingleton<UserRemoteDatasource>(
    () => UserRemoteDatasourceImpl(client: sl(), tokenStorage: sl()),
  );
  sl.registerLazySingleton<UserSearchRepo>(
    () => UserRearchRepoImpl(sl<UserRemoteDatasource>()),
  );
  sl.registerFactory(() => SearchUsersUsecase(sl<UserSearchRepo>()));
  sl.registerFactory(() => SearchUsersBloc(sl<SearchUsersUsecase>()));
  sl.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(client: sl(), tokenStorage: sl()),
  );
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(sl<GroupRemoteDataSource>()),
  );
  sl.registerFactory(
    () => GroupBloc(CreateGroupUsecase(sl<GroupRepository>())),
  );
  sl.registerLazySingleton<FriendRequestRemoteDatasource>(
    () => FriendRequestRemoteDatasourceImpl(client: sl(), tokenStorage: sl()),
  );
  sl.registerLazySingleton(() => CallSignalingService(sl()));

  sl.registerLazySingleton<CallRemoteDataSource>(
    () => CallRemotedataSource(sl<TokenStorage>()),
  );
  sl.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(sl<CallRemoteDataSource>()),
  );
}

/// Registers CallBloc once a user id is available (after login or
/// on auto-login). Safe to call multiple times — no-ops if already
/// registered.
bool _registeringCallBloc = false;
CallNotificationListener? _callNotifications;
MessageNotificationListener? _messageNotifications;

Future<void> stopCallListening() async {
  await _messageNotifications?.dispose();
  _messageNotifications = null;
  await NotificationService.instance.cancelMessages();
  await BackgroundCallService.stop();
  await _callNotifications?.dispose();
  _callNotifications = null;
  await NotificationService.instance.cancelIncomingCall();
  if (sl.isRegistered<CallBloc>() && sl.isReadySync<CallBloc>()) {
    await sl<CallBloc>().close();
    await sl.unregister<CallBloc>();
    await sl.resetLazySingleton<CallSignalingService>();
  }
}

Future<void> registerCallBloc() async {
  if (sl.isRegistered<CallBloc>() || _registeringCallBloc) return;
  _registeringCallBloc = true;
  try {
    sl.registerSingletonAsync<CallBloc>(() async {
      final tokenStorage = sl<TokenStorage>();
      final userId = await tokenStorage.getUserId();
      final userName = await tokenStorage.getUserName();
      if (userId == null || userId.isEmpty) {
        throw StateError('CallBloc needs a logged-in user id.');
      }
      final signaling = sl<CallSignalingService>();
      final bloc = CallBloc(
        currentUserId: userId,
        currentUserName: userName ?? '',
        signaling: signaling,
        callRepository: sl<CallRepository>(),
      );
      _callNotifications = CallNotificationListener(
        states: bloc.stream,
        show: NotificationService.instance.showIncomingCall,
        cancel: NotificationService.instance.cancelIncomingCall,
      );
      try {
        await BackgroundCallService.start();
        await signaling.start(userId);
        _messageNotifications = MessageNotificationListener(
          userId: userId,
          show: NotificationService.instance.showMessage,
          isBackground: () =>
              WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed,
        )..start(signaling.client);
        return bloc;
      } catch (_) {
        await _messageNotifications?.dispose();
        _messageNotifications = null;
        await _callNotifications?.dispose();
        _callNotifications = null;
        await bloc.close();
        await BackgroundCallService.stop();
        rethrow;
      }
    });
    await sl.isReady<CallBloc>();
  } finally {
    _registeringCallBloc = false;
  }
}
