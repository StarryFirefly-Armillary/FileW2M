import 'package:flutter_test/flutter_test.dart';
import 'package:file_transfer/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const FileTransferApp());
    expect(find.text('FileTransfer'), findsOneWidget);
  });
}
