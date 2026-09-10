import 'package:chat_app/feature/call/data/datasource/call_remotedata_source.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._remoteDataSource);

  final CallRemoteDataSource _remoteDataSource;

  @override
  Future<void> endCall({required String callId, required String status}) async {
    await _remoteDataSource.endCall(callId: callId, status: status);
  }
}
