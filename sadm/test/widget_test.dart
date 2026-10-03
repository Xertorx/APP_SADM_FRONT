// Basic smoke tests for the home screen and navigation to the adoptante
// registration form.

import 'package:flutter_test/flutter_test.dart';

import 'package:sadm/main.dart';

void main() {
  testWidgets('Renders the home screen with both entry points', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    expect(find.text('Bienvenido a SADM'), findsOneWidget);
    expect(find.text('Registrar adoptante'), findsOneWidget);
    expect(find.text('Publicar mascota'), findsOneWidget);
  });

  testWidgets('Navigates to the adoptante registration form', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    await tester.tap(find.text('Registrar adoptante'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de adoptante'), findsOneWidget);
  });
}
