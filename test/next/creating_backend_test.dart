import 'package:flutter_test/flutter_test.dart';

import 'creating_backend/backend_example.dart';
import 'creating_backend/frontend_example.dart';

FrontendExample? frontend;
FrontendExample get front => frontend!;

Future<void> main() async {
  group('Creating backend', () {
    setUp(() async {
      frontend = FrontendExample();
      await front.init();
    });

    tearDown(() async {
      await front.dispose();
      frontend = null;
    });

    test('Check running backend method', () async {
      final int computeResult = await front.computeIntOnBackend();
      expect(computeResult, 2);
    });

    test('Check sending messages from backend to frontend and reversed', () async {
      front.runBackendEventWithSendingMessageBack();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(front.isMessageReceived, true);
    });

    test('Check sending large amount of data via chunks from Backend to Frontend with "send" method', () async {
      front.initReceivingMockData();
      const Duration timeout = Duration(milliseconds: TOTAL_SIZE * (DELAY_MS + 8) * 2 ~/ CHUNK_SIZE);
      print('Timeout: ${timeout.inMilliseconds}');
      await Future<void>.delayed(timeout);
      expect(front.mockData.length, TOTAL_SIZE);
    });

    test('Check sending large amount of data via chunks from Backend to Frontend with sync style method', () async {
      await front.getLargeDataSync();
      expect(front.mockData.length, TOTAL_SIZE);
    });
  });
}
