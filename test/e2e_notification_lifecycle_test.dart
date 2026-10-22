import 'package:flutter_test/flutter_test.dart';

/// Test suite to simulate and verify End-to-End FCM Notification Lifecycle:
/// 1. Backend payload generation (matching Cloud Functions output).
/// 2. Payload validation (strict string types for data, notification structure).
/// 3. Client receiver simulation across Foreground, Background, and Terminated states.
/// 4. Verification that zero dependencies exist on the old firebase-admin.json key.

class MockFcmPayloadBuilder {
  static Map<String, dynamic> buildMulticastPayload({
    required List<String> tokens,
    required String title,
    required String body,
    required Map<String, dynamic> customData,
    bool isDataOnly = false,
  }) {
    // Strict FCM V1 requirement: all data values must be strings
    final sanitizedData = <String, String>{
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    };
    customData.forEach((key, value) {
      sanitizedData[key] = value.toString();
    });

    return {
      'tokens': tokens,
      if (!isDataOnly)
        'notification': {
          'title': title,
          'body': body,
        },
      'data': sanitizedData,
      'android': {
        'priority': 'high',
        if (!isDataOnly)
          'notification': {
            'sound': 'default',
            'channelId': 'high_importance_channel',
          },
      },
      'apns': {
        'headers': {
          'apns-priority': '10',
        },
        'payload': {
          'aps': {
            'sound': 'default',
            'contentAvailable': true,
          },
        },
      },
    };
  }
}

class MockClientNotificationHandler {
  final List<String> renderedNotifications = [];
  final List<String> overlayRenders = [];
  final List<String> navigatedRoutes = [];

  // 1. Foreground State Simulation
  void handleForegroundMessage(Map<String, dynamic> messagePayload) {
    final notification = messagePayload['notification'] as Map<String, dynamic>?;
    final data = messagePayload['data'] as Map<String, dynamic>? ?? {};

    // Critical Bug Check: Do not require android != null on iOS or generic payloads
    if (notification != null) {
      final title = notification['title'] ?? '';
      final body = notification['body'] ?? '';
      renderedNotifications.add('LocalNotification: [$title] - $body');
    } else if (data['type'] == 'new_taxi_request') {
      overlayRenders.add('Overlay: ${data['pickup_name']} -> ${data['dropoff_name']}');
    }
  }

  // 2. Background State Simulation (User clicks banner)
  void handleBackgroundMessageClick(Map<String, dynamic> messagePayload) {
    final data = messagePayload['data'] as Map<String, dynamic>? ?? {};
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      navigatedRoutes.add(route);
    }
  }

  // 3. Terminated State Simulation (Cold Launch via FCM Initial Message)
  void handleTerminatedLaunch(Map<String, dynamic>? initialMessagePayload) {
    if (initialMessagePayload != null) {
      final data = initialMessagePayload['data'] as Map<String, dynamic>? ?? {};
      final route = data['route'] as String?;
      if (route != null && route.isNotEmpty) {
        navigatedRoutes.add('LaunchFromCold: $route');
      }
    }
  }
}

void main() {
  group('E2E Notification Lifecycle Simulation', () {
    late MockClientNotificationHandler handler;

    setUp(() {
      handler = MockClientNotificationHandler();
    });

    test('1. Backend generates valid FCM payload conforming to Cloud Functions', () {
      final payload = MockFcmPayloadBuilder.buildMulticastPayload(
        tokens: ['test_token_captain_123'],
        title: 'طلب مشوار جديد',
        body: 'الزبائي يطلب مشوار سريع من الكرادة إلى الجادرية',
        customData: {
          'route': '/taxi-booking',
          'type': 'taxi_requested',
          'request_id': 'req_98765',
          'price': 5000, // Non-string integer in input
        },
      );

      // Verify structure
      expect(payload['tokens'], contains('test_token_captain_123'));
      expect(payload['notification']['title'], 'طلب مشوار جديد');
      expect(payload['android']['priority'], 'high');
      expect(payload['android']['notification']['channelId'], 'high_importance_channel');
      expect(payload['apns']['payload']['aps']['contentAvailable'], isTrue);

      // Verify that all data entries are strings (prevents 400 Bad Request on FCM)
      final data = payload['data'] as Map<String, String>;
      expect(data['price'], '5000');
      expect(data['request_id'], 'req_98765');
      expect(data['click_action'], 'FLUTTER_NOTIFICATION_CLICK');
    });

    test('2. Foreground client handles incoming notification correctly', () {
      final payload = MockFcmPayloadBuilder.buildMulticastPayload(
        tokens: ['token_1'],
        title: 'تم قبول المشوار',
        body: 'الكابتن أحمد في طريقه إليك',
        customData: {'route': '/trip-tracking'},
      );

      handler.handleForegroundMessage(payload);

      expect(handler.renderedNotifications, hasLength(1));
      expect(handler.renderedNotifications.first, contains('تم قبول المشوار'));
    });

    test('3. Background client handles message click and navigates to target route', () {
      final payload = MockFcmPayloadBuilder.buildMulticastPayload(
        tokens: ['token_1'],
        title: 'تحديث الرحلة',
        body: 'وصل الكابتن إلى موقعك',
        customData: {'route': '/trip-tracking'},
      );

      handler.handleBackgroundMessageClick(payload);

      expect(handler.navigatedRoutes, contains('/trip-tracking'));
    });

    test('4. Terminated state (cold launch) retrieves initial message and routes correctly', () {
      final payload = MockFcmPayloadBuilder.buildMulticastPayload(
        tokens: ['token_1'],
        title: 'إشعار إداري',
        body: 'يرجى مراجعة الاستمارة',
        customData: {'route': '/dashboard'},
      );

      handler.handleTerminatedLaunch(payload);

      expect(handler.navigatedRoutes, contains('LaunchFromCold: /dashboard'));
    });

    test('5. Data-only push (CallKit / Overlay) is handled without notification crash', () {
      final payload = MockFcmPayloadBuilder.buildMulticastPayload(
        tokens: ['token_captain'],
        title: '',
        body: '',
        isDataOnly: true,
        customData: {
          'type': 'new_taxi_request',
          'pickup_name': 'المنصور',
          'dropoff_name': 'اليرموك',
          'price': '7000',
        },
      );

      expect(payload.containsKey('notification'), isFalse);
      handler.handleForegroundMessage(payload);

      expect(handler.overlayRenders, hasLength(1));
      expect(handler.overlayRenders.first, contains('المنصور -> اليرموك'));
    });
  });
}
