import 'package:meta/meta.dart';
import 'package:isolator/src/in/in_abstract.dart';

enum MessageType {
  add,
  remove,
}

/// Helper to register and unregister Backends in DataBus
@immutable
class DataBusBackendInitMessage {
  const DataBusBackendInitMessage({
    required this.backendIn,
    required this.backendId,
    required this.type,
  });

  final In? backendIn;
  final String backendId;
  final MessageType type;
}
