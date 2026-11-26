import 'package:excel/excel.dart';

import 'pickup_service.dart';

List<int> buildPickupWorkbook(
  PickupDeparture departure,
  List<Map<String, dynamic>> rows,
  List<Map<String, dynamic>> stops,
) {
  final workbook = Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet()!;
  workbook.rename(defaultSheet, 'Check-ins');
  final sheet = workbook['Check-ins'];
  final locations = {for (final stop in stops) stop['id']: stop};
  final headers = [
    'Trip',
    'Departure date',
    'Lead traveller',
    'Phone number',
    'Party size',
    'Additional travellers',
    'Pickup point',
    'Pickup time',
  ];
  sheet.appendRow(headers.map(TextCellValue.new).toList());
  final widths = <double>[38, 17, 26, 21, 13, 42, 26, 22];
  for (var column = 0; column < headers.length; column++) {
    sheet.setColumnWidth(column, widths[column]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        .cellStyle = CellStyle(bold: true);
  }
  for (final row in rows) {
    final stop = locations[row['stop']];
    final people = (row['party_size'] as num?)?.toInt() ?? 1;
    final names = ((row['passenger_names'] as List?) ?? const [])
        .whereType<String>()
        .take(people > 0 ? people - 1 : 0)
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
    sheet.appendRow([
      TextCellValue(departure.title),
      TextCellValue(departure.date),
      TextCellValue(row['lead_name']?.toString() ?? ''),
      TextCellValue(row['phone']?.toString() ?? ''),
      IntCellValue(people),
      TextCellValue(names),
      TextCellValue(stop?['name']?.toString() ?? ''),
      TextCellValue(stop?['pickup_time']?.toString() ?? ''),
    ]);
  }
  return workbook.encode() ?? (throw StateError('Could not create the Excel workbook.'));
}
