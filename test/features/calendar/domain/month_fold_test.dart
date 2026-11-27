import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/month_fold.dart';

void main() {
  const fold = MonthFold(rows: 6, selectedRow: 3, rowHeight: 48);

  test('a 6-row month folds 240 dp, down to its one row', () {
    expect(fold.distance, 240);
    expect(fold.height(0), 288);
    expect(fold.height(0.5), 168);
    expect(fold.height(1), 48);
    expect(
      const MonthFold(rows: 5, selectedRow: 0, rowHeight: 48).distance,
      192,
    );
  });

  test('the selected row ends at the top', () {
    expect(fold.offset(0), 0);
    expect(fold.offset(1), -144);
    expect(
      const MonthFold(rows: 6, selectedRow: 0, rowHeight: 48).offset(1),
      0,
    );
    expect(
      const MonthFold(rows: 6, selectedRow: 5, rowHeight: 48).offset(0.5),
      -120,
    );
  });

  test('the other rows are gone by 60 %, the handle comes in after 70 %', () {
    expect(MonthFold.othersOpacity(0), 1);
    expect(MonthFold.othersOpacity(0.3), closeTo(0.5, 1e-9));
    expect(MonthFold.othersOpacity(0.6), 0);
    expect(MonthFold.othersOpacity(1), 0);
    expect(MonthFold.handleOpacity(0), 0);
    expect(MonthFold.handleOpacity(0.7), 0);
    expect(MonthFold.handleOpacity(0.85), closeTo(0.5, 1e-9));
    expect(MonthFold.handleOpacity(1), 1);
  });
}
