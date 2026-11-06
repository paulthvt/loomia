import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/presentation/fit_words.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // The test font draws every glyph as wide as the font size: 10 px here.
  String fit(
    String text, {
    required double width,
    required int maxLines,
    double scale = 1,
  }) => fitWords(
    text,
    style: const TextStyle(fontSize: 10),
    width: width,
    maxLines: maxLines,
    scaler: TextScaler.linear(scale),
    direction: TextDirection.ltr,
  );

  testWidgets('a title that fits stays as it is', (tester) async {
    expect(
      fit('Dinner with Léa & Tom', width: 60, maxLines: 4),
      'Dinner with Léa & Tom',
    );
  });

  testWidgets('whole words, then "…"', (tester) async {
    expect(fit('Open house brunch', width: 50, maxLines: 1), 'Open…');
  });

  testWidgets('a first word too long shows its first letters', (tester) async {
    expect(fit('Product evening', width: 50, maxLines: 1), 'Prod…');
  });

  testWidgets('over two lines, never a break inside a word', (tester) async {
    expect(fit('Coffee with Camille', width: 70, maxLines: 2), 'Coffee with…');
    // Each word on its own line, Camille at exactly 70.
    expect(
      fit('Coffee with Camille', width: 70, maxLines: 3),
      'Coffee with Camille',
    );
    // Two lines of 50: "Coffee" (60) can't sit whole on one.
    expect(fit('Coffee with Camille', width: 50, maxLines: 2), 'Coff…');
  });

  testWidgets('at text scale 2', (tester) async {
    expect(fit('Team check-in', width: 50, maxLines: 1, scale: 2), 'T…');
    expect(tester.takeException(), isNull);
  });
}
