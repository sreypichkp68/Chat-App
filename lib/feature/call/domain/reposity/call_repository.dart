abstract class CallRepository {
  Future<void> endCall({required String callId, required String status});
}
