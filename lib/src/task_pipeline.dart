import 'dart:async';

part 'task_completer.dart';
part 'task_exceptions.dart';
part 'share_task.dart';

/// 内部 Task 回调，需要
typedef MessageTaskExecutor<T, Q> = Future<Q> Function(T data, TaskPipeline childPipeline);

/// 内部 Task 回调，需要
typedef TaskExecutor<Q> = Future<Q> Function(TaskPipeline childPipeline);

/// Task 存储容器
/// 存放 [_Task] 回调容器
class _TaskContainer<T, Q> {
	_TaskContainer({this.taskCompleter, this.childPipeline, this.shareTask});
	final _TaskCompleter<Q> taskCompleter;
	final TaskPipeline childPipeline;
	final BaseShareTask<T, Q> shareTask;
}

/// Task 管线
/// 用来控制所有 Task 的执行与终结
class TaskPipeline {
	/// 通用构造方法
	TaskPipeline(): this._parentPipeline = null;
	
	/// 生成子 Pipeline 方法
	TaskPipeline._spawn(this._parentPipeline);
	
	/// 祖先 TaskPipeline
	TaskPipeline _parentPipeline;
	
	/// 判断当前 TaskPipeline 是否已经被销毁
	bool _isDestroyed = false;
	
	/// TaskContainer 映射表
	/// 存放全部正在执行的 Task 和管理其全部子 Task 的 Pipeline
	Map<dynamic, _TaskContainer> _taskContainerMap;
	
	/// 匿名 Task 数字 Key
	/// 每次创建 Task 都会自增 1，保证 Key 唯一
	int _anonymousKey = 0;
	
	/// 获取下一个匿名 Task 数字 Key
	int _nextAnonymousKey() {
		_anonymousKey ++;
		if(_anonymousKey >= 0xFFFFFFF) {
			_anonymousKey = 0;
		}
		
		return _anonymousKey;
	}
	
	
	/// 终结指定 Task
	/// 不能终结匿名 Task
	/// 同时也会销毁子 TaskPipeline.
	void finishTask(String key) {
		_finishTask(key);
	}
	
	/// 终结指定 Task 实现
	void _finishTask(dynamic key) {
		if(_taskContainerMap == null) {
			return;
		}
		_stopTask(_taskContainerMap.remove(key));
	}
	
	/// 终结全部 Task
	/// 同时也会销毁全部子 TaskPipeline.
	void finishAllTask() {
		if(_taskContainerMap != null) {
			final tempTaskMap = _taskContainerMap;
			_taskContainerMap = null;
			tempTaskMap.values.forEach((taskContainer) {
				_stopTask(taskContainer);
			});
		}
		
		_anonymousKey = 0;
	}
	
	/// 终结 Task 的逻辑实现
	void _stopTask(_TaskContainer taskContainer) {
		if(taskContainer == null) {
			return;
		}
		
		taskContainer.taskCompleter.stop();
		taskContainer.shareTask?._cancelMonitor();
		taskContainer.childPipeline?.destroy();
	}
	
	/// 销毁 Task
	void destroy() {
		_isDestroyed = true;
		_parentPipeline = null;
		finishAllTask();
	}
	
	/// 执行内部 Task
	/// 如果已经存在正在执行的 Task，则直接将其返回
	/// 但是如果父 TaskPipeline 存在该 Key，则判断为形成 Task 闭环，抛出异常
	Future<Q> execInnerKeyTask<T, Q>(String key, T data, MessageTaskExecutor<T, Q> taskCallback) {
		if(_isDestroyed) {
			return null;
		}
		return _execInnerKeyTask(key, data, taskCallback);
	}
	
	/// 执行内部 Task，忽略结果
	void runInnerKeyTask<T, Q>(String key, T data, MessageTaskExecutor<T, Q> taskCallback) {
		if(_isDestroyed) {
			return;
		}
		_execInnerKeyTask(key, data, taskCallback);
	}
	
	/// 执行匿名内部 Task
	/// 该 Task 无法通过外部主动结束
	/// 将会有内部生成一个数字作为 Task Key，该 Key 保证唯一
	Future<Q> execInnerTask<T, Q>(T data, MessageTaskExecutor<T, Q> taskCallback) {
		if(_isDestroyed) {
			return null;
		}
		return _execInnerKeyTask(_nextAnonymousKey(), data, taskCallback);
	}
	
	/// 执行匿名内部 Task，忽略结果
	void runInnerTask<T, Q>(T data, MessageTaskExecutor<T, Q> taskCallback) {
		if(_isDestroyed) {
			return;
		}
		_execInnerKeyTask(_nextAnonymousKey(), data, taskCallback);
	}
	
