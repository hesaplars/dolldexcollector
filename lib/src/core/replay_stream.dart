import 'dart:async';

class ReplayStream<T> extends Stream<T> {
  final Stream<T> _source;
  T? _lastValue;
  bool _hasValue = false;
  StreamSubscription<T>? _subscription;
  final Set<StreamController<T>> _controllers = {};

  ReplayStream(this._source);

  void _startSubscription() {
    _subscription ??= _source.listen(
      (data) {
        _lastValue = data;
        _hasValue = true;
        final targets = List<StreamController<T>>.from(_controllers);
        for (final c in targets) {
          if (!c.isClosed) {
            c.add(data);
          }
        }
      },
      onError: (err) {
        final targets = List<StreamController<T>>.from(_controllers);
        for (final c in targets) {
          if (!c.isClosed) {
            c.addError(err);
          }
        }
      },
      onDone: () {
        final targets = List<StreamController<T>>.from(_controllers);
        for (final c in targets) {
          if (!c.isClosed) {
            c.close();
          }
        }
      },
    );
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<T>(sync: true);
    
    _controllers.add(controller);
    _startSubscription();

    if (_hasValue) {
      controller.add(_lastValue as T);
    }

    final sub = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    controller.onCancel = () {
      _controllers.remove(controller);
      controller.close();
      if (_controllers.isEmpty) {
        _subscription?.cancel();
        _subscription = null;
      }
    };

    return sub;
  }
}
