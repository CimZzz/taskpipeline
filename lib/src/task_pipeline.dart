import 'dart:async';

import 'proxy_completer.dart';
part 'task_exceptions.dart';
part 'share_task.dart';

/// 内部 Task 回调，需要消息数据
typedef MessageTaskExecutor<T, Q> = FutureOr<Q> Function(T data, TaskPipeline childPipeline);

/// 内部 Task 回调，需要消息数据，但是不需要子 Pipeline
typedef LeafMessageTaskExecutor<T, Q> = FutureOr<Q> Function(T data);

/// 内部 Task 回调，不需要消息数据
typedef TaskExecutor<Q> = FutureOr<Q> Function(TaskPipeline childPipeline);

/// 内部 Task 回调，不需要消息数据，也不需要子 Pipeline
typedef LeafTaskExecutor<Q> = FutureOr<Q> Function();

/// Task 存储容器
/// 存放 [_Task] 回调容器
class _TaskContainer<T, Q> {
	_TaskContainer({this.proxyCompleter, this.childPipeline, this.shareTask});
	final ProxyCompleter<Q> proxyCompleter;
	final TaskPipeline childPipeline;
	final ShareTask<T, Q> shareTask;
}

/// Task 管线
/// 用来控制所有 Task 的执行与终结
class TaskPipeline {
	/// 通用构造方法
	TaskPipeline();
	
	/// 生成子 Pipeline 方法
	TaskPipeline._spawn(this._ancestor);
	
	/// 生成子 Pipeline 方法
	TaskPipeline._fork(this._forkKey, this._master);
	
	/// 祖先 TaskPipeline
	TaskPipeline _ancestor;
	
	/// 主 TaskPipeline
	TaskPipeline _master;

  /// Fork 时使用的 Key
  dynamic _forkKey;
	
	/// 判断当前 TaskPipeline 是否已经被销毁
	bool _isDestroyed = false;
	
	/// TaskContainer 映射表
	/// 存放全部正在执行的 Task 和管理其全部子 Task 的 Pipeline
	Map<dynamic, _TaskContainer> _taskContainerMap;

  /// 存放 Fork 的 TaskPipeline 映射表
  /// 主 TaskPipeline 可以 Fork 子 TaskPipeline,
  /// 当主 TaskPipeline 被销毁时，子 TaskPipeline 也会被销毁
  /// 这个子 TaskPipeline 与任务中创建的 TaskPipeline 不同的是，
  /// 该 TaskPipeline 不会持有主 TaskPipeline 的引用，而是作为一个独立
  /// 的存在
  Map<dynamic, TaskPipeline> _forkPipeline;
	
  /// Fork 一个子 Pipeline，进行独立使用
  /// 在调用 destroy 时会自动和主 Pipeline 脱钩
  TaskPipeline fork({dynamic key}) {
    if(key == null || _forkPipeline?.containsKey(key) == true) {
      // key 不存在或者指定 key 下存在对应子 TaskPipeline，返回 null
      return null;
    }
    final taskPipeline = TaskPipeline._fork(key, this);
    _forkPipeline ??= {};
    _forkPipeline[key] = taskPipeline;
    return taskPipeline;
  }

