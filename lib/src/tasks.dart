part of 'task_pipeline.dart';

/// Task 基类
/// 定义了 Task 基本的操作方法
abstract class _Task<T, Q> {
	/// 执行 Task 所需数据 Getter
	T get data;

	/// 根据给定的 key 执行 Task.
	/// 这样做的目的是有些类型的 Task 与 [TaskPipeline] 或 [TaskTree] 的关系是一对多.
	Future<Q> _execute(dynamic key);

	/// 根据给定的 key 停止 Task.
	/// 这样做的目的是有些类型的 Task 与 [TaskPipeline] 或 [TaskTree] 的关系是一对多.
	void _stop(dynamic key);
}