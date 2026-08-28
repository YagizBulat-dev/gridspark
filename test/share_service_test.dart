import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/core/services/share_service.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('maps native share statuses to explicit app outcomes', () {
    expect(
      mapShareResultStatus(ShareResultStatus.success),
      ShareOutcome.success,
    );
    expect(
      mapShareResultStatus(ShareResultStatus.dismissed),
      ShareOutcome.dismissed,
    );
    expect(
      mapShareResultStatus(ShareResultStatus.unavailable),
      ShareOutcome.error,
    );
  });
}
