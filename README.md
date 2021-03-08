# isolator

Isolator is a package, which offer to you a simple way for creating two-component states with isolated part and frontend part of any kind (BLoC, MobX, ChangeNotifier and many others).

This package is a trying to proof of concept, when you take out heavy business logic to isolates for achievement a fully cleared from any lugs application. With this package you can easy create a so-called "backend" - class with your logic and second class, which uses a special mixin - a state of any kind - BLoC / MobX / ChangeNotifier (as in an example).

## Example (with null-safety now)

```dart
import 'package:flutter/cupertino.dart';
import 'package:isolator/isolator.dart';

enum TestEvent { intSync, intAsync, intAsyncWithReturn, chunks, observer, errorOnBackend, invalidType, afterCreation }

const int VALUE_AFTER_CREATION = 11;
const int ASYNC_INT = 10;
const int SYNC_INT = 12;

/// Example of state with ChangeNotifier
class ChangeNotifierFrontend with Frontend<TestEvent>, ChangeNotifier {
  @override
  Map<TestEvent, Function> get tasks => {};
}

/// Frontend - anything else, what you want to use a state of your app
class FrontendTest with Frontend<TestEvent> {
  int asyncIntFromBackend = 0;
  int syncIntFromBackend = 0;
  int valueAfterCreation = 0;
  bool isErrorHandled = false;
  List<int> intChunks = [];

  /// You can get any value (after calculating it on the backend) in synchronous style
  /// When you using [runBackendMethod] function - you call your Backend's method, which
  /// matches the passed event id, and get back value in that place
  ///
  /// It most simplest way to use Isolator
  Future<int> getIntFromBackendSync() async {
    final int intFromBackend = await runBackendMethod(TestEvent.intSync);
    syncIntFromBackend = intFromBackend;
    return syncIntFromBackend;
  }

  /// Also, you can use asynchronous style
  /// It is the way, when you send some params (with event id) to Backend
  /// Then, Backend handle it, and after that you handle Backend response via Frontend task
  void loadIntFromBackend() {
    send(TestEvent.intAsync);
  }

  /// It is a task for handle Backend response
  /// for event id [TestEvent.intAsync]
  void _setIntFromBackend(int intFromBackend) {
    this.asyncIntFromBackend = intFromBackend;
  }

  /// You can return value from backend with simple "return" keyword
  /// without using [send] method of your Backend
  /// To see that - open [_returnIntBack] method of [BackendTest]
  void loadIntFromBackendWithReturn() {
    send(TestEvent.intAsyncWithReturn);
  }

  /// When you want get a large amount of data from the Backend
  /// You can use [sendChunks] method of the Backend
  /// For example - see method [_returnChunks] of [BackendTest]
  void loadChunks() {
    send(TestEvent.chunks);
  }

  /// Task for handle [sendChunks] event must take a [List] of data
  void _setIntChunks(List<int> intChunks) {
    this.intChunks.clear();
    this.intChunks.addAll(intChunks);
  }

  /// Before using Backend with Frontend, you should init your Backend
  /// To do this - simple use [initBackend] method of your Frontend
  Future<void> init(int id) async {
    await initBackend<int>(_backendFabric, data: VALUE_AFTER_CREATION, id: '$id');
  }

  /// If you want to destroy Backend - use [killBackend] method
  /// It can be useful, if your state lifetime is shorter than lifetime of app
  void dispose() {
    killBackend();
  }

  /// Hook, which calls on every error
  /// Which throws in the Backend
  @override
  Future<void> onError(dynamic error) async {
    await super.onError(error);
  }

  /// Hook, which calls on every event from the Backend
  @override
  void onBackendResponse() {
    super.onBackendResponse();
  }

  /// This method need for test cases
  void invalidType() {
    send(TestEvent.invalidType);
  }

  /// This method need for test cases
  void runError() {
    send(TestEvent.errorOnBackend);
  }

  /// This method need for test cases
  void _taskWithInvalidType(String intFromBackend) {
    // WAITING FOR ERROR
  }

  /// This method need for test cases
  void _handleError(dynamic error) {
    isErrorHandled = true;
  }

  /// This method need for test cases
  void _setValueAfterCreation(int valueAfterCreation) {
    this.valueAfterCreation = valueAfterCreation;
  }

  /// [tasks] - Map of methods, which calls on events with
  /// matched ids from Backend
  @override
  Map<TestEvent, Function> get tasks => {
        TestEvent.intAsync: _setIntFromBackend,
        TestEvent.intAsyncWithReturn: _setIntFromBackend,
        TestEvent.chunks: _setIntChunks,
        TestEvent.invalidType: _taskWithInvalidType,
        TestEvent.afterCreation: _setValueAfterCreation,
      };

  /// [errorsHandlers] - Map of methods, which calls, if error
  /// was thrown in the Backend, while Backend handle operation
  /// with matched event id
  @override
  Map<TestEvent, ErrorHandler> get errorsHandlers => {
        TestEvent.errorOnBackend: _handleError,
      };
}

/// Backend - class, which will handle your logic in separate isolate
class BackendTest extends Backend<TestEvent> {
  BackendTest(BackendArgument<int> argument) : super(argument) {
    _sendValueAfterCreation(argument.data!);
  }

  /// You can send value to the Frontend with [send] method
  /// Also, you can use this method any times in all of you Backend methods
  void _sendIntBack() {
    send(TestEvent.intAsync, ASYNC_INT);
    send(TestEvent.observer);
  }

  /// Or you can simply return the value and your Frontend will receive a message with exact event id
  /// For example - there Frontend will receive event [TestEvent.intAsyncWithReturn] with value [ASYNC_INT]
  int _returnIntBack() {
    return ASYNC_INT;
  }

  void _sendValueAfterCreation(int value) {
    send(TestEvent.afterCreation, value);
  }

  int _returnSyncInt() {
    return SYNC_INT;
  }

  int _returnValue() {
    return SYNC_INT;
  }

  void _throwError() {
    throw Exception('Manual error');
  }

  /// Example of using [sendChunks] method for sending a large amount of data
  /// from the Backend to the Frontend without junks of your interface
  void _returnChunks() {
    final List<int> chunks = [];
    for (int i = 0; i < 10000; i++) {
      chunks.add(i);
    }

    /// You can control delay between chunks and amount of items in one chunk
    /// to achieve a lowest time for the data transfering and doesn't have any junks
    sendChunks(TestEvent.chunks, chunks, delay: const Duration(milliseconds: 3), itemsPerChunk: 1000);
  }

  /// [operations] - Map of methods, which similar to [tasks] of Frontend
  /// every operation will handle events from the Frontend with matched event id
  @override
  Map<TestEvent, Function> get operations => {
        TestEvent.intAsync: _sendIntBack,
        TestEvent.intAsyncWithReturn: _returnIntBack,
        TestEvent.intSync: _returnSyncInt,
        TestEvent.invalidType: _returnValue,
        TestEvent.errorOnBackend: _throwError,
        TestEvent.chunks: _returnChunks,
      };
}

class AnotherFrontend {
  AnotherFrontend(this.frontendTest);

  final FrontendTest frontendTest;
  int intFromFrontendTest = 0;

  void subscriptionForFrontendTest() {
    this.intFromFrontendTest = frontendTest.asyncIntFromBackend;
  }
  
  /// You can subscribe on every available (your) event of your Frontend
  void subscribe() {
    frontendTest.onEvent(TestEvent.observer, subscriptionForFrontendTest);
  }
}

void _backendFabric(BackendArgument<int> argument) {
  BackendTest(argument);
}

```

## Restrictions
- Backend classes can't use a native layer (method-channel)
- For one backend - one isolate (too many isolates take much time for initialization, for example: ~6000ms for 30 isolates at emulator in dev mode) 

## Schema of interaction

![Schema](https://github.com/alphamikle/isolator/raw/master/schema.png)