import 'package:flutter_test/flutter_test.dart';
import 'package:nimbark_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows auth screen when no session is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const NimbarkApp());
    await tester.pumpAndSettle();

    expect(find.text('Nimbark'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
