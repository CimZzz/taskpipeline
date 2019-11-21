import 'dart:async';

/// Task 执行回调接口
typedef TaskExecutor<T, Q> = Future<Q> Function(T);

/// 任务管线
/// 可以代理执行 Future，在执行过程中可以随时中断（并不是真正的中断，而是立即返回 null）
class TaskPipeline {
	/// 当前 Task 映射表
	/// Task 执行完成后将会被从中移除
	Map<dynamic, _Task> _taskMap;
	Map<dynamic, _Task> get _tasks {
		return _taskMap ??= Map();
	}

	/// 根据 key 将 Task 从表中移除
	void _remove(dynamic key) {
		if(_taskMap == null) {
			return null;
		}
		_taskMap.remove(key);
		if(_taskMap.isEmpty) {
			_taskMap = null;
		}
	}

	/// 执行 Task
	/// 其中 TaskMixin 是
	Future<Q> completeTask<T extends BaseTaskParams, Q>(TaskMixin<T, Q> taskMixin) {
		var task = _tasks[taskMixin.taskParams];
		if(task == null) {
			task = _Task<T, Q>();
			task.start();
			_tasks[taskMixin.taskParams] = task;
			task.execute(taskMixin.execute());
			task._completer.future.whenComplete((){
				_remove(taskMixin.taskParams);
			});
		}

		return task._completer.future;
	}

	Future<Q> completeCallback<T, Q>(T key, TaskExecutor<T, Q> executor) {
		var task = _tasks[key];
		if(task == null) {
			task = _Task<T, Q>();
			task.start();
			_tasks[key] = task;
			task.execute(executor(key));
			task._completer.future.whenComplete((){
				_remove(key);
			});

		}

		return task._completer.future;
	}

	void finishTask(dynamic key) {
		if(this._taskMap != null) {
			var task = _tasks[key];
			if(task != null) {
				task.stop();
			}
		}
	}
}

class _Task<T, Q> {
	Completer<Q> _completer;
	Completer<Q> _innerCompleter;

	void start() {
		_completer = Completer();
		_innerCompleter = Completer();
		_completer.complete(_innerCompleter.future);
	}

	void execute(Future<Q> realFuture) async {
		try {
			final result = await realFuture;
			if(_innerCompleter != null && !_innerCompleter.isCompleted) {
				_innerCompleter.complete(result);
			}
		}
		catch (e) {
			if(_innerCompleter != null && !_innerCompleter.isCompleted) {
				_innerCompleter.completeError(e);
			}
		}
	}

	void stop() {
		_innerCompleter.complete(null);
	}
}

abstract class BaseTaskParams {

}

mixin TaskMixin<T extends BaseTaskParams, Q> {
	T get taskParams;

	Future<Q> execute();
}