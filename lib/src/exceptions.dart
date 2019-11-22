part of 'task_pipeline.dart';


class TaskException with Exception {
	TaskException({this.message});

	final String message;

	@override
	String toString() {
		return message ?? "Occur TaskException.";
	}
}