	/// 执行内部 Task 逻辑
	Future<Q> _execInnerKeyTask<T, Q>(dynamic key, T data, MessageTaskExecutor<T, Q> taskCallback) {
		if(_isDestroyed) {
			return null;
		}
		_taskContainerMap ??= Map();
		Future<Q> requireFuture;
		_TaskContainer taskContainer;
		if(key is String) {
			taskContainer = _taskContainerMap[key];
			if(taskContainer != null) {
				if(taskContainer.shareTask != null) {
					throw TaskException(message: "Already exist share task. key : $key");
				}
				final taskCompleter = taskContainer.taskCompleter;
				if(taskCompleter != null && taskCompleter is _TaskCompleter<Q>) {
					requireFuture = taskCompleter.future();
				}
				else {
					throw TaskException(message: "Equal key, but not equal inner task. key : $key");
				}
			}
			else {
				// 检查父 TaskPipeline 是否存在相同 Key 值的 Task
				// 存在则抛出异常
				if(_checkParentExist(key)) {
					throw TaskException(message: "Ancestor task pipeline exists same key. key : $key");
				}
			}
		}
		
		if(taskContainer == null) {
			taskContainer = _establishKeyTask<T, Q>(key);
			requireFuture = taskContainer.taskCompleter.complete(
				taskCallback(data, taskContainer.childPipeline));
		}
		
		return requireFuture;
	}
	
	/// 执行共享 Task
	/// 如果已经存在正在执行的 Task，则直接将其返回
	/// 如果全局存在正在执行的 Task，那么会将其加入监控
	Future<Q> execShareKeyTask<T, Q>(String key, BaseShareTask<T, Q> shareTask) {
		if(_isDestroyed) {
			return null;
		}
		return _execShareKeyTask(key, shareTask);
	}
	
	/// 执行共享 Task，忽略结果
	void runShareKeyTask<T, Q>(String key, BaseShareTask<T, Q> shareTask) {
		if(_isDestroyed) {
			return null;
		}
		
		_execShareKeyTask(key, shareTask);
	}
	
	/// 执行匿名共享 Task
	/// 该 Task 无法通过外部主动结束
	/// 将会有内部生成一个数字作为 Task Key，该 Key 保证唯一
	Future<Q> execShareTask<T, Q>(BaseShareTask<T, Q> shareTask) {
		if(_isDestroyed) {
			return null;
		}
		return _execShareKeyTask(_nextAnonymousKey(), shareTask);
	}
	
	/// 执行匿名共享 Task，忽略结果
	void runShareTask<T, Q>(BaseShareTask<T, Q> shareTask) {
		if(_isDestroyed) {
			return null;
		}
		
		_execShareKeyTask(_nextAnonymousKey(), shareTask);
	}
	
	/// 执行共享 Task 逻辑
	Future<Q> _execShareKeyTask<T, Q>(dynamic key, BaseShareTask<T, Q> shareTask) {
		if(_isDestroyed) {
			return null;
		}
		
		_taskContainerMap ??= Map();
		Future<Q> requireFuture;
		_TaskContainer taskContainer;
		if(key is String) {
			taskContainer = _taskContainerMap[key];
			if(taskContainer != null) {
				if(taskContainer.shareTask == null) {
					throw TaskException(message: "Already exist inner task. key : $key");
				}
				
				final shareTask = taskContainer.shareTask;
				final taskCompleter = taskContainer.taskCompleter;
				if(taskContainer.taskCompleter != null &&
					taskCompleter is _TaskCompleter<Q> &&
					shareTask is BaseShareTask<T, Q> &&
					shareTask.data == shareTask.data
				) {
					requireFuture = taskCompleter.future();
				}
				else {
					throw TaskException(message: "Equal key, but not equal share task. key : $key");
				}
			}
			else {
				// Share Task 不会向上检查 Key 值冲突.
			}
		}
		
		if(taskContainer == null) {
			// 从全局 Share Task 池中找到正在执行的相同的 Share Task
			var requireTask = _findShareTask<T, Q>(shareTask.uniqueKey, shareTask.data);
			if(requireTask == null) {
				// 没有找到，则创建一个放到全局 Share Task 中
				_addShareTask(shareTask);
				requireTask = shareTask;
			}
			
			// 因为 Share Task 不会引起循环嵌套问题
			taskContainer = _establishKeyTask<T, Q>(key, hasChildPipeline: false, baseShareTask: requireTask);
			requireFuture = taskContainer.taskCompleter.complete(requireTask._execute());
		}
		
		return requireFuture;
	}
	
	
	/// 检查祖先 TaskPipeline 是否存在同样 Key 值的内部 Task.
	/// 通常来说，内部 Task 在一个 Task 树中， Key 是唯一的，最大限度防止闭环的形成
	bool _checkParentExist(String key) {
		var parent = this._parentPipeline;
		while(parent != null) {
			if(parent._taskContainerMap != null) {
				final taskContainer = parent._taskContainerMap[key];
				// 共享 Task 不存在子 TaskPipeline
				if (taskContainer != null && taskContainer.childPipeline != null) {
					return true;
				}
			}
			parent = parent._parentPipeline;
		}
		return false;
	}
	
	/// 建立 Key Task
	/// 可以主动被终结
	_TaskContainer<T, Q> _establishKeyTask<T, Q>(dynamic key, {bool hasChildPipeline = true, BaseShareTask<T, Q> baseShareTask}) {
		_TaskCompleter<Q> completer = _TaskCompleter(() {
			_finishTask(key);
		});
		baseShareTask?._monitor();
		final taskContainer = _TaskContainer(
			taskCompleter: completer,
			childPipeline: hasChildPipeline ? TaskPipeline._spawn(this) : null,
			shareTask: baseShareTask,
		);
		_taskContainerMap[key] = taskContainer;
		return taskContainer;
	}
}