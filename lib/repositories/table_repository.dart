import 'dart:async';
import '../models/table_delta_event.dart';
import '../models/table_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

/// 테이블 데이터 Repository (단일 진실원)
/// - WS 델타 수신 → 상태 적용
/// - HTTP fallback
/// - 스트림으로 외부에 상태 노출
class TableRepository {
  final ApiService _apiService;
  final WebSocketService _wsService;

  List<TableModel> _tables = [];
  TableModel? _currentTable;

  final _tablesController = StreamController<List<TableModel>>.broadcast();
  final _currentTableController = StreamController<TableModel?>.broadcast();

  StreamSubscription<TableDeltaEvent>? _deltaSub;

  // Singleton
  static TableRepository? _instance;
  factory TableRepository({
    required ApiService apiService,
    required WebSocketService wsService,
  }) {
    _instance ??= TableRepository._internal(apiService, wsService);
    return _instance!;
  }

  TableRepository._internal(this._apiService, this._wsService) {
    _deltaSub = _wsService.tablesStream.listen(_applyDelta);
  }

  List<TableModel> get tables => _tables;
  TableModel? get currentTable => _currentTable;
  Stream<List<TableModel>> get tablesStream => _tablesController.stream;
  Stream<TableModel?> get currentTableStream => _currentTableController.stream;

  /// HTTP로 강제 새로고침 (WS 장애 시 fallback)
  Future<void> refresh() async {
    final tables = await _apiService.getTables();
    if (tables.isNotEmpty) {
      _tables = tables;
      _tablesController.add(_tables);
      _syncCurrentTable();
    }
  }

  /// 내 테이블 직접 클리어 (인증 해제 등)
  void clearCurrentTable() {
    _currentTable = null;
    _currentTableController.add(null);
  }

  void _applyDelta(TableDeltaEvent event) {
    switch (event.type) {
      case TableDeltaType.snapshot:
        _tables = event.tables!;
        break;

      case TableDeltaType.added:
      case TableDeltaType.updated:
        final table = event.table!;
        final idx = _tables.indexWhere((t) => t.id == table.id);
        if (idx != -1) {
          _tables = [
            for (int i = 0; i < _tables.length; i++)
              i == idx ? table : _tables[i],
          ];
        } else {
          _tables = [..._tables, table];
        }
        break;

      case TableDeltaType.removed:
        _tables = _tables.where((t) => t.id != event.removedId).toList();
        break;
    }

    _tablesController.add(_tables);
    _syncCurrentTable();
  }

  void _syncCurrentTable() {
    final deviceId = _apiService.deviceId;

    if (_currentTable != null) {
      final match = _tables.where((t) => t.id == _currentTable!.id).firstOrNull;
      if (match == null) {
        _currentTable = null;
        _currentTableController.add(null);
      } else {
        // 이전 상태가 INACTIVE → 재연결 델타 전송
        if (_currentTable!.status == TableStatus.inactive &&
            match.status == TableStatus.inactive) {
          _wsService.sendReconnectDelta();
        }
        if (match != _currentTable) {
          _currentTable = match;
          _currentTableController.add(match);
        }
      }
    } else if (deviceId != null) {
      final myTable = _tables.where((t) => t.id == deviceId).firstOrNull;
      if (myTable != null) {
        // 첫 세팅인데 INACTIVE → 앱 재시작 케이스
        if (myTable.status == TableStatus.inactive) {
          _wsService.sendReconnectDelta();
        }
        _currentTable = myTable;
        _currentTableController.add(myTable);
      }
    }
  }

  void dispose() {
    _deltaSub?.cancel();
    _tablesController.close();
    _currentTableController.close();
  }
}
