typedef TaskRpcMethodCallback = Object? Function(Object? parameters);

abstract class TaskRpcClient {
  Future<void> connect();
  Future<Object?> sendRequest(String method, [Object? parameters]);
  void registerMethod(String name, TaskRpcMethodCallback callback);
  Future<void> close();
}
