import 'dart:async';

import '../core/logging/visitor_api_logger.dart';
import '../domain/entities/visitor_activity.dart';
import '../domain/repositories/visitor_repository.dart';

/// Periodically polls `/chatscript/visitor/polling` for new activities.
class VisitorPollingService {
  final VisitorRepository _repository;
  final Duration interval;

  Timer? _timer;
  bool _inFlight = false;
  String _timestamp;
  String? _tenantId;
  String? _sessionId;

  final _activitiesController =
      StreamController<List<IncomingVisitorActivity>>.broadcast();
  final _errorController = StreamController<Object>.broadcast();

  VisitorPollingService({
    required this._repository,
    this.interval = const Duration(seconds: 3),
    String initialTimestamp = '0',
  }) : _timestamp = initialTimestamp;

  Stream<List<IncomingVisitorActivity>> get activities =>
      _activitiesController.stream;

  Stream<Object> get errors => _errorController.stream;

  String get currentTimestamp => _timestamp;

  bool get isRunning => _timer != null;

  void start({required String tenantId, required String sessionId}) {
    _tenantId = tenantId;
    _sessionId = sessionId;
    stop(cancelControllers: false);
    VisitorApiLogger.info(
      'POLL loop start every ${interval.inSeconds}s | '
      'tid=$tenantId sid=$sessionId ts=$_timestamp',
    );
    _timer = Timer.periodic(interval, (_) => _tick());
    unawaited(_tick());
  }

  void stop({bool cancelControllers = true}) {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final tenantId = _tenantId;
    final sessionId = _sessionId;
    if (tenantId == null || sessionId == null || _inFlight) return;

    _inFlight = true;
    try {
      final result = await _repository.pollActivities(
        tenantId: tenantId,
        sessionId: sessionId,
        timestamp: _timestamp,
      );
      _timestamp = result.nextTimestamp;
      if (result.activities.isNotEmpty && !_activitiesController.isClosed) {
        _activitiesController.add(result.activities);
      }
    } catch (e) {
      VisitorApiLogger.error('POLL tick failed', e);
      if (!_errorController.isClosed) {
        _errorController.add(e);
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> dispose() async {
    stop();
    await _activitiesController.close();
    await _errorController.close();
  }
}
