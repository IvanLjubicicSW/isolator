library;

import 'dart:async';

import 'package:isolator/src/in/in_abstract.dart';
import 'package:isolator/src/in/in_web.dart';
import 'package:isolator/src/out/out_abstract.dart';
import 'package:isolator/src/types.dart';

/// Out implementation for the web
class OutWeb<T> implements Out<T> {
  late final StreamController<T> _streamController = StreamController<T>();
  late final Stream<T> _stream = _streamController.stream.asBroadcastStream();

  @override
  In get createIn => InWeb()..initSink(_streamController.sink);

  @override
  StreamSubscription<T> listen(
    StreamDataListener<T> onData, {
    StreamErrorListener? onError,
    StreamOnDoneCallback? onDone,
    bool cancelOnError = false,
  }) {
    final subscription = _stream.listen(
      onData as StreamDataListener<dynamic>,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
    return subscription;
  }

  @override
  Future<void> close() => _streamController.close();
}

/// Inner package factory
Out<T> createOut<T>() => OutWeb<T>();
