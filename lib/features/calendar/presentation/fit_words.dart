import 'package:material_ui/material_ui.dart';

/// [text] cut to what fits on [maxLines] lines of [width]: as many whole
/// words as fit, then "…"; when the first word alone doesn't, its leading
/// letters + "…"; [text] itself when it all fits. Never a word split over
/// two lines.
String fitWords(
  String text, {
  required TextStyle style,
  required double width,
  required int maxLines,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  final painter = TextPainter(
    textDirection: direction,
    textScaler: scaler,
    maxLines: maxLines,
  );
  double wide(String piece) {
    painter
      ..text = TextSpan(text: piece, style: style)
      ..layout();
    return painter.width;
  }

  // A word wider than the line would wrap inside itself: that doesn't fit.
  bool fits(String candidate) {
    if (candidate.split(' ').any((word) => wide(word) > width)) return false;
    painter
      ..text = TextSpan(text: candidate, style: style)
      ..layout(maxWidth: width);
    return !painter.didExceedMaxLines;
  }

  try {
    if (fits(text)) return text;
    final words = text.split(' ');
    for (var n = words.length - 1; n > 0; n--) {
      final candidate = '${words.take(n).join(' ')}…';
      if (fits(candidate)) return candidate;
    }
    final letters = words.first.characters;
    for (var n = letters.length - 1; n > 0; n--) {
      final candidate = '${letters.take(n)}…';
      if (fits(candidate)) return candidate;
    }
    return '…';
  } finally {
    painter.dispose();
  }
}
