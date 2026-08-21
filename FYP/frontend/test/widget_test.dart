import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/state/app_settings_controller.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final controller = AppSettingsController();
    await tester.pumpWidget(StudyApp(controller: controller));
    expect(find.byType(StudyApp), findsOneWidget);
  });
}
