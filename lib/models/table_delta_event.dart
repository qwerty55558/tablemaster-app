import 'table_model.dart';

enum TableDeltaType {
  snapshot,
  added,
  updated,
  removed,
}

class TableDeltaEvent {
  final TableDeltaType type;
  final List<TableModel>? tables;
  final TableModel? table;
  final String? removedId;

  const TableDeltaEvent._({
    required this.type,
    this.tables,
    this.table,
    this.removedId,
  });

  factory TableDeltaEvent.snapshot(List<TableModel> tables) =>
      TableDeltaEvent._(type: TableDeltaType.snapshot, tables: tables);

  factory TableDeltaEvent.added(TableModel table) =>
      TableDeltaEvent._(type: TableDeltaType.added, table: table);

  factory TableDeltaEvent.updated(TableModel table) =>
      TableDeltaEvent._(type: TableDeltaType.updated, table: table);

  factory TableDeltaEvent.removed(String id) =>
      TableDeltaEvent._(type: TableDeltaType.removed, removedId: id);
}
