part of 'task_pipeline.dart';

typedef TaskDoneCallback = void Function();

class _TaskCompleter<Q> {
	_TaskCompleter(this.taskDoneCallback);
	
	TaskDoneCallback taskDoneCallback;
	StreamSubscription<Q> _taskSubscription;
	Completer<Q> _completer;
	
	Future<Q> complete(Future<Q> monitorFuture) {
		if(_completer != null) {
			return _completer.future;
		}
		
		_completer = Completer<Q>();
		_completer.future.whenComplete(() {
			_doTaskDoneCallback();
		});
		_taskSubscription = monitorFuture.asStream().listen(
			(data) {
				_completeData(data);
			},
			onError: (error, [StackTrace stack]) {
				_completeError(error, stack);
			}
		);
		
		return _completer.future;
	}
	
	Future<Q> future() {
		return _completer?.future;
	}
	
	void stop({bool needDoneCallback = false}) {
		if(!needDoneCallback) {
			taskDoneCallback();
		}
		_completeData(null);
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
	
	
	void _doTaskDoneCallback() {
		if(taskDoneCallback != null) {
			taskDoneCallback();
			taskDoneCallback = null;
		}
	}
	
	void _destroy() {
		if(_taskSubscription != null) {
			_taskSubscription.cancel();
			_taskSubscription = null;
		}
	}
}