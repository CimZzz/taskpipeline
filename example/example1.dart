import 'package:taskpipeline/taskpipeline.dart';

/// 该示例所示范的内容:
/// 执行一个内部 Task
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行一个内部 Task
	// 内部 Task 只作用于该 TaskPipeline 对象
	final result1 = await taskPipeline.execInnerTask(leafExec: () async {
		await Future.delayed(const Duration(seconds: 2));
		return 10;
	});

	print("result1: $result1");
}