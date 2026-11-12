import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_tracker/screens/auth_screen.dart';
import 'package:health_tracker/theme/app_theme.dart';

void main() {
  Future<void> openAuthScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const AuthScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRegisterForm(WidgetTester tester) async {
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
  }

  testWidgets('login rejects an email outside gmail.com', (tester) async {
    await openAuthScreen(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'person@example.com');
    await tester.enterText(fields.at(1), 'password');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Gunakan alamat email @gmail.com yang valid'),
        findsOneWidget);
  });

  testWidgets('login continues to accept a username', (tester) async {
    await openAuthScreen(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'JhonDoe');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Wajib diisi'), findsOneWidget);
    expect(
        find.text('Gunakan alamat email @gmail.com yang valid'), findsNothing);
  });

  testWidgets('register requires a gmail.com address', (tester) async {
    await openAuthScreen(tester);
    await openRegisterForm(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jhon Doe');
    await tester.enterText(fields.at(1), 'JhonDoe');
    await tester.enterText(fields.at(2), 'person@example.com');
    await tester.enterText(fields.at(3), 'password');
    await tester.enterText(fields.at(4), '170');
    await tester.enterText(fields.at(5), '65');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Gunakan alamat email @gmail.com yang valid'),
        findsOneWidget);
  });

  testWidgets('register rejects out-of-range height and weight',
      (tester) async {
    await openAuthScreen(tester);
    await openRegisterForm(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jhon Doe');
    await tester.enterText(fields.at(1), 'JhonDoe');
    await tester.enterText(fields.at(2), 'jhon@gmail.com');
    await tester.enterText(fields.at(3), 'password');
    await tester.enterText(fields.at(4), '251');
    await tester.enterText(fields.at(5), '301');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Tinggi harus antara 50–250 cm'), findsOneWidget);
    expect(find.text('Berat harus antara 10–300 kg'), findsOneWidget);
  });
}
