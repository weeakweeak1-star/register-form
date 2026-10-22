import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_weeak_admin/main.dart';

void main() {
  testWidgets('Admin app widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
