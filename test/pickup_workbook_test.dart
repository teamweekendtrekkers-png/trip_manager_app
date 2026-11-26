import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/pickup_workbook.dart';

void main() {
  test('exports the roster as typed Excel cells', () {
    final bytes = buildPickupWorkbook(
      (slug: 'sample', title: 'Sample trip', date: '2026-11-27', open: true),
      [
        {
          'lead_name': '=Sample traveller',
          'phone': '+91 90000 00001',
          'party_size': 2,
          'passenger_names': ['Second traveller'],
          'stop': 'station',
        },
      ],
      [
        {'id': 'station', 'name': 'Station', 'pickup_time': '9 PM'},
      ],
    );

    final sheet = Excel.decodeBytes(bytes)['Check-ins'];
    expect(sheet.maxRows, 2);
    final values = sheet.rows[1].map((cell) => cell?.value).toList();
    expect(values[2], isA<TextCellValue>());
    expect(values[2].toString(), '=Sample traveller');
    expect(values[3].toString(), '+91 90000 00001');
    expect((values[4] as IntCellValue).value, 2);
    expect(values[5].toString(), 'Second traveller');
    expect(values[6].toString(), 'Station');
    expect(values[7].toString(), '9 PM');
  });
}
