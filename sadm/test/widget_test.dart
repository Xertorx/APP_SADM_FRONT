// Smoke tests for the public home screen and the auth entry points.

import 'package:flutter_test/flutter_test.dart';

import 'package:sadm/main.dart';
import 'package:sadm/services/auth_session.dart';

void main() {
  setUp(AuthSession.limpiar);

  testWidgets('Home shows the app info and only the auth actions', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    expect(find.text('¿Qué es SADM?'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
    expect(find.text('Publicar mascota'), findsNothing);
    expect(find.text('Dar en adopción'), findsNothing);
  });

  testWidgets('Navigates to the login form', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
  });

  testWidgets('Navigates to the registration form', (WidgetTester tester) async {
    await tester.pumpWidget(const SadmApp());

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('Authenticated usuario sees the panel shortcut instead', (WidgetTester tester) async {
    AuthSession.token = 'token';
    await tester.pumpWidget(const SadmApp());

    expect(find.text('Ir a mi panel'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });
}
