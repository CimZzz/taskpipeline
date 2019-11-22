part of 'task_pipeline.dart';


/// TaskTree 存储容器
/// 存放子 Task 完成订阅的容器
class _TaskTreeContainer {
	_TaskTreeContainer(this.task, this.completeSubscription);
	final _Task task;
	final StreamSubscription completeSubscription;
}

/// Task 任务树
/// 用来维护根 Task 下全部子 Task
/// * TaskTree 只会维护由自身发起的 Task，如果在 Task 中仍然使用 [TaskPipeline] 来作为
/// * Task 的发起者，那么产生的 Task 将不会记录为子 Task
class TaskTree {
	TaskTree._();

	/// 子 Task 映射表
	Map<_Task, _TaskTreeContainer> _taskMap;
	
	/// 将 Task 加入到子 Task 表中
	void _addChildTask(_TaskTreeContainer container) {
		_taskMap ??= Map();
		_taskMap[container.task] = container;
	}


	/// 从 TaskTreeContainer 映射表中移除对应 Key 下的 TaskTreeContainer
	/// 该操作只会将 TaskTreeContainer 从表中移除，并不会做其他操作
	_TaskTreeContainer _removeTaskContainer(_Task task) {
		if(_taskMap == null) {
			return null;
		}
		_TaskTreeContainer taskTreeContainer = _taskMap.remove(task);
		if(_taskMap.isEmpty) {
			_taskMap = null;
		}
		return taskTreeContainer;
	}

	/// 判断是否可以继续分裂子 Task
	/// 当设置为 `false` 时，由该 TaskTree 发起的
	/// 全部 Task 都不会被执行，并且会直接返回 `null` 作为执行结果
	/// * 目前只有在 TaskTree 被终结时才会将其变为 `false`
	var _isAllowForkChild = true;

	/// 根 Task 完成订阅
	/// 作用是将 Task 从根中移除并终结
	/// 但是如果主动终结了 Task，那么首先会取消该订阅，
	/// 以免当被终结的 Task 完成时触发订阅导致正在执行的 Task
	/// 被不当终结
	StreamSubscription _completeSubscription;

	/// 停止分裂子 Task
	/// 在 Task 被终结的时候首先会调用该方法，
	/// 再调用 [_finishAllChildTask] 方法
	void _stopForkChildTask() {
		if(_isAllowForkChild) {
			_isAllowForkChild = false;
		}

		if(_completeSubscription != null) {
			_completeSubscription.cancel();
			_completeSubscription = null;
		}
	}
	
	void _finishChildTask(_Task task) {
		if(_taskMap == null) {
			return;
		}

		final container = _removeTaskContainer(task);
		if(container != null) {
			container.completeSubscription.cancel();
			task._stop(this);
		}
	}

	/// 终结全部子 Task
	void _finishAllChildTask() {
		if(_taskMap == null) {
			return;
		}

		_taskMap.forEach((task, container) {
			container.completeSubscription.cancel();
			task._stop(this);
		});

		_taskMap = null;
	}

	/// 执行内部 Task
	/// 与 Pipeline 不同的是，该方法不需要提供 Key 值，因为全部子 Task 都会被
	Future<Q> execInnerTask<T, Q>(T data, TaskExecutor<T, Q> taskCallback) {
		if(!_isAllowForkChild) {
			return null;
		}
		_InnerTask<T, Q> childTask = _InnerTask(data, taskCallback, this);
		final taskFuture = childTask._execute(this);
		StreamSubscription streamSubscription = taskFuture.asStream().listen(
			null,
			onDone: () {
				_finishChildTask(childTask);
			}
		);
		_addChildTask(_TaskTreeContainer(childTask, streamSubscription));
		return taskFuture;
	}
}