// Basic smoke test for the adoptante registration form.

import 'package:flutter_test/flutter_test.dart';

import 'package:sadm/main.dart';

void main() {
  testWidgets('Renders the adoptante registration form', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    expect(find.text('Registro de adoptante'), findsOneWidget);
    expect(find.text('Registrar adoptante'), findsOneWidget);
  });
}

