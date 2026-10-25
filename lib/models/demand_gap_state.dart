import 'package:flutter/foundation.dart';
import '../repositories/demand_gap_repository.dart';
import '../services/api_client.dart';
import 'demand_gap_models.dart';

/// The admin's Demand tab: the report for the chosen window. Changing the window loads again; the last report stays on screen meanwhile.
class DemandGapState extends ChangeNotifier {
  DemandGapState({required DemandGapRepository repository, int days = 14}) : _repo = repository, _days = days;

  final DemandGapRepository _repo;

  int _days;
  DemandGapReport? _report;
  bool _loading = false;
  String? _error;
  int _ticket = 0;
  bool _disposed = false;

  int get days => _days;
  DemandGapReport? get report => _report;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    final ticket = ++_ticket;
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _repo.load(days: _days);
      if (ticket != _ticket) return; // a newer window took over
      _report = r;
    } catch (e) {
      if (ticket != _ticket) return;
      _error = e is ApiException ? e.message : 'Could not load demand gaps.';
    } finally {
      if (ticket == _ticket) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> setDays(int days) {
    if (days == _days) return Future.value();
    _days = days;
    return load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
