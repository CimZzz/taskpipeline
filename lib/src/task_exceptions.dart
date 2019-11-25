part of 'task_pipeline.dart';

/// Task 异常
/// 通常会在执行 Task 的方法中抛出
class TaskException with Exception {
	TaskException({this.message});

	final String message;

	@override
	String toString() {
		return message ?? "Occur TaskException.";
	}
}