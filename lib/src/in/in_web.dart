library;

import 'package:isolator/src/in/in_abstract.dart';

/// [In] for the web
class InWeb implements In {
  late final Sink<dynamic> _sink;

  @override
  void send<T>(T data) => _sink.add(data);

  /// Inner package method
  void initSink(Sink<dynamic> sink) => _sink = sink;
}

/// Inner package factory
In createIn() => InWeb();
