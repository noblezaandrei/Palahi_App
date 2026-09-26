import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/widgets/button_label.dart';

void main() {
  // The breeder's request card squeezes three buttons into one row; on a
  // 360dp-wide phone their labels used to wrap mid-word ("Acce / pt").
  for (final textScale in [1.0, 1.3]) {
    testWidgets('three buttons in a row keep one-line labels '
        '(text scale $textScale)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const ButtonLabel('Message'),
                        style: OutlinedButton.styleFrom(
                          padding: compactButtonPadding,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: compactButtonPadding,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const ButtonLabel('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: compactButtonPadding,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const ButtonLabel('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      for (final label in ['Message', 'Reject', 'Accept']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        // One line of text, never wrapped or cut off.
        expect(
          paragraph.size.height, // as laid out in the button
          lessThan(paragraph.text.style!.fontSize! * textScale * 2),
          reason: '$label wrapped onto more than one line',
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      expect(tester.takeException(), isNull); // no overflow errors
    });
  }
}
