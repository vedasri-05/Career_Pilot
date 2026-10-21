import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme configuration smoke test', (WidgetTester tester) async {
    final theme = AppTheme.lightTheme;
    expect(theme.scaffoldBackgroundColor, AppTheme.background);
    expect(theme.primaryColor, AppTheme.primaryBlue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('CareerPilot Running'))),
      ),
    );

    expect(find.text('CareerPilot Running'), findsOneWidget);
  });
}
