part of 'task_pipeline.dart';

class _InnerTask<T, Q> extends _Task<T, Q> {
	_InnerTask(this._data, this._callback, this._taskTree);

	/// 执行 Task 所需数据
	final T _data;

	/// 执行 Task 的执行回调
	final TaskExecutor<T, Q> _callback;

	/// 执行 TaskTree
	final TaskTree _taskTree;

	@override
	T get data => _data;
	TaskExecutor<T, Q> get callback => _callback;


	/// 对外的 Completer
	/// 实际通知 TaskPipeline 的 Completer
	Completer<Q> _completer;

	/// 对内的 Completer
	/// 用来执行实际 Task 并获得结果
	Completer<Q> _innerCompleter;

	/// 对内 Completer 的流订阅
	/// 用于将结果通知给 [_completer]，可以取消订阅
	StreamSubscription<Q> _subscription;


	/// 外部调用来停止该程序的执行
	/// 直接返回 `null` 作为执行结果
	@override
	void _stop(dynamic key) {
		_completeData(null);
	}

	/// 执行 Task
	/// 第一次会实例化 Completer 并实际执行 Task 逻辑
	@override
	Future<Q> _execute(dynamic key) {
		if(_completer == null) {
			_completer = Completer();
			_innerCompleter = Completer();
			_innerCompleter.complete(callback(data, _taskTree));
			_subscription = _innerCompleter.future.asStream().listen(
				(recvData) {
					_completeData(recvData);
				},
				onError: (error, stackTrace) {
					_completeError(error, stackTrace);
				}
			);
		}

		return _completer.future;
	}

	/// 完成 [_completer] 并返回指定数据
	/// 完成之后会回收 [_innerCompleter] 和 [_subscription]
	void _completeData(Q data) {
		if(_completer != null && !_completer.isCompleted) {
			_completer.complete(data);
			_destroy();
		}
	}

	/// 完成 [_completer] 并返回指定错误
	/// 完成之后会回收 [_innerCompleter] 和 [_subscription]
	void _completeError(dynamic error, StackTrace stackTrace) {
		if(_completer != null && !_completer.isCompleted) {
			_completer.completeError(error, stackTrace);
			_destroy();
		}
	}

	/// 回收 Task 中的 [_innerCompleter] 和 [_subscription]
	void _destroy() {
		_innerCompleter = null;
		if(_subscription != null) {
			_subscription.cancel();
			_subscription = null;
		}
	}
}