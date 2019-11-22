import 'dart:async';

part 'tasks.dart';
part 'task_tree.dart';
part 'exceptions.dart';
part 'inner_task.dart';
part 'share_task.dart';
part 'aa.dart';


/// Task 回调
typedef TaskExecutor<T, Q> = Future<Q> Function(T data, TaskTree taskTree);

/// Task 存储容器
/// 存放 [_Task] 和 [TaskTree] 的容器
class _TaskContainer {
    _TaskContainer(this.task, this.taskTree);
	final _Task task;
	final TaskTree taskTree;
}

/// Task 管线
/// 用来控制所有 Task 的执行与终结
class TaskPipeline {
	Map<>


	/// TaskContainer 映射表
	/// 存放全部正在执行的 Task 和管理其全部子 Task 的 TaskTree
	Map<String, _TaskContainer> _taskContainerMap;

	/// 通过 Key 找到正在执行的 TaskContainer
	_TaskContainer _findTaskContainer(String key) {
		if(_taskContainerMap == null) {
			return null;
		}

		return _taskContainerMap[key];
	}

	/// 向 TaskContainer 映射表中添加 TaskContainer
	void _addTaskContainer(String key, _TaskContainer taskContainer) {
		_taskContainerMap ??= Map();
		_taskContainerMap[key] = taskContainer;
	}

	/// 从 TaskContainer 映射表中移除对应 Key 下的 TaskContainer
	/// 该操作只会将 TaskContainer 从表中移除，并不会做其他操作
	_TaskContainer _removeTaskContainer(String key) {
		if(_taskContainerMap == null) {
			return null;
		}
		_TaskContainer taskContainer = _taskContainerMap.remove(key);
		if(_taskContainerMap.isEmpty) {
			_taskContainerMap = null;
		}
		return taskContainer;
	}

	/// 执行内部 Task
	/// 内部 Task 不会被全局共享，但是可以在 TaskPipeline 中共享，前提是全部参数必须相同，
	/// 否则会抛出异常; 如果执行一个新的内部 Task，将会实例化 [_InnerTask] 和 [TaskTree] 对象，
	/// 分别用来执行逻辑和管理子 Task.
	Future<Q> execInnerTask<T, Q>(String key, T data, TaskExecutor<T, Q> taskCallback) {
		_InnerTask<T, Q> requireTask;

		// 找到正在运行的 childTask.
		// 对其进行校验，当 childTask 不满足以下条件，抛出异常
		// 1. 类型不为 _InnerTask<T, Q>
		// 2. 数据不相等
		// 3. 回调方法不相同
		_TaskContainer taskContainer = _findTaskContainer(key);
		if(taskContainer != null) {
			final task = taskContainer.task;
			if(task is! _InnerTask<T, Q>) {
				throw TaskException(message: "Key: $key 对应下 Task 已存在，并且不是一个内部 Task");
			}

			if(task.data != taskCallback) {
				throw TaskException(message: "Key: $key 存在内部 Task，但数据不相同");
			}

			if(task.callback != taskCallback) {
				throw TaskException(message: "Key: $key 存在内部 Task，但回调方法不相同");
			}

			requireTask = task;
		}
		else {
			// 没有找到正在运行的 Task
			// 实例化新的 [_InnerTask] 和 [TaskTree]
			TaskTree taskTree = TaskTree._();
			requireTask = _InnerTask(data, taskCallback, taskTree);
			// 将新建的 Task 和 TaskTree 添加到映射表中，表示在 `key` 下已经有一个内部 Task 正在执行
			_addTaskContainer(key, _TaskContainer(requireTask, taskTree));
			// 监听 Task 结束回调，将其从 [TaskPipeline] 中移除
			taskTree._completeSubscription = requireTask._execute(null).asStream().listen(
				null,
				onDone: () {
					finishTask(key);
				}
			);
		}

		// 返回正在执行的 Task 的 Future
		return requireTask._execute(null);
	}

	/// 直接终结指定 Task
	/// 通过 Key 找到 Task，并将其对应 TaskTree 下全部 Task 一一终结
	/// 使用 _removeTask 先将 Task 从 Task 映射表中移除，然后调用 _stopTask 停止
	/// 正在执行的 Task.
	void finishTask(String key) {
		if(_taskContainerMap == null) {
			return;
		}
		_TaskContainer taskContainer = _removeTaskContainer(key);
		_stopTask(taskContainer);
	}

	/// 终结全部 Task
	void finishAll() {
//		Map<String, _Task> tempMap = _taskContainerMap;
//		_taskContainerMap = null;
//		tempMap.forEach((_, task) {
//		});
	}

	/// 实际停止 Task 的逻辑
	/// 先停止自身，再终止全部子 Task
	void _stopTask(_TaskContainer taskContainer) {
		if(taskContainer == null) {
			return;
		}
		taskContainer.taskTree?._stopForkChildTask();
		taskContainer.task._stop(this);
		taskContainer.taskTree?._finishAllChildTask();
	}
}
