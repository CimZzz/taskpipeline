part of 'task_pipeline.dart';

void main() async {
	final pipeline = TaskPipeline();
	print(await pipeline.execInnerTask("123", 123, (data, tree) async {
		await Future.delayed(const Duration(seconds: 2));
		return 123;
	}));
	print(pipeline._taskContainerMap?.length ?? 0);
}