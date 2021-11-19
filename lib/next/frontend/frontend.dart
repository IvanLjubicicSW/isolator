import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isolator/next/action_reducer.dart';
import 'package:isolator/next/backend/backend_create_result.dart';
import 'package:isolator/next/backend/initializer_error_text.dart';
import 'package:isolator/next/in/in_abstract.dart';
import 'package:isolator/next/isolator/isolator_abstract.dart';
import 'package:isolator/next/maybe.dart';
import 'package:isolator/next/message.dart';
import 'package:isolator/next/out/out_abstract.dart';
import 'package:isolator/next/types.dart';
import 'package:isolator/next/utils.dart';

part 'frontend_action_initializer.dart';

mixin Frontend {
  void initActions();

  void onForceUpdate() {}

  void onEvent() {}

  @mustCallSuper
  Future<void> initBackend<T>({
    required BackendInitializer<T> initializer,
    required Type backendType,
    IsolatePoolId? poolId,
    T? data,
  }) async {
    initActions();
    final BackendCreateResult result = await Isolator.instance.isolate(
      initializer: initializer,
      backendType: backendType,
      poolId: poolId,
    );
    _backendType = backendType;
    _poolId = result.poolId;
    _backendOut = result.backendOut;
    _frontendIn = result.frontendIn;
    _backendOut.listen(_backendMessageRawHandler);
  }

  @mustCallSuper
  Future<void> dispose() async {
    _completers.clear();
    _runningFunctions.clear();
    _actions.clear();
    await Isolator.instance.close(backendType: _backendType, poolId: _poolId);
  }

  Future<Maybe<Res>> run<Event, Req extends Object?, Res extends Object?>({required Event event, Req? data, Duration? timeout}) async {
    final String code = generateMessageCode(event);
    final Completer<Maybe<dynamic>> completer = Completer<Maybe<dynamic>>();
    final StackTrace currentTrace = StackTrace.current;
    final String runningFunctionName = getNameOfParentRunningFunction(currentTrace.toString());
    _completers[code] = completer;
    _runningFunctions[code] = runningFunctionName;
    _frontendIn.send(
      Message<Event, Req?>(
        event: event,
        data: data,
        code: code,
        timestamp: DateTime.now(),
        serviceData: ServiceData.none,
      ),
    );
    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, () {
        _completers.remove(code);
        _runningFunctions.remove(code);
        throw Exception('Timeout ($timeout) of action $event with code $code exceed');
      });
    }
    final Maybe<dynamic> result = await completer.future;
    timer?.cancel();
    _completers.remove(code);
    _runningFunctions.remove(code);
    return result.castTo<Res>();
  }

  FrontendActionInitializer<Event> on<Event>([Event? event]) => FrontendActionInitializer(frontend: this, event: event, eventType: Event);

  Future<void> _backendMessageRawHandler(dynamic backendMessage) async {
    if (backendMessage is Message) {
      await _backendMessageHandler<dynamic, dynamic>(backendMessage);
    } else {
      throw Exception('Got an invalid message from Backend: $backendMessage');
    }
  }

  Future<void> _backendMessageHandler<Event, Data>(Message<Event, Data> backendMessage) async {
    if (backendMessage.isChunksMessage) {
      await _handleChunksEvent<Event, dynamic>(backendMessage as Message<Event, List<dynamic>>);
    } else if (backendMessage.code.isNotEmpty) {
      await _handleSyncEvent<Event, Data>(backendMessage);
    } else {
      await _handleAsyncEvent<Event, Data>(backendMessage);
    }
  }

  Future<void> _handleSyncEvent<Event, Data>(Message<Event, Data> backendMessage) async {
    final String code = backendMessage.code;
    try {
      if (!_completers.containsKey(code)) {
        throw Exception('Not found Completer for event ${backendMessage.event} with code $code. Maybe you`ve seen Timeout exception?');
      }
      final Data data = backendMessage.data;
      final Completer<Data> completer = _completers[code]! as Completer<Data>;
      completer.complete(data);
      onEvent();
      if (backendMessage.forceUpdate) {
        onForceUpdate();
      }
    } catch (error) {
      print('''
[$runtimeType] Sync action error
Data: ${objectToTypedString(backendMessage.data)}
Event: ${objectToTypedString(backendMessage.event)}
Code: ${backendMessage.code}
Additional info: ${_runningFunctions[code] ?? StackTrace.current}
Error: ${errorToString(error)}
Stacktrace: ${errorStackTraceToString(error)}
''');
      _runningFunctions.remove(code);
      rethrow;
    }
  }

  Future<void> _handleAsyncEvent<Event, Data>(Message<Event, Data> backendMessage) async {
    try {
      final Function action = getAction(backendMessage.event, _actions, runtimeType.toString());
      action(event: backendMessage.event, data: backendMessage.data);
      onEvent();
      if (backendMessage.forceUpdate) {
        onForceUpdate();
      }
    } catch (error) {
      print('''
[$runtimeType] Async action error
Data: ${objectToTypedString(backendMessage.data)}
Event: ${objectToTypedString(backendMessage.event)}
Code: ${backendMessage.code}
Additional info: ${_runningFunctions[backendMessage.code] ?? StackTrace.current}
Error: ${errorToString(error)}
Stacktrace: ${errorStackTraceToString(error)}
''');
      _runningFunctions.remove(backendMessage.code);
      rethrow;
    }
  }

  Future<void> _handleChunksEvent<Event, Data>(Message<Event, List<Data>> backendMessage) async {
    final String transactionCode = backendMessage.code;
    final ServiceData serviceData = backendMessage.serviceData;
    final List<Data> data = backendMessage.data;
    if (serviceData == ServiceData.transactionStart) {
      _chunksPartials[transactionCode] = data;
    } else if (serviceData == ServiceData.transactionContinue) {
      (_chunksPartials[transactionCode]! as List<Data>).addAll(data);
    } else if (serviceData == ServiceData.transactionEnd) {
      (_chunksPartials[transactionCode]! as List<Data>).addAll(data);
      final bool isSyncChunkEvent = isSyncChunkEventCode(backendMessage.code);
      if (isSyncChunkEvent) {
        await _handleSyncEvent(
          Message(
            event: backendMessage.event,
            data: Maybe<Data>(data: _chunksPartials[transactionCode], error: null),
            code: syncChunkCodeToMessageCode(backendMessage.code),
            timestamp: backendMessage.timestamp,
            serviceData: ServiceData.none,
          ),
        );
      } else {
        await _handleAsyncEvent(
          Message(
            event: backendMessage.event,
            data: _chunksPartials[transactionCode],
            code: '',
            timestamp: backendMessage.timestamp,
            serviceData: ServiceData.none,
          ),
        );
      }
      _chunksPartials.remove(transactionCode);
    } else if (serviceData == ServiceData.transactionAbort) {
      _chunksPartials.remove(transactionCode);
    }
  }

  late final Out _backendOut;
  late final In _frontendIn;
  late Type _backendType;
  late int _poolId;
  final Map<dynamic, Function> _actions = <dynamic, Function>{};
  final Map<String, Completer> _completers = {};
  final Map<String, String> _runningFunctions = {};
  final Map<String, List<dynamic>> _chunksPartials = {};
}
