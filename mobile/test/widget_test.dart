import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jansetu_mobile/main.dart';

void main() {
  testWidgets('JanSetu App smoke test renders ReportScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: JanSetuApp()));
    expect(find.text('Report Civic Issue'), findsOneWidget);
    expect(find.text('TAP TO TAKE PHOTO'), findsOneWidget);
  });
}
