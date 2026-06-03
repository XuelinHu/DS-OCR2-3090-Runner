import 'package:ds_ocr_mobile/src/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders OCR home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DsOcrApp());
    await tester.pump();

    expect(find.text('DS OCR'), findsOneWidget);
    expect(find.text('OCR Task'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
  });
}
