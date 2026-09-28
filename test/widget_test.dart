import 'package:flutter_test/flutter_test.dart';
import 'package:kmc_teacher_app/main.dart';

void main() {
  testWidgets('Teacher App Shell smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KasaraniTeacherApp());

    // Verify splash screen branding exists
    expect(find.text('KASARANI MUSIC CENTER'), findsOneWidget);
    expect(find.text('TEACHER & FACULTY PORTAL'), findsOneWidget);
  });
}
