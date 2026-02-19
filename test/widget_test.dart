import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dgx_thermal/main.dart';
import 'package:dgx_thermal/providers/connection_provider.dart';

void main() {
  testWidgets('Connection screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConnectionProvider(),
        child: const DgxThermalApp(),
      ),
    );
    expect(find.text('DGX Thermal'), findsOneWidget);
  });
}
