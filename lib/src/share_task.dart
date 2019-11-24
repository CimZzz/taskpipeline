part of 'task_pipeline.dart';



Map<dynamic, Map<dynamic, BaseShareTask>> _shareTaskMap;

BaseShareTask<T, Q> _findShareTask<T, Q>(dynamic key, T dataKey) {
	if(_shareTaskMap != null) {
		final keyMap = _shareTaskMap[key];
		if(keyMap != null) {
			final shareTask = keyMap[dataKey];
			if(shareTask != null) {
				if(shareTask is BaseShareTask<T, Q>) {
					return shareTask;
				}
				else {
					throw TaskException(message: "Equal key, but not equal share task. key : $key");
				}
			}
		}
	}
	
	return null;
}

void _addShareTask(BaseShareTask baseShareTask) {
	_shareTaskMap ??= Map();
	final keyMap = _shareTaskMap.putIfAbsent(baseShareTask.uniqueKey, () => Map());
	keyMap[baseShareTask.data] = baseShareTask;
}

void _removeShareTask(BaseShareTask baseShareTask) {
	if(_shareTaskMap != null) {
		final keyMap = _shareTaskMap[baseShareTask.uniqueKey];
		if(keyMap != null) {
			if(keyMap.remove(baseShareTask.data) != null) {
				if(keyMap.isEmpty) {
					_shareTaskMap.remove(baseShareTask.uniqueKey);
					if(_shareTaskMap.isEmpty) {
						_shareTaskMap = null;
					}
				}
			}
		}
	}
}

abstract class BaseShareTask<T, Q> {
	dynamic get uniqueKey;
	T get data;
	int _refCount = 0;
	
	Completer<Q> _completer;
	StreamSubscription<Q> _innerSubscription;
	Completer<Q> _innerCompleter;
	
	Future<Q> _execute() {
		if(_completer != null) {
			return _completer.future;
		}
		
		_completer = Completer<Q>();
		_completer.future.whenComplete(() {
			_removeShareTask(this);
		});
		_innerCompleter = Completer<Q>();
		_innerSubscription = _innerCompleter.future.asStream().listen(
			(data) {
				_completeData(data);
			},
			onError: (error, [StackTrace stackTrace]) {
				_completeError(error, stackTrace);
			}
		);
		_innerCompleter.complete(execute());
		return _completer.future;
	}
	
	void _monitor() {
		_refCount ++;
		print("_monitor count: $_refCount");
	}
	
	void _cancelMonitor() {
		_refCount --;
		print("_cancelMonitor count: $_refCount");
	}
	
	void _completeData(Q data) {
		if(_completer != null && _completer.isCompleted) {
			return;
		}
		
		_completer.complete(data);
		_destroy();
	}
	
	void _completeError(dynamic error, [StackTrace stack]) {
		if(_completer != null && _completer.isCompleted) {
			return;
		}
		
		_completer.completeError(error, stack);
		_destroy();
	}
	
	void _destroy() {
		if(_innerSubscription != null) {
			_innerSubscription.cancel();
			_innerSubscription = null;
		}
		_refCount = 0;
	}
	
	Future<Q> execute();
}