
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notepad_messenger/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Notepad launches successfully', (tester) async {
    await tester.pumpWidget(
      const NotepadApp(backendConfigured: false),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notepad'), findsOneWidget);
    expect(find.text('RECENT NOTES'), findsOneWidget);
  });
}
