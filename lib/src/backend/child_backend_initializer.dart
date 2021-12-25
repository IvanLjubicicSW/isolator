import 'package:meta/meta.dart';
import 'package:isolator/src/backend/backend.dart';
import 'package:isolator/src/backend/backend_argument.dart';
import 'package:isolator/src/types.dart';

/// Special class to initialize Backend in the existing pool
@immutable
class ChildBackendInitializer<T, B extends Backend> {
  const ChildBackendInitializer({
    required this.initializer,
    required this.argument,
    required this.backendId,
  });

  final BackendInitializer<T, B> initializer;
  final BackendArgument<T> argument;
  final BackendId backendId;
}
