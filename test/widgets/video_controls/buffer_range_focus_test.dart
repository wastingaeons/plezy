import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/video_controls/painters/buffer_range_painter.dart';

void main() {
  test('timeline repaints when the D-pad focus palette changes', () {
    final unfocused = BufferRangePainter(
      ranges: const [],
      duration: const Duration(minutes: 42),
      focused: false,
    );
    final focused = BufferRangePainter(
      ranges: const [],
      duration: const Duration(minutes: 42),
      focused: true,
    );

    expect(focused.shouldRepaint(unfocused), isTrue);
    expect(unfocused.shouldRepaint(focused), isTrue);
    expect(focused.shouldRepaint(focused), isFalse);
  });
}