  /// 取消 Fork 引用
  void _forkCancel({dynamic key}) {
    if(key == null || !(_forkPipeline?.containsKey(key) ?? false)) {
      // key 不存在或者指定 key 下不存在对应的子 TaskPipeline，返回
      return;
    }
    _forkPipeline.remove(key);
    if(_forkPipeline.length == 0) {
      _forkPipeline = null;
    }
  }

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
	
	
	/// 终结 Task 的逻辑实现
	void _stopTask(_TaskContainer taskContainer) {
		if(taskContainer == null) {
			return;
		}
		
		taskContainer.proxyCompleter.stop();
		taskContainer.shareTask?._cancelMonitor();
		taskContainer.childPipeline?.destroy();
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
	
	/// 销毁 Task
	void destroy() {
		_isDestroyed = true;
		_ancestor = null;
		finishAllTask();
    if(_master != null) {
      _master._forkCancel(key: _forkKey);
      _master = null;
    }

    if(_forkPipeline != null) {
      final tempPipeline = _forkPipeline;
      _forkPipeline = null;
      tempPipeline.values.forEach((pipeline) {
        pipeline.destroy();
      });
    }
	}

	/// 执行内部 Task，并获取其返回值
	/// * key: Task 的键值，设置了该值的 Task 可以通过 [TaskPipeline.finishTask] 主动终结该任务.
	///
	/// * data: Task 执行所需要的数据，只在使用 [msgExec] 或者 [leafMsgExec] 时才会生效.
	///
	/// * msgExec: Task 执行回调. 该回调使用 [data] 和生成的 `TaskPipeline` 作为回调参数，
	/// 使用子 `TaskPipeline` 执行的 Task，都会随着该回调的终结而终结.
	///
	/// * leafMsgExec: Task 执行回调. 该回调只使用 [data] 作为回调参数, 不会生成子 `TaskPipeline`.
	///
	/// * exec: Task 执行回调. 该回调忽略 [data]，但会生成 `TaskPipeline` 作为回调参数，
	/// 使用子 `TaskPipeline` 执行的 Task，都会随着该回调的终结而终结.
	///
	/// * leafExec: Task 执行回调. 该回调忽略 [data] 并且不会生成子 `TaskPipeline`.
	///
	/// 以上四种执行回调，在同一时间只有一种会生效，所以建议仅传递一种执行回调.
	/// 优先级顺序为: msgExec > leafMsgExec > exec > leafExec
	///
	/// 如果不设置 [key] 的话，将会由内部生成一个数字作为 Task Key，该 Key 保证唯一，但外部无法
	/// 通过 [TaskPipeline.finishTask] 方法来主动终结此 Task.
	Future<Q> execInnerTask<T, Q>({
		String key,
		T data,
		MessageTaskExecutor<T, Q> msgExec,
		LeafMessageTaskExecutor<T, Q> leafMsgExec,
		TaskExecutor<Q> exec,
		LeafTaskExecutor<Q> leafExec,
	}) {
		if(_isDestroyed) {
			return null;
		}
		return _execInnerTask(
			key: key != null ? key : _nextAnonymousKey(),
			data: data,
			msgExec: msgExec,
			leafMsgExec: leafMsgExec,
			exec: exec,
			leafExec: leafExec,
		);
	}

	/// 执行内部 Task，忽略其返回值
	/// * key: Task 的键值，设置了该值的 Task 可以通过 [TaskPipeline.finishTask] 主动终结该任务.
	///
	/// * data: Task 执行所需要的数据，只在使用 [msgExec] 或者 [leafMsgExec] 时才会生效.
	///
	/// * msgExec: Task 执行回调. 该回调使用 [data] 和生成的 `TaskPipeline` 作为回调参数，
	/// 使用子 `TaskPipeline` 执行的 Task，都会随着该回调的终结而终结.
	///
	/// * leafMsgExec: Task 执行回调. 该回调只使用 [data] 作为回调参数, 不会生成子 `TaskPipeline`.
	///
	/// * exec: Task 执行回调. 该回调忽略 [data]，但会生成 `TaskPipeline` 作为回调参数，
	/// 使用子 `TaskPipeline` 执行的 Task，都会随着该回调的终结而终结.
	///
	/// * leafExec: Task 执行回调. 该回调忽略 [data] 并且不会生成子 `TaskPipeline`.
	///
	/// 以上四种执行回调，在同一时间只有一种会生效，所以建议仅传递一种执行回调.
	/// 优先级顺序为: msgExec > leafMsgExec > exec > leafExec
	///
	/// 如果不设置 [key] 的话，将会由内部生成一个数字作为 Task Key，该 Key 保证唯一，但外部无法
	/// 通过 [TaskPipeline.finishTask] 方法来主动终结此 Task.
	void runInnerTask<T, Q>({
		String key,
		T data,
		MessageTaskExecutor<T, Q> msgExec,
		LeafMessageTaskExecutor<T, Q> leafMsgExec,
		TaskExecutor<Q> exec,
		LeafTaskExecutor<Q> leafExec,
	}) {
		if(_isDestroyed) {
			return;
		}
		_execInnerTask(
			key: key != null ? key : _nextAnonymousKey(),
			data: data,
			msgExec: msgExec,
			leafMsgExec: leafMsgExec,
			exec: exec,
			leafExec: leafExec,
		);
	}

	/// 执行内部 Task 逻辑
	Future<Q> _execInnerTask<T, Q>({
		dynamic key,
		T data,
		MessageTaskExecutor<T, Q> msgExec,
		LeafMessageTaskExecutor<T, Q> leafMsgExec,
		TaskExecutor<Q> exec,
		LeafTaskExecutor<Q> leafExec,
	}) {
		if(_isDestroyed) {
			return null;
		}

		// 不存在回调的话直接返回
		if(msgExec == null &&
			leafMsgExec == null &&
			exec == null &&
			leafExec == null) {
			return null;
		}

		_taskContainerMap ??= {};
		Future<Q> requireFuture;
		_TaskContainer taskContainer;
		if(key is String) {
			taskContainer = _taskContainerMap[key];
			if(taskContainer != null) {
				if(taskContainer.shareTask != null) {
					throw TaskException(message: 'Already exist share task. key : $key');
				}
				final taskCompleter = taskContainer.proxyCompleter;
				if(taskCompleter != null && taskCompleter is ProxyCompleter<Q>) {
					requireFuture = taskCompleter.future();
				}
				else {
					throw TaskException(message: 'Equal key, but not equal inner task. key : $key');
				}
			}
			else {
				// 检查父 TaskPipeline 是否存在相同 Key 值的 Task
				// 存在则抛出异常
				if(_checkParentExist(key)) {
					throw TaskException(message: 'Ancestor task pipeline exists same key. key : $key');
				}
			}
		}
		
		if(taskContainer == null) {
			FutureOr<Q> taskFuture;
			try {
				if (msgExec != null) {
					taskContainer = _establishKeyTask<T, Q>(key);
					taskFuture = msgExec(data, taskContainer.childPipeline);
				}
				else if (leafMsgExec != null) {
					taskContainer =
						_establishKeyTask<T, Q>(key, hasChildPipeline: false);
					taskFuture = leafMsgExec(data);
				}
				else if (exec != null) {
					taskContainer = _establishKeyTask<T, Q>(key);
					taskFuture = exec(taskContainer.childPipeline);
				}
				else if (leafExec != null) {
					taskContainer =
						_establishKeyTask<T, Q>(key, hasChildPipeline: false);
					taskFuture = leafExec();
				}
				
				if(taskFuture is Future<Q>) {
					requireFuture = taskContainer.proxyCompleter.completeFuture(taskFuture);
				}
				else {
					requireFuture = taskContainer.proxyCompleter.completeData(taskFuture);
				}
			}
			catch(e, stacktrace) {
				requireFuture = taskContainer.proxyCompleter.completeError(e, stacktrace);
			}
		}
		
		return requireFuture;
	}


	/// 执行共享 Task，并获取其返回值
	/// * key: Task 的键值，设置了该值的 Task 可以通过 [TaskPipeline.finishTask] 主动终结该任务.
	///
	/// * shareTask: 共享 Task.
	/// 
	/// 如果不设置 [key] 的话，将会由内部生成一个数字作为 Task Key，该 Key 保证唯一，但外部无法
	/// 通过 [TaskPipeline.finishTask] 方法来主动终结此 Task.
	Future<Q> execShareTask<T, Q>({
		String key,
		ShareTask<T, Q> shareTask
	}) {
		if(_isDestroyed) {
			return null;
		}
		return _execShareTask(
			key: key != null ? key : _nextAnonymousKey(),
			shareTask: shareTask
		);
	}

	/// 执行共享 Task，忽略其返回值
	/// * key: Task 的键值，设置了该值的 Task 可以通过 [TaskPipeline.finishTask] 主动终结该任务.
	///
	/// * shareTask: 共享 Task.
	///
	/// 如果不设置 [key] 的话，将会由内部生成一个数字作为 Task Key，该 Key 保证唯一，但外部无法
	/// 通过 [TaskPipeline.finishTask] 方法来主动终结此 Task.
	void runShareTask<T, Q>({
		String key,
		ShareTask<T, Q> shareTask
	}) {
		if(_isDestroyed) {
			return;
		}

		_execShareTask(
			key: key != null ? key : _nextAnonymousKey(),
			shareTask: shareTask
		);
	}

	
	/// 执行共享 Task 逻辑
	Future<Q> _execShareTask<T, Q>({
		dynamic key,
		ShareTask<T, Q> shareTask
	}) {
		if(_isDestroyed) {
			return null;
		}

		if(shareTask == null) {
			return null;
		}
		
		_taskContainerMap ??= {};
		Future<Q> requireFuture;
		_TaskContainer taskContainer;
		if(key is String) {
			taskContainer = _taskContainerMap[key];
			if(taskContainer != null) {
				if(taskContainer.shareTask == null) {
					throw TaskException(message: 'Already exist inner task. key : $key');
				}
				
				final shareTask = taskContainer.shareTask;
				final taskCompleter = taskContainer.proxyCompleter;
				if(taskContainer.proxyCompleter != null &&
					taskCompleter is ProxyCompleter<Q> &&
					shareTask is ShareTask<T, Q> &&
					shareTask.data == shareTask.data
				) {
					requireFuture = taskCompleter.future();
				}
				else {
					throw TaskException(message: 'Equal key, but not equal share task. key : $key');
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
			requireFuture = taskContainer.proxyCompleter.completeFuture(requireTask._execute());
		}
		
		return requireFuture;
	}
	
	
	/// 检查祖先 TaskPipeline 是否存在同样 Key 值的内部 Task.
	/// 通常来说，内部 Task 在一个 Task 树中， Key 是唯一的，最大限度防止闭环的形成
	bool _checkParentExist(String key) {
		var parent = _ancestor;
		while(parent != null) {
			if(parent._taskContainerMap != null) {
				final taskContainer = parent._taskContainerMap[key];
				// 共享 Task 不存在子 TaskPipeline
				if (taskContainer != null && taskContainer.childPipeline != null) {
					return true;
				}
			}
			parent = parent._ancestor;
		}
		return false;
	}
	
	/// 建立 Key Task
	/// 可以主动被终结
	_TaskContainer<T, Q> _establishKeyTask<T, Q>(dynamic key, {bool hasChildPipeline = true, ShareTask<T, Q> baseShareTask}) {
		var completer = ProxyCompleter<Q>(() {
			_finishTask(key);
		});
		baseShareTask?._monitor();
		final taskContainer = _TaskContainer(
			proxyCompleter: completer,
			childPipeline: hasChildPipeline ? TaskPipeline._spawn(this) : null,
			shareTask: baseShareTask,
		);
		_taskContainerMap[key] = taskContainer;
		return taskContainer;
	}
}