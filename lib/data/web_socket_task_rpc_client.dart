import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'task_rpc_client.dart';

class WebSocketTaskRpcClient implements TaskRpcClient {
  WebSocketTaskRpcClient(this.uri);

  final Uri uri;
  WebSocketChannel? _channel;
  rpc.Peer? _peer;

  @override
  Future<void> connect() async {
    if (_peer != null) {
      return;
    }

    final channel = WebSocketChannel.connect(uri);
    await channel.ready;

    final peer = rpc.Peer(channel.cast<String>());
    _channel = channel;
    _peer = peer;
    unawaited(peer.listen());
  }

  @override
  void registerMethod(String name, TaskRpcMethodCallback callback) {
    final peer = _peer;
    if (peer == null) {
      throw StateError('RPC client is not connected');
    }

    peer.registerMethod(name, (rpc.Parameters parameters) {
      return callback(parameters.value);
    });
  }

  @override
  Future<Object?> sendRequest(String method, [Object? parameters]) async {
    final peer = _peer;
    if (peer == null) {
      throw StateError('RPC client is not connected');
    }

    return peer.sendRequest(method, parameters);
  }

  @override
  Future<void> close() async {
    await _peer?.close();
    await _channel?.sink.close();
    _peer = null;
    _channel = null;
  }
}
