import 'package:isolator/next/backend/backend_argument.dart';
import 'package:isolator/next/frontend/frontend.dart';

import 'back.dart';
import 'event.dart';

class Front with Frontend {
  bool uiWasUpdated = false;
  int value = 0;
  final List<int> values = [];
  final List<int> chunks = [];

  void initValueMessageSending() => run(event: Event.getMessageWithValue);

  void initListMessageSending() => run(event: Event.getMessageWithList);

  void initChunksMessageSending() => run(event: Event.getMessageWithChunks);

  void initSeveralMessagesSending() => run(event: Event.getSeveralMessages);

  void _setValue({required Event event, required int data}) {
    value = data;
  }

  void _setList({required Event event, required List<int> data}) {
    values
      ..clear()
      ..addAll(data);
  }

  void _setChunks({required Event event, required List<int> data}) {
    chunks
      ..clear()
      ..addAll(data);
  }

  @override
  void onForceUpdate() {
    /// This hook will called automatically
    /// If you passed [forceUpdate] argument in send method of Backend:
    /// send(event: Event.getMessageWithList, data: ActionResponse.value([1, 2, 3, 4, 5]), forceUpdate: true);
    ///
    /// You can use it, for example - to automatically update your UI by calling [notifyListeners]
    uiWasUpdated = true;
  }

  @override
  Future<void> destroy() async {
    uiWasUpdated = false;
    value = 0;
    values.clear();
    chunks.clear();
    await super.destroy();
  }

  Future<void> init() async {
    await initBackend(initializer: createBack);
  }

  @override
  void initActions() {
    whenEventCome(Event.getMessageWithValue).run(_setValue);
    whenEventCome(Event.getMessageWithList).run(_setList);
    whenEventCome(Event.getMessageWithChunks).run(_setChunks);
  }
}

Back createBack(BackendArgument<void> argument) {
  return Back(argument: argument);
}
