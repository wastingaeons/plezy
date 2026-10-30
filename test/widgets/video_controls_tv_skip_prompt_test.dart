import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/video_controls/video_controls.dart';

void main() {
  test('TV marker prompt stays visible after player controls hide', () {
    expect(
      shouldShowSkipMarkerButton(
        hasFirstFrame: true,
        hasMarker: true,
        hasPlayNextPrompt: false,
        skipButtonDismissed: false,
        controlsVisible: false,
        persistUntilMarkerEnds: true,
      ),
      isTrue,
    );
  });

  test('TV honors an explicit dismiss even when chrome is visible', () {
    expect(
      shouldShowSkipMarkerButton(
        hasFirstFrame: true,
        hasMarker: true,
        hasPlayNextPrompt: false,
        skipButtonDismissed: true,
        controlsVisible: true,
        persistUntilMarkerEnds: true,
      ),
      isFalse,
    );
  });

  test('TV prompt never appears without marker or before first frame', () {
    for (final hasFirstFrame in [false, true]) {
      for (final hasMarker in [false, true]) {
        if (hasFirstFrame && hasMarker) continue;
        expect(
          shouldShowSkipMarkerButton(
            hasFirstFrame: hasFirstFrame,
            hasMarker: hasMarker,
            hasPlayNextPrompt: false,
            skipButtonDismissed: false,
            controlsVisible: false,
            persistUntilMarkerEnds: true,
          ),
          isFalse,
        );
      }
    }
  });

  test('up-next dialog takes precedence over TV skip prompt', () {
    expect(
      shouldShowSkipMarkerButton(
        hasFirstFrame: true,
        hasMarker: true,
        hasPlayNextPrompt: true,
        skipButtonDismissed: false,
        controlsVisible: false,
        persistUntilMarkerEnds: true,
      ),
      isFalse,
    );
  });

  test(
    'mobile keeps full-sized skip prompt available while controls are hidden',
    () {
      expect(
        shouldShowSkipMarkerButton(
          hasFirstFrame: true,
          hasMarker: true,
          hasPlayNextPrompt: false,
          skipButtonDismissed: false,
          controlsVisible: false,
          persistUntilMarkerEnds: true,
        ),
        isTrue,
      );
      expect(
        shouldShowSkipMarkerButton(
          hasFirstFrame: true,
          hasMarker: true,
          hasPlayNextPrompt: false,
          skipButtonDismissed: true,
          controlsVisible: true,
          persistUntilMarkerEnds: true,
        ),
        isFalse,
      );
    },
  );

  test('desktop retains original seven-second dismissal behavior', () {
    expect(
      shouldShowSkipMarkerButton(
        hasFirstFrame: true,
        hasMarker: true,
        hasPlayNextPrompt: false,
        skipButtonDismissed: true,
        controlsVisible: false,
      ),
      isFalse,
    );
    expect(
      shouldShowSkipMarkerButton(
        hasFirstFrame: true,
        hasMarker: true,
        hasPlayNextPrompt: false,
        skipButtonDismissed: true,
        controlsVisible: true,
      ),
      isTrue,
    );
  });
}
