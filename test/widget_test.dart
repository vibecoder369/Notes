import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_messenger/main.dart';

void main() {
  testWidgets('Notepad launches cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const NotepadApp(backendConfigured: false));
    expect(find.text('Notepad'), findsOneWidget);
  });
}